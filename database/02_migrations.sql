-- ============================================
-- Migration Scripts for MData Lab System
-- ============================================
-- This file contains migration queries to update schema
-- Run these after initial schema creation for enhancements

-- ============================================
-- Migration 1.1: Add machine status history
-- ============================================
CREATE TABLE IF NOT EXISTS `machine_status_history` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL,
  `old_status` ENUM('ACTIVE', 'INACTIVE', 'ERROR', 'MAINTENANCE'),
  `new_status` ENUM('ACTIVE', 'INACTIVE', 'ERROR', 'MAINTENANCE'),
  `reason` VARCHAR(255),
  `changed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_changed_at` (`changed_at`),
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `machines` (`machine_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Trigger for status history
DELIMITER //
CREATE TRIGGER trg_machine_status_change
AFTER UPDATE ON machines
FOR EACH ROW
BEGIN
  IF OLD.status != NEW.status THEN
    INSERT INTO machine_status_history (machine_id, old_status, new_status, reason)
    VALUES (NEW.machine_id, OLD.status, NEW.status, CONCAT('Status changed at ', NOW()));
  END IF;
END //
DELIMITER ;

-- ============================================
-- Migration 1.2: Add performance metrics table
-- ============================================
CREATE TABLE IF NOT EXISTS `performance_metrics` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL,
  `metric_date` DATE NOT NULL,
  
  -- Daily statistics
  `records_received` INT DEFAULT 0,
  `records_valid` INT DEFAULT 0,
  `records_invalid` INT DEFAULT 0,
  `data_size_mb` DECIMAL(10, 2) DEFAULT 0,
  
  -- Performance
  `avg_processing_time_ms` INT DEFAULT 0,
  `max_processing_time_ms` INT DEFAULT 0,
  `sync_count` INT DEFAULT 0,
  
  -- Errors
  `error_count` INT DEFAULT 0,
  `critical_errors` INT DEFAULT 0,
  
  -- Timestamps
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  UNIQUE KEY `uk_machine_date` (`machine_id`, `metric_date`),
  KEY `idx_metric_date` (`metric_date`),
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `machines` (`machine_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Migration 1.3: Add alerting/notification rules
-- ============================================
CREATE TABLE IF NOT EXISTS `alert_rules` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `rule_name` VARCHAR(100) NOT NULL,
  `description` TEXT,
  
  -- Condition
  `condition_type` ENUM('ERROR_THRESHOLD', 'NO_ACTIVITY', 'CACHE_FULL', 'INVALID_DATA_RATE', 'RESPONSE_TIME') NOT NULL,
  `threshold_value` INT,
  `time_window_minutes` INT DEFAULT 60,
  
  -- Action
  `alert_severity` ENUM('INFO', 'WARNING', 'ERROR', 'CRITICAL') DEFAULT 'WARNING',
  `enabled` BOOLEAN DEFAULT TRUE,
  `alert_channels` JSON COMMENT 'Email, SMS, Slack, etc.',
  
  -- Metadata
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY `idx_enabled` (`enabled`),
  KEY `idx_condition_type` (`condition_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Migration 1.4: Add audit log table
-- ============================================
CREATE TABLE IF NOT EXISTS `audit_log` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
  `action` VARCHAR(50) NOT NULL,
  `entity_type` VARCHAR(50) NOT NULL,
  `entity_id` VARCHAR(100),
  `changes` JSON,
  `performed_by` VARCHAR(100),
  `ip_address` VARCHAR(45),
  `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  KEY `idx_entity_type` (`entity_type`),
  KEY `idx_action` (`action`),
  KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Migration 1.5: Add API request tracking
-- ============================================
CREATE TABLE IF NOT EXISTS `api_request_log` (
  `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50),
  `endpoint` VARCHAR(255) NOT NULL,
  `method` VARCHAR(10) NOT NULL,
  `status_code` INT,
  `response_time_ms` INT,
  `request_size_bytes` INT,
  `response_size_bytes` INT,
  `error_message` TEXT,
  `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  KEY `idx_machine_id` (`machine_id`),
  KEY `idx_endpoint` (`endpoint`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_status_code` (`status_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='API request tracking for performance analysis';

-- ============================================
-- Migration 1.6: Add data retention policies
-- ============================================
CREATE TABLE IF NOT EXISTS `retention_policies` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL UNIQUE,
  `description` TEXT,
  
  -- Policy settings
  `table_name` VARCHAR(50) NOT NULL,
  `retention_days` INT NOT NULL COMMENT 'Keep data for N days',
  `archive_action` ENUM('DELETE', 'ARCHIVE', 'COMPRESS') DEFAULT 'ARCHIVE' COMMENT 'Action to perform on old data',
  `archive_storage_path` VARCHAR(500),
  
  -- Schedule
  `enabled` BOOLEAN DEFAULT TRUE,
  `cron_schedule` VARCHAR(50) COMMENT 'Cron expression for cleanup schedule',
  `last_execution` TIMESTAMP NULL,
  `next_execution` TIMESTAMP NULL,
  
  -- Metadata
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default retention policies
INSERT INTO retention_policies (name, description, table_name, retention_days, archive_action, enabled)
VALUES 
  ('raw_data_retention', 'Keep raw data for 24 months, archive older', 'raw_data', 730, 'ARCHIVE', TRUE),
  ('error_log_retention', 'Keep error logs for 12 months', 'error_log', 365, 'ARCHIVE', TRUE),
  ('sync_log_retention', 'Keep sync logs for 6 months', 'sync_log', 180, 'DELETE', TRUE),
  ('dedup_retention', 'Clean dedup entries after 30 days', 'message_dedup', 30, 'DELETE', TRUE)
ON DUPLICATE KEY UPDATE updated_at = NOW();

-- ============================================
-- Migration 1.7: Add machine grouping/categories
-- ============================================
CREATE TABLE IF NOT EXISTS `machine_groups` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `group_name` VARCHAR(100) NOT NULL UNIQUE,
  `description` TEXT,
  `color` VARCHAR(20) COMMENT 'For UI display',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  KEY `idx_group_name` (`group_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `machine_group_mapping` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50) NOT NULL,
  `group_id` INT NOT NULL,
  `assigned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE KEY `uk_machine_group` (`machine_id`, `group_id`),
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `machines` (`machine_id`) ON DELETE CASCADE,
  FOREIGN KEY `fk_group_id` (`group_id`) REFERENCES `machine_groups` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Migration 1.8: Add data transformation rules
-- ============================================
CREATE TABLE IF NOT EXISTS `transformation_rules` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `machine_id` VARCHAR(50),
  `rule_name` VARCHAR(100) NOT NULL,
  `description` TEXT,
  
  -- Rule definition
  `rule_type` ENUM('REGEX_EXTRACT', 'CSV_PARSE', 'XLSX_PARSE', 'JSON_MAP', 'CUSTOM_CODE') NOT NULL,
  `source_pattern` TEXT COMMENT 'Regex or parsing pattern',
  `target_fields` JSON COMMENT 'Target field mapping',
  
  -- Validation
  `validation_rules` JSON COMMENT 'Data validation constraints',
  `unit_conversion` JSON COMMENT 'Unit conversion rules',
  
  -- Status
  `enabled` BOOLEAN DEFAULT TRUE,
  `version` INT DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY `fk_machine_id` (`machine_id`) REFERENCES `machines` (`machine_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Migration 1.9: Add backup/restore info
-- ============================================
CREATE TABLE IF NOT EXISTS `backup_info` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `backup_name` VARCHAR(100) NOT NULL UNIQUE,
  `backup_type` ENUM('FULL', 'INCREMENTAL', 'PARTITION') DEFAULT 'FULL',
  `source_table` VARCHAR(50),
  `partition_name` VARCHAR(50),
  
  -- Backup details
  `backup_size_mb` DECIMAL(10, 2),
  `record_count` BIGINT,
  `backup_path` VARCHAR(500),
  
  -- Timing
  `started_at` TIMESTAMP,
  `completed_at` TIMESTAMP,
  `retention_until` DATE,
  
  -- Status
  `status` ENUM('PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'VERIFIED') DEFAULT 'PENDING',
  `error_message` TEXT,
  `verified` BOOLEAN DEFAULT FALSE,
  
  KEY `idx_backup_type` (`backup_type`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Migration 1.10: Add system configuration
-- ============================================
CREATE TABLE IF NOT EXISTS `system_config` (
  `config_key` VARCHAR(100) PRIMARY KEY,
  `config_value` TEXT NOT NULL,
  `description` TEXT,
  `config_type` ENUM('STRING', 'INTEGER', 'BOOLEAN', 'JSON') DEFAULT 'STRING',
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default config values
INSERT INTO system_config (config_key, config_value, description, config_type)
VALUES 
  ('max_batch_size', '1000', 'Maximum records per sync batch', 'INTEGER'),
  ('cache_warning_percent', '80', 'Alert when cache usage exceeds this %', 'INTEGER'),
  ('sync_timeout_seconds', '30', 'Sync operation timeout', 'INTEGER'),
  ('max_retries', '3', 'Maximum retry attempts for failed sync', 'INTEGER'),
  ('duplicate_check_enabled', 'true', 'Enable message deduplication', 'BOOLEAN'),
  ('partition_rotation_day', '1', 'Day of quarter to rotate partitions', 'INTEGER')
ON DUPLICATE KEY UPDATE updated_at = NOW();

-- ============================================
-- END OF MIGRATIONS
-- ============================================
