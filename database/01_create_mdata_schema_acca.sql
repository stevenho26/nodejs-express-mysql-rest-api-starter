-- ============================================
-- MData API - Lab Data Collection System
-- Database Setup Script (PHASE 1) - For Existing acca_mdata
-- ============================================
-- Version: 2.0
-- Date: 2026-04-22
-- Description: Add raw data collection tables to existing acca_mdata database
-- NOTE: This script uses the existing acca_mdata database

-- ============================================
-- 1. USE EXISTING DATABASE
-- ============================================
USE `acca_mdata`;

-- ============================================
-- 2. CREATE MACHINES TABLE (Machine Configuration)
-- ============================================
CREATE TABLE IF NOT EXISTS `tbl_machines` (
  `id` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Primary Key',
  `machine_id` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Unique identifier from config',
  `name` VARCHAR(100) NOT NULL COMMENT 'Machine name/label',
  `location` VARCHAR(100) COMMENT 'Physical location in lab',
  `device_type` VARCHAR(50) NOT NULL COMMENT 'Device type: Analyzer, Centrifuge, etc.',
  `description` TEXT COMMENT 'Machine description',
  
  -- Connection Configuration
  `protocols` JSON NOT NULL COMMENT 'Supported protocols config (RS232, LAN, FILE)',
  `status` ENUM('ACTIVE', 'INACTIVE', 'ERROR', 'MAINTENANCE') DEFAULT 'ACTIVE' COMMENT 'Machine status',
  
  -- Last Activity
  `last_sync` TIMESTAMP NULL COMMENT 'Last successful sync time',
  `last_heartbeat` TIMESTAMP NULL COMMENT 'Last heartbeat from middleware',
  `total_records_sent` BIGINT DEFAULT 0 COMMENT 'Total records sent from this machine',
  `total_errors` INT DEFAULT 0 COMMENT 'Total errors encountered',
  
  -- Metadata
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Indexes
  UNIQUE KEY `uk_machine_id` (`machine_id`),
  KEY `idx_status` (`status`),
  KEY `idx_device_type` (`device_type`),
  KEY `idx_last_sync` (`last_sync`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Machine configuration and metadata';

-- ============================================
-- 3. CREATE RAW_DATA TABLE (Partitioned by Quarter)
-- ============================================
CREATE TABLE IF NOT EXISTS `tbl_raw_data` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT 'Primary Key',
  `machine_id` VARCHAR(50) NOT NULL COMMENT 'Foreign key to machines.machine_id',
  `message_id` VARCHAR(100) NOT NULL COMMENT 'Unique message identifier (UUID)',
  `protocol` VARCHAR(20) NOT NULL COMMENT 'Protocol used: RS232, LAN, FILE',
  
  -- Raw Data Storage
  `raw_payload` LONGTEXT NOT NULL COMMENT 'Complete raw data as received (JSON format)',
  `raw_payload_hash` VARCHAR(64) COMMENT 'SHA256 hash for deduplication check',
  
  -- Validation & Error Handling
  `is_valid` BOOLEAN DEFAULT TRUE COMMENT 'Data validation status',
  `validation_error` VARCHAR(500) COMMENT 'Error message if validation failed',
  `error_code` VARCHAR(20) COMMENT 'Error code for categorization',
  
  -- Metadata
  `received_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When data was received by API',
  `middleware_timestamp` TIMESTAMP NULL COMMENT 'When data was captured by middleware',
  `partition_key` VARCHAR(20) NOT NULL COMMENT 'Partition identifier (2024_Q1, 2024_Q2, etc.)',
  `batch_id` VARCHAR(100) COMMENT 'Batch identifier for correlation',
  
  -- Indexes
  UNIQUE KEY `uk_message_id` (`message_id`),
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_received_at` (`received_at`),
  KEY `idx_partition_key` (`partition_key`),
  KEY `idx_is_valid` (`is_valid`),
  KEY `idx_protocol` (`protocol`),
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Raw data collection table (partitioned by quarter)'

-- Add Partitions (Quarters)
PARTITION BY LIST COLUMNS (partition_key) (
  PARTITION p2024_q1 VALUES IN ('2024_Q1') COMMENT='Q1 2024',
  PARTITION p2024_q2 VALUES IN ('2024_Q2') COMMENT='Q2 2024',
  PARTITION p2024_q3 VALUES IN ('2024_Q3') COMMENT='Q3 2024',
  PARTITION p2024_q4 VALUES IN ('2024_Q4') COMMENT='Q4 2024',
  PARTITION p2025_q1 VALUES IN ('2025_Q1') COMMENT='Q1 2025',
  PARTITION p2025_q2 VALUES IN ('2025_Q2') COMMENT='Q2 2025',
  PARTITION p2025_q3 VALUES IN ('2025_Q3') COMMENT='Q3 2025',
  PARTITION p2025_q4 VALUES IN ('2025_Q4') COMMENT='Q4 2025',
  PARTITION p2026_q1 VALUES IN ('2026_Q1') COMMENT='Q1 2026',
  PARTITION p2026_q2 VALUES IN ('2026_Q2') COMMENT='Q2 2026',
  PARTITION pdefault VALUES IN (DEFAULT) COMMENT='Default partition for undefined quarters'
);

-- ============================================
-- 4. CREATE ERROR_LOG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `tbl_error_log` (
  `id` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Primary Key',
  `machine_id` VARCHAR(50) NOT NULL COMMENT 'Foreign key to tbl_machines.machine_id',
  `error_code` VARCHAR(20) NOT NULL COMMENT 'Error code for categorization',
  `error_message` TEXT NOT NULL COMMENT 'Detailed error message',
  `error_details` JSON COMMENT 'Additional error context (stack trace, etc.)',
  `severity` ENUM('INFO', 'WARNING', 'ERROR', 'CRITICAL') DEFAULT 'ERROR' COMMENT 'Error severity level',
  
  -- Status
  `resolved` BOOLEAN DEFAULT FALSE COMMENT 'Whether error has been resolved',
  `resolved_at` TIMESTAMP NULL COMMENT 'When error was resolved',
  `resolution_note` TEXT COMMENT 'Resolution details',
  
  -- Timestamps
  `error_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When error occurred',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Indexes
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_error_code` (`error_code`),
  KEY `idx_error_timestamp` (`error_timestamp`),
  KEY `idx_resolved` (`resolved`),
  KEY `idx_severity` (`severity`),
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Error and alert log from middleware';

-- ============================================
-- 5. CREATE SYNC_LOG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `tbl_sync_log` (
  `id` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Primary Key',
  `machine_id` VARCHAR(50) NOT NULL COMMENT 'Foreign key to tbl_machines.machine_id',
  
  -- Sync Details
  `batch_id` VARCHAR(100) UNIQUE COMMENT 'Unique batch identifier',
  `batch_count` INT NOT NULL COMMENT 'Total records in batch',
  `success_count` INT NOT NULL COMMENT 'Successfully processed records',
  `failed_count` INT DEFAULT 0 COMMENT 'Failed records',
  `duplicate_count` INT DEFAULT 0 COMMENT 'Duplicate records detected',
  
  -- Performance Metrics
  `duration_ms` INT COMMENT 'Sync duration in milliseconds',
  `data_size_bytes` BIGINT COMMENT 'Total data size in bytes',
  
  -- Status
  `status` ENUM('SUCCESS', 'PARTIAL', 'FAILED') NOT NULL COMMENT 'Overall sync status',
  `error_message` TEXT COMMENT 'Error message if failed',
  
  -- Timestamps
  `sync_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When sync occurred',
  `completed_at` TIMESTAMP NULL COMMENT 'When sync completed',
  
  -- Indexes
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_sync_timestamp` (`sync_timestamp`),
  KEY `idx_status` (`status`),
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Sync event log for tracking data transfers';

-- ============================================
-- 6. CREATE MESSAGE_DEDUP TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `tbl_message_dedup` (
  `id` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Primary Key',
  `machine_id` VARCHAR(50) NOT NULL COMMENT 'Foreign key to tbl_machines.machine_id',
  `message_id` VARCHAR(100) NOT NULL COMMENT 'Message identifier for deduplication',
  `data_hash` VARCHAR(64) NOT NULL COMMENT 'SHA256 hash of payload',
  
  -- Tracking
  `first_received_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'First time received',
  `duplicate_count` INT DEFAULT 0 COMMENT 'Number of duplicates detected',
  `last_duplicate_at` TIMESTAMP NULL COMMENT 'Last time duplicate was detected',
  
  -- Cleanup
  `archived` BOOLEAN DEFAULT FALSE COMMENT 'Whether marked for archival',
  `archived_at` TIMESTAMP NULL,
  
  -- Indexes
  UNIQUE KEY `uk_message_id` (`message_id`),
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_first_received_at` (`first_received_at`),
  KEY `idx_archived` (`archived`),
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Message deduplication tracking table';

-- ============================================
-- 7. CREATE PROTOCOL_CONFIG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `tbl_protocol_config` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL UNIQUE,
  
  -- RS232 Configuration
  `rs232_enabled` BOOLEAN DEFAULT FALSE,
  `rs232_port` VARCHAR(20) COMMENT 'COM port: COM1, COM2, etc.',
  `rs232_baudrate` INT DEFAULT 9600 COMMENT 'Baud rate: 9600, 19200, 115200, etc.',
  `rs232_databits` INT DEFAULT 8,
  `rs232_stopbits` INT DEFAULT 1,
  `rs232_parity` VARCHAR(10) DEFAULT 'NONE' COMMENT 'NONE, ODD, EVEN',
  `rs232_handshake` VARCHAR(10) DEFAULT 'NONE' COMMENT 'NONE, XON_XOFF, RTS_CTS',
  
  -- LAN/TCP Configuration
  `lan_enabled` BOOLEAN DEFAULT FALSE,
  `lan_host` VARCHAR(50) COMMENT 'IP address or hostname',
  `lan_port` INT DEFAULT 502 COMMENT 'Port number (typically 502 for Modbus TCP)',
  `lan_timeout_ms` INT DEFAULT 5000,
  `lan_retry_count` INT DEFAULT 3,
  
  -- File Watcher Configuration
  `file_enabled` BOOLEAN DEFAULT FALSE,
  `file_watch_path` VARCHAR(500) COMMENT 'Directory path to monitor',
  `file_pattern` VARCHAR(100) DEFAULT '*.csv' COMMENT 'File pattern to watch: *.csv, *.xlsx, etc.',
  `file_encoding` VARCHAR(20) DEFAULT 'UTF-8',
  
  -- Validation Configuration
  `checksum_enabled` BOOLEAN DEFAULT TRUE,
  `checksum_type` VARCHAR(20) DEFAULT 'CUSTOM' COMMENT 'Custom terminator or CRC16',
  `terminator_char` VARCHAR(10) DEFAULT '\\r\\n' COMMENT 'String terminator',
  `max_payload_size` INT DEFAULT 65536 COMMENT 'Maximum payload size in bytes',
  
  -- Sync Configuration
  `sync_interval_ms` INT DEFAULT 30000 COMMENT 'Sync interval in milliseconds',
  `batch_size` INT DEFAULT 500 COMMENT 'Number of records per batch',
  `cache_flush_on_sync` BOOLEAN DEFAULT TRUE,
  
  -- Metadata
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Protocol-specific configuration for each machine';

-- ============================================
-- 8. CREATE MIDDLEWARE_CACHE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `tbl_middleware_cache` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL UNIQUE,
  
  -- Cache Status
  `cache_size_bytes` BIGINT DEFAULT 0 COMMENT 'Current cache size',
  `pending_count` INT DEFAULT 0 COMMENT 'Number of pending items',
  `last_sync_attempt` TIMESTAMP NULL COMMENT 'Last attempt to sync',
  `last_sync_success` TIMESTAMP NULL COMMENT 'Last successful sync',
  
  -- Cache Health
  `cache_utilization_percent` DECIMAL(5, 2) DEFAULT 0 COMMENT 'Cache utilization percentage',
  `is_healthy` BOOLEAN DEFAULT TRUE,
  `health_check_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- Middleware Status
  `middleware_version` VARCHAR(20),
  `middleware_last_seen` TIMESTAMP NULL,
  `middleware_status` ENUM('RUNNING', 'STOPPED', 'ERROR', 'UNKNOWN') DEFAULT 'UNKNOWN',
  
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_is_healthy` (`is_healthy`),
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Middleware cache and health status tracking';

-- ============================================
-- 9. CREATE DATA_TRANSFORMATION_LOG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS `tbl_data_transformation_log` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `raw_data_id` BIGINT NOT NULL,
  `machine_id` VARCHAR(50) NOT NULL,
  
  -- Transformation Process
  `transformation_status` ENUM('PENDING', 'IN_PROGRESS', 'SUCCESS', 'FAILED') DEFAULT 'PENDING',
  `transformation_error` TEXT COMMENT 'Error message if failed',
  
  -- Extracted Data (for reference)
  `extracted_values` JSON COMMENT 'Extracted key-value pairs',
  `normalization_applied` TEXT COMMENT 'Applied normalization rules',
  
  -- Tracking
  `started_at` TIMESTAMP NULL,
  `completed_at` TIMESTAMP NULL,
  `duration_ms` INT COMMENT 'Processing duration',
  
  -- Metadata
  `worker_id` VARCHAR(50) COMMENT 'Which worker processed this',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_transformation_status` (`transformation_status`),
  KEY `idx_raw_data_id` (`raw_data_id`),
  FOREIGN KEY `fk_raw_data_id` (`raw_data_id`) REFERENCES `tbl_raw_data` (`id`) ON DELETE CASCADE,
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Data transformation processing log (Phase 2 preparation)';

-- ============================================
-- 10. CREATE VIEWS
-- ============================================

-- View: Active Machines Summary
CREATE OR REPLACE VIEW `v_active_machines_summary` AS
SELECT 
  m.machine_id,
  m.name,
  m.device_type,
  m.status,
  m.last_sync,
  m.last_heartbeat,
  m.total_records_sent,
  m.total_errors,
  TIMEDIFF(NOW(), m.last_heartbeat) AS time_since_heartbeat,
  mc.pending_count,
  mc.cache_size_bytes,
  mc.middleware_status,
  (SELECT COUNT(*) FROM tbl_raw_data WHERE machine_id = m.machine_id AND received_at > DATE_SUB(NOW(), INTERVAL 1 DAY)) AS records_24h
FROM tbl_machines m
LEFT JOIN tbl_middleware_cache mc ON m.machine_id = mc.machine_id
WHERE m.status = 'ACTIVE'
ORDER BY m.last_heartbeat DESC;

-- View: Error Summary Last 7 Days
CREATE OR REPLACE VIEW `v_error_summary_7days` AS
SELECT 
  machine_id,
  error_code,
  severity,
  COUNT(*) AS error_count,
  MAX(error_timestamp) AS last_error_time,
  SUM(CASE WHEN resolved = TRUE THEN 1 ELSE 0 END) AS resolved_count
FROM tbl_error_log
WHERE error_timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY machine_id, error_code, severity
ORDER BY error_count DESC;

-- View: Data Quality Report
CREATE OR REPLACE VIEW `v_data_quality_report` AS
SELECT 
  machine_id,
  COUNT(*) AS total_records,
  SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) AS valid_records,
  SUM(CASE WHEN is_valid = FALSE THEN 1 ELSE 0 END) AS invalid_records,
  ROUND(100.0 * SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS valid_percentage,
  MIN(received_at) AS first_record,
  MAX(received_at) AS last_record,
  DATE(NOW()) AS report_date
FROM tbl_raw_data
WHERE received_at > DATE_SUB(NOW(), INTERVAL 1 DAY)
GROUP BY machine_id
ORDER BY valid_percentage ASC;

-- ============================================
-- 11. CREATE INDEXES FOR OPTIMIZATION
-- ============================================

-- Composite indexes for common queries
ALTER TABLE tbl_raw_data ADD INDEX idx_composite_machine_received 
  (machine_id, received_at DESC);
ALTER TABLE tbl_raw_data ADD INDEX idx_composite_partition_valid 
  (partition_key, is_valid);
ALTER TABLE tbl_error_log ADD INDEX idx_composite_machine_severity 
  (machine_id, severity, error_timestamp DESC);
ALTER TABLE tbl_sync_log ADD INDEX idx_composite_machine_status 
  (machine_id, status, sync_timestamp DESC);

-- ============================================
-- 12. CREATE STORED PROCEDURES
-- ============================================

-- Procedure: Get partition size (for monitoring)
DELIMITER //
CREATE PROCEDURE sp_get_partition_sizes()
BEGIN
  SELECT 
    partition_name,
    ROUND(data_length / 1024 / 1024, 2) AS size_mb,
    partition_expression,
    partition_method
  FROM information_schema.partitions
  WHERE table_schema = 'acca_mdata' 
    AND table_name = 'tbl_raw_data'
    AND partition_name IS NOT NULL
  ORDER BY data_length DESC;
END //
DELIMITER ;

-- Procedure: Cleanup old message dedup entries
DELIMITER //
CREATE PROCEDURE sp_cleanup_old_dedup_entries(IN days_old INT)
BEGIN
  UPDATE tbl_message_dedup 
  SET archived = TRUE, archived_at = NOW()
  WHERE first_received_at < DATE_SUB(NOW(), INTERVAL days_old DAY)
    AND archived = FALSE;
  
  SELECT ROW_COUNT() AS rows_archived;
END //
DELIMITER ;

-- Procedure: Generate daily health report
DELIMITER //
CREATE PROCEDURE sp_generate_health_report()
BEGIN
  SELECT 
    DATE(NOW()) AS report_date,
    COUNT(DISTINCT m.machine_id) AS active_machines,
    (SELECT COUNT(*) FROM tbl_raw_data WHERE received_at > DATE_SUB(NOW(), INTERVAL 1 DAY)) AS records_today,
    (SELECT COUNT(*) FROM tbl_error_log WHERE error_timestamp > DATE_SUB(NOW(), INTERVAL 1 DAY) AND resolved = FALSE) AS unresolved_errors,
    (SELECT AVG(success_count / batch_count * 100) FROM tbl_sync_log WHERE sync_timestamp > DATE_SUB(NOW(), INTERVAL 1 DAY)) AS avg_sync_success_rate
  FROM tbl_machines m;
END //
DELIMITER ;

-- ============================================
-- 13. CREATE TRIGGERS
-- ============================================

-- Trigger: Update machines total_records_sent when new raw_data inserted
DELIMITER //
CREATE TRIGGER trg_update_machine_record_count
AFTER INSERT ON tbl_raw_data
FOR EACH ROW
BEGIN
  UPDATE tbl_machines 
  SET total_records_sent = total_records_sent + 1,
      last_sync = NOW()
  WHERE machine_id = NEW.machine_id;
END //
DELIMITER ;

-- Trigger: Update machines total_errors when error logged
DELIMITER //
CREATE TRIGGER trg_update_machine_error_count
AFTER INSERT ON tbl_error_log
FOR EACH ROW
BEGIN
  UPDATE tbl_machines 
  SET total_errors = total_errors + 1
  WHERE machine_id = NEW.machine_id;
END //
DELIMITER ;

-- Trigger: Track deduplication
DELIMITER //
CREATE TRIGGER trg_track_duplicate
BEFORE INSERT ON tbl_raw_data
FOR EACH ROW
BEGIN
  DECLARE duplicate_exists INT;
  
  SELECT COUNT(*) INTO duplicate_exists 
  FROM tbl_message_dedup 
  WHERE message_id = NEW.message_id;
  
  IF duplicate_exists > 0 THEN
    UPDATE tbl_message_dedup 
    SET duplicate_count = duplicate_count + 1,
        last_duplicate_at = NOW()
    WHERE message_id = NEW.message_id;
  ELSE
    INSERT INTO tbl_message_dedup (machine_id, message_id, data_hash)
    VALUES (NEW.machine_id, NEW.message_id, NEW.raw_payload_hash);
  END IF;
END //
DELIMITER ;

-- ============================================
-- 14. FINAL VERIFICATION
-- ============================================

SELECT '✅ Tables created in acca_mdata database:' AS info;
SHOW TABLES;

SELECT '✅ Partitions info:' AS info;
SELECT 
  partition_name, 
  partition_expression,
  ROUND(data_length / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.partitions
WHERE table_schema = 'acca_mdata' 
  AND table_name = 'tbl_raw_data'
  AND partition_name IS NOT NULL
ORDER BY partition_name;

-- ============================================
-- END OF SCRIPT
-- ============================================
