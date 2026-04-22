const mysql = require('mysql2/promise');
require('dotenv').config();

async function setupDatabase() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    multipleStatements: false
  });

  try {
    // Drop existing objects
    console.log('🗑️  Dropping existing objects...');
    const dropStatements = [
      'DROP TABLE IF EXISTS `tbl_data_transformation_log`',
      'DROP TABLE IF EXISTS `tbl_middleware_cache`',
      'DROP TABLE IF EXISTS `tbl_protocol_config`',
      'DROP TABLE IF EXISTS `tbl_message_dedup`',
      'DROP TABLE IF EXISTS `tbl_sync_log`',
      'DROP TABLE IF EXISTS `tbl_error_log`',
      'DROP TABLE IF EXISTS `tbl_raw_data`',
      'DROP TABLE IF EXISTS `tbl_machines`',
    ];

    for (const stmt of dropStatements) {
      try {
        await connection.execute(stmt);
      } catch (e) {
        // Ignore errors on drop
      }
    }

    console.log('✅ Old objects dropped\n');
    console.log('📝 Creating tables...');

    await connection.execute('USE `acca_mdata`');

    // Create tbl_machines
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tbl_machines (
        id INT AUTO_INCREMENT PRIMARY KEY,
        machine_id VARCHAR(50) NOT NULL UNIQUE,
        name VARCHAR(100) NOT NULL,
        location VARCHAR(100),
        device_type VARCHAR(50) NOT NULL,
        description TEXT,
        protocols JSON NOT NULL,
        status ENUM('ACTIVE', 'INACTIVE', 'ERROR', 'MAINTENANCE') DEFAULT 'ACTIVE',
        last_sync TIMESTAMP NULL,
        last_heartbeat TIMESTAMP NULL,
        total_records_sent BIGINT DEFAULT 0,
        total_errors INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uk_machine_id (machine_id),
        KEY idx_status (status),
        KEY idx_device_type (device_type),
        KEY idx_last_sync (last_sync)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  ✓ tbl_machines');

    // Create tbl_raw_data
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tbl_raw_data (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        machine_id VARCHAR(50) NOT NULL,
        message_id VARCHAR(100) NOT NULL,
        protocol VARCHAR(20) NOT NULL,
        raw_payload LONGTEXT NOT NULL,
        raw_payload_hash VARCHAR(64),
        is_valid BOOLEAN DEFAULT TRUE,
        validation_error VARCHAR(500),
        error_code VARCHAR(20),
        received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        middleware_timestamp TIMESTAMP NULL,
        partition_key VARCHAR(20) NOT NULL,
        batch_id VARCHAR(100),
        UNIQUE KEY uk_message_id (message_id),
        KEY idx_machine_id (machine_id),
        KEY idx_received_at (received_at),
        KEY idx_partition_key (partition_key),
        KEY idx_is_valid (is_valid),
        KEY idx_protocol (protocol),
        KEY idx_composite_machine_received (machine_id, received_at DESC),
        KEY idx_composite_partition_valid (partition_key, is_valid),
        FOREIGN KEY fk_machine_id (machine_id) REFERENCES tbl_machines (machine_id) ON DELETE CASCADE ON UPDATE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  ✓ tbl_raw_data');

    // Create tbl_error_log
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tbl_error_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        machine_id VARCHAR(50) NOT NULL,
        error_code VARCHAR(20) NOT NULL,
        error_message TEXT NOT NULL,
        error_details JSON,
        severity ENUM('INFO', 'WARNING', 'ERROR', 'CRITICAL') DEFAULT 'ERROR',
        resolved BOOLEAN DEFAULT FALSE,
        resolved_at TIMESTAMP NULL,
        resolution_note TEXT,
        error_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_machine_id (machine_id),
        KEY idx_error_code (error_code),
        KEY idx_error_timestamp (error_timestamp),
        KEY idx_resolved (resolved),
        KEY idx_severity (severity),
        KEY idx_composite_machine_severity (machine_id, severity, error_timestamp DESC),
        FOREIGN KEY fk_machine_id_error (machine_id) REFERENCES tbl_machines (machine_id) ON DELETE CASCADE ON UPDATE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  ✓ tbl_error_log');

    // Create tbl_sync_log
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tbl_sync_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        machine_id VARCHAR(50) NOT NULL,
        batch_id VARCHAR(100) UNIQUE,
        batch_count INT NOT NULL,
        success_count INT NOT NULL,
        failed_count INT DEFAULT 0,
        duplicate_count INT DEFAULT 0,
        duration_ms INT,
        data_size_bytes BIGINT,
        status ENUM('SUCCESS', 'PARTIAL', 'FAILED') NOT NULL,
        error_message TEXT,
        sync_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        completed_at TIMESTAMP NULL,
        KEY idx_machine_id (machine_id),
        KEY idx_sync_timestamp (sync_timestamp),
        KEY idx_status (status),
        KEY idx_composite_machine_status (machine_id, status, sync_timestamp DESC),
        FOREIGN KEY fk_machine_id_sync (machine_id) REFERENCES tbl_machines (machine_id) ON DELETE CASCADE ON UPDATE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  ✓ tbl_sync_log');

    // Create tbl_message_dedup
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tbl_message_dedup (
        id INT AUTO_INCREMENT PRIMARY KEY,
        machine_id VARCHAR(50) NOT NULL,
        message_id VARCHAR(100) NOT NULL,
        data_hash VARCHAR(64) NOT NULL,
        first_received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        duplicate_count INT DEFAULT 0,
        last_duplicate_at TIMESTAMP NULL,
        archived BOOLEAN DEFAULT FALSE,
        archived_at TIMESTAMP NULL,
        UNIQUE KEY uk_message_id (message_id),
        KEY idx_machine_id (machine_id),
        KEY idx_first_received_at (first_received_at),
        KEY idx_archived (archived),
        FOREIGN KEY fk_machine_id_dedup (machine_id) REFERENCES tbl_machines (machine_id) ON DELETE CASCADE ON UPDATE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  ✓ tbl_message_dedup');

    // Create tbl_protocol_config
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tbl_protocol_config (
        id INT AUTO_INCREMENT PRIMARY KEY,
        machine_id VARCHAR(50) NOT NULL UNIQUE,
        rs232_enabled BOOLEAN DEFAULT FALSE,
        rs232_port VARCHAR(20),
        rs232_baudrate INT DEFAULT 9600,
        rs232_databits INT DEFAULT 8,
        rs232_stopbits INT DEFAULT 1,
        rs232_parity VARCHAR(10) DEFAULT 'NONE',
        rs232_handshake VARCHAR(10) DEFAULT 'NONE',
        lan_enabled BOOLEAN DEFAULT FALSE,
        lan_host VARCHAR(50),
        lan_port INT DEFAULT 502,
        lan_timeout_ms INT DEFAULT 5000,
        lan_retry_count INT DEFAULT 3,
        file_enabled BOOLEAN DEFAULT FALSE,
        file_watch_path VARCHAR(500),
        file_pattern VARCHAR(100) DEFAULT '*.csv',
        file_encoding VARCHAR(20) DEFAULT 'UTF-8',
        checksum_enabled BOOLEAN DEFAULT TRUE,
        checksum_type VARCHAR(20) DEFAULT 'CUSTOM',
        terminator_char VARCHAR(10) DEFAULT '\\r\\n',
        max_payload_size INT DEFAULT 65536,
        sync_interval_ms INT DEFAULT 30000,
        batch_size INT DEFAULT 500,
        cache_flush_on_sync BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY fk_machine_id_config (machine_id) REFERENCES tbl_machines (machine_id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  ✓ tbl_protocol_config');

    // Create tbl_middleware_cache
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tbl_middleware_cache (
        id INT AUTO_INCREMENT PRIMARY KEY,
        machine_id VARCHAR(50) NOT NULL UNIQUE,
        cache_size_bytes BIGINT DEFAULT 0,
        pending_count INT DEFAULT 0,
        last_sync_attempt TIMESTAMP NULL,
        last_sync_success TIMESTAMP NULL,
        cache_utilization_percent DECIMAL(5, 2) DEFAULT 0,
        is_healthy BOOLEAN DEFAULT TRUE,
        health_check_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        middleware_version VARCHAR(20),
        middleware_last_seen TIMESTAMP NULL,
        middleware_status ENUM('RUNNING', 'STOPPED', 'ERROR', 'UNKNOWN') DEFAULT 'UNKNOWN',
        KEY idx_machine_id (machine_id),
        KEY idx_is_healthy (is_healthy),
        FOREIGN KEY fk_machine_id_cache (machine_id) REFERENCES tbl_machines (machine_id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  ✓ tbl_middleware_cache');

    // Create tbl_data_transformation_log
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS tbl_data_transformation_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        raw_data_id BIGINT NOT NULL,
        machine_id VARCHAR(50) NOT NULL,
        transformation_status ENUM('PENDING', 'IN_PROGRESS', 'SUCCESS', 'FAILED') DEFAULT 'PENDING',
        transformation_error TEXT,
        extracted_values JSON,
        normalization_applied TEXT,
        started_at TIMESTAMP NULL,
        completed_at TIMESTAMP NULL,
        duration_ms INT,
        worker_id VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_machine_id (machine_id),
        KEY idx_transformation_status (transformation_status),
        KEY idx_raw_data_id (raw_data_id),
        FOREIGN KEY fk_raw_data_id (raw_data_id) REFERENCES tbl_raw_data (id) ON DELETE CASCADE,
        FOREIGN KEY fk_machine_id_transform (machine_id) REFERENCES tbl_machines (machine_id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `);
    console.log('  ✓ tbl_data_transformation_log');

    console.log('\n✅ All tables created successfully in acca_mdata database!');

    // Verify tables
    const [tables] = await connection.execute('SHOW TABLES LIKE "tbl_%" FROM acca_mdata');
    console.log('\n📋 Created tables:');
    tables.forEach(t => {
      const tableName = Object.values(t)[0];
      console.log('   ' + tableName);
    });

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await connection.end();
  }
}

setupDatabase();
