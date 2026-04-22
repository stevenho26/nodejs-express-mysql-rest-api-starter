-- ============================================
-- MData API - Lab Data Collection System
-- Clean up and create tables in acca_mdata
-- ============================================

USE `acca_mdata`;

-- Drop existing tables if they exist
DROP TABLE IF EXISTS `tbl_data_transformation_log`;
DROP TABLE IF EXISTS `tbl_middleware_cache`;
DROP TABLE IF EXISTS `tbl_protocol_config`;
DROP TABLE IF EXISTS `tbl_message_dedup`;
DROP TABLE IF EXISTS `tbl_sync_log`;
DROP TABLE IF EXISTS `tbl_error_log`;
DROP TABLE IF EXISTS `tbl_raw_data`;
DROP TABLE IF EXISTS `tbl_machines`;

-- Drop views if they exist
DROP VIEW IF EXISTS `v_active_machines_summary`;
DROP VIEW IF EXISTS `v_error_summary_7days`;
DROP VIEW IF EXISTS `v_data_quality_report`;

-- Drop procedures if they exist
DROP PROCEDURE IF EXISTS `sp_get_partition_sizes`;
DROP PROCEDURE IF EXISTS `sp_cleanup_old_dedup_entries`;
DROP PROCEDURE IF EXISTS `sp_generate_health_report`;

-- Drop triggers if they exist
DROP TRIGGER IF EXISTS `trg_update_machine_record_count`;
DROP TRIGGER IF EXISTS `trg_update_machine_error_count`;
DROP TRIGGER IF EXISTS `trg_track_duplicate`;

-- ============================================
-- 1. CREATE MACHINES TABLE
-- ============================================
CREATE TABLE `tbl_machines` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL UNIQUE,
  `name` VARCHAR(100) NOT NULL,
  `location` VARCHAR(100),
  `device_type` VARCHAR(50) NOT NULL,
  `description` TEXT,
  
  `protocols` JSON NOT NULL,
  `status` ENUM('ACTIVE', 'INACTIVE', 'ERROR', 'MAINTENANCE') DEFAULT 'ACTIVE',
  
  `last_sync` TIMESTAMP NULL,
  `last_heartbeat` TIMESTAMP NULL,
  `total_records_sent` BIGINT DEFAULT 0,
  `total_errors` INT DEFAULT 0,
  
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  UNIQUE KEY `uk_machine_id` (`machine_id`),
  KEY `idx_status` (`status`),
  KEY `idx_device_type` (`device_type`),
  KEY `idx_last_sync` (`last_sync`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 2. CREATE RAW_DATA TABLE
-- ============================================
CREATE TABLE `tbl_raw_data` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL,
  `message_id` VARCHAR(100) NOT NULL,
  `protocol` VARCHAR(20) NOT NULL,
  
  `raw_payload` LONGTEXT NOT NULL,
  `raw_payload_hash` VARCHAR(64),
  
  `is_valid` BOOLEAN DEFAULT TRUE,
  `validation_error` VARCHAR(500),
  `error_code` VARCHAR(20),
  
  `received_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `middleware_timestamp` TIMESTAMP NULL,
  `partition_key` VARCHAR(20) NOT NULL,
  `batch_id` VARCHAR(100),
  
  UNIQUE KEY `uk_message_id` (`message_id`),
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_received_at` (`received_at`),
  KEY `idx_partition_key` (`partition_key`),
  KEY `idx_is_valid` (`is_valid`),
  KEY `idx_protocol` (`protocol`),
  KEY `idx_composite_machine_received` (`machine_id`, `received_at` DESC),
  KEY `idx_composite_partition_valid` (`partition_key`, `is_valid`),
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 3. CREATE ERROR_LOG TABLE
-- ============================================
CREATE TABLE `tbl_error_log` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL,
  `error_code` VARCHAR(20) NOT NULL,
  `error_message` TEXT NOT NULL,
  `error_details` JSON,
  `severity` ENUM('INFO', 'WARNING', 'ERROR', 'CRITICAL') DEFAULT 'ERROR',
  
  `resolved` BOOLEAN DEFAULT FALSE,
  `resolved_at` TIMESTAMP NULL,
  `resolution_note` TEXT,
  
  `error_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_error_code` (`error_code`),
  KEY `idx_error_timestamp` (`error_timestamp`),
  KEY `idx_resolved` (`resolved`),
  KEY `idx_severity` (`severity`),
  KEY `idx_composite_machine_severity` (`machine_id`, `severity`, `error_timestamp` DESC),
  FOREIGN KEY `fk_machine_id_error` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 4. CREATE SYNC_LOG TABLE
-- ============================================
CREATE TABLE `tbl_sync_log` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL,
  
  `batch_id` VARCHAR(100) UNIQUE,
  `batch_count` INT NOT NULL,
  `success_count` INT NOT NULL,
  `failed_count` INT DEFAULT 0,
  `duplicate_count` INT DEFAULT 0,
  
  `duration_ms` INT,
  `data_size_bytes` BIGINT,
  
  `status` ENUM('SUCCESS', 'PARTIAL', 'FAILED') NOT NULL,
  `error_message` TEXT,
  
  `sync_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `completed_at` TIMESTAMP NULL,
  
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_sync_timestamp` (`sync_timestamp`),
  KEY `idx_status` (`status`),
  KEY `idx_composite_machine_status` (`machine_id`, `status`, `sync_timestamp` DESC),
  FOREIGN KEY `fk_machine_id_sync` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 5. CREATE MESSAGE_DEDUP TABLE
-- ============================================
CREATE TABLE `tbl_message_dedup` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL,
  `message_id` VARCHAR(100) NOT NULL,
  `data_hash` VARCHAR(64) NOT NULL,
  
  `first_received_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `duplicate_count` INT DEFAULT 0,
  `last_duplicate_at` TIMESTAMP NULL,
  
  `archived` BOOLEAN DEFAULT FALSE,
  `archived_at` TIMESTAMP NULL,
  
  UNIQUE KEY `uk_message_id` (`message_id`),
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_first_received_at` (`first_received_at`),
  KEY `idx_archived` (`archived`),
  FOREIGN KEY `fk_machine_id_dedup` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 6. CREATE PROTOCOL_CONFIG TABLE
-- ============================================
CREATE TABLE `tbl_protocol_config` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL UNIQUE,
  
  `rs232_enabled` BOOLEAN DEFAULT FALSE,
  `rs232_port` VARCHAR(20),
  `rs232_baudrate` INT DEFAULT 9600,
  `rs232_databits` INT DEFAULT 8,
  `rs232_stopbits` INT DEFAULT 1,
  `rs232_parity` VARCHAR(10) DEFAULT 'NONE',
  `rs232_handshake` VARCHAR(10) DEFAULT 'NONE',
  
  `lan_enabled` BOOLEAN DEFAULT FALSE,
  `lan_host` VARCHAR(50),
  `lan_port` INT DEFAULT 502,
  `lan_timeout_ms` INT DEFAULT 5000,
  `lan_retry_count` INT DEFAULT 3,
  
  `file_enabled` BOOLEAN DEFAULT FALSE,
  `file_watch_path` VARCHAR(500),
  `file_pattern` VARCHAR(100) DEFAULT '*.csv',
  `file_encoding` VARCHAR(20) DEFAULT 'UTF-8',
  
  `checksum_enabled` BOOLEAN DEFAULT TRUE,
  `checksum_type` VARCHAR(20) DEFAULT 'CUSTOM',
  `terminator_char` VARCHAR(10) DEFAULT '\r\n',
  `max_payload_size` INT DEFAULT 65536,
  
  `sync_interval_ms` INT DEFAULT 30000,
  `batch_size` INT DEFAULT 500,
  `cache_flush_on_sync` BOOLEAN DEFAULT TRUE,
  
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY `fk_machine_id_config` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 7. CREATE MIDDLEWARE_CACHE TABLE
-- ============================================
CREATE TABLE `tbl_middleware_cache` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL UNIQUE,
  
  `cache_size_bytes` BIGINT DEFAULT 0,
  `pending_count` INT DEFAULT 0,
  `last_sync_attempt` TIMESTAMP NULL,
  `last_sync_success` TIMESTAMP NULL,
  
  `cache_utilization_percent` DECIMAL(5, 2) DEFAULT 0,
  `is_healthy` BOOLEAN DEFAULT TRUE,
  `health_check_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  `middleware_version` VARCHAR(20),
  `middleware_last_seen` TIMESTAMP NULL,
  `middleware_status` ENUM('RUNNING', 'STOPPED', 'ERROR', 'UNKNOWN') DEFAULT 'UNKNOWN',
  
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_is_healthy` (`is_healthy`),
  FOREIGN KEY `fk_machine_id_cache` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 8. CREATE DATA_TRANSFORMATION_LOG TABLE
-- ============================================
CREATE TABLE `tbl_data_transformation_log` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `raw_data_id` BIGINT NOT NULL,
  `machine_id` VARCHAR(50) NOT NULL,
  
  `transformation_status` ENUM('PENDING', 'IN_PROGRESS', 'SUCCESS', 'FAILED') DEFAULT 'PENDING',
  `transformation_error` TEXT,
  
  `extracted_values` JSON,
  `normalization_applied` TEXT,
  
  `started_at` TIMESTAMP NULL,
  `completed_at` TIMESTAMP NULL,
  `duration_ms` INT,
  
  `worker_id` VARCHAR(50),
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_transformation_status` (`transformation_status`),
  KEY `idx_raw_data_id` (`raw_data_id`),
  FOREIGN KEY `fk_raw_data_id` (`raw_data_id`) REFERENCES `tbl_raw_data` (`id`) ON DELETE CASCADE,
  FOREIGN KEY `fk_machine_id_transform` (`machine_id`) REFERENCES `tbl_machines` (`machine_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- 9. CREATE VIEWS
-- ============================================

CREATE VIEW `v_active_machines_summary` AS
SELECT 
  m.machine_id,
  m.name,
  m.device_type,
  m.status,
  m.last_sync,
  m.last_heartbeat,
  m.total_records_sent,
  m.total_errors,
  mc.pending_count,
  mc.cache_size_bytes,
  mc.middleware_status,
  (SELECT COUNT(*) FROM tbl_raw_data WHERE machine_id = m.machine_id AND received_at > DATE_SUB(NOW(), INTERVAL 1 DAY)) AS records_24h
FROM tbl_machines m
LEFT JOIN tbl_middleware_cache mc ON m.machine_id = mc.machine_id
WHERE m.status = 'ACTIVE'
ORDER BY m.last_heartbeat DESC;

CREATE VIEW `v_error_summary_7days` AS
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

CREATE VIEW `v_data_quality_report` AS
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
-- 10. CREATE STORED PROCEDURES
-- ============================================

DELIMITER //
CREATE PROCEDURE `sp_get_partition_sizes`()
BEGIN
  SELECT 
    'tbl_raw_data' as table_name,
    COUNT(*) as row_count,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb
  FROM information_schema.tables
  WHERE table_schema = 'acca_mdata' 
    AND table_name = 'tbl_raw_data';
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE `sp_cleanup_old_dedup_entries`(IN days_old INT)
BEGIN
  UPDATE tbl_message_dedup 
  SET archived = TRUE, archived_at = NOW()
  WHERE first_received_at < DATE_SUB(NOW(), INTERVAL days_old DAY)
    AND archived = FALSE;
  
  SELECT ROW_COUNT() AS rows_archived;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE `sp_generate_health_report`()
BEGIN
  SELECT 
    DATE(NOW()) AS report_date,
    COUNT(DISTINCT m.machine_id) AS active_machines,
    (SELECT COUNT(*) FROM tbl_raw_data WHERE received_at > DATE_SUB(NOW(), INTERVAL 1 DAY)) AS records_today,
    (SELECT COUNT(*) FROM tbl_error_log WHERE error_timestamp > DATE_SUB(NOW(), INTERVAL 1 DAY) AND resolved = FALSE) AS unresolved_errors
  FROM tbl_machines m;
END //
DELIMITER ;

-- ============================================
-- 11. CREATE TRIGGERS
-- ============================================

DELIMITER //
CREATE TRIGGER `trg_update_machine_record_count`
AFTER INSERT ON tbl_raw_data
FOR EACH ROW
BEGIN
  UPDATE tbl_machines 
  SET total_records_sent = total_records_sent + 1,
      last_sync = NOW()
  WHERE machine_id = NEW.machine_id;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER `trg_update_machine_error_count`
AFTER INSERT ON tbl_error_log
FOR EACH ROW
BEGIN
  UPDATE tbl_machines 
  SET total_errors = total_errors + 1
  WHERE machine_id = NEW.machine_id;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER `trg_track_duplicate`
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
-- VERIFICATION
-- ============================================

SELECT '✅ All tables created successfully!' AS status;
SHOW TABLES LIKE 'tbl_%';
