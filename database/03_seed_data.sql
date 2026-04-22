-- ============================================
-- Seed Data for MData Lab System
-- ============================================
-- This script populates sample data for testing
-- Run this AFTER 01_create_mdata_schema.sql

USE `mdata_lab`;

-- ============================================
-- 1. INSERT SAMPLE MACHINES
-- ============================================

INSERT INTO `machines` (
  machine_id, 
  name, 
  location, 
  device_type, 
  description,
  protocols,
  status
) VALUES 
(
  'LAB_001',
  'Analyzer - Main Lab',
  'Building A, Room 101',
  'Analyzer',
  'Hematology analyzer for blood tests',
  JSON_OBJECT(
    'RS232', JSON_OBJECT('port', 'COM3', 'baudrate', 9600),
    'FILE', JSON_OBJECT('path', 'C:\\\\Lab\\\\Results', 'pattern', '*.csv')
  ),
  'ACTIVE'
),
(
  'LAB_002',
  'Centrifuge - Biochemistry',
  'Building A, Room 102',
  'Centrifuge',
  'High-speed centrifuge for sample preparation',
  JSON_OBJECT(
    'LAN', JSON_OBJECT('host', '192.168.1.50', 'port', 502),
    'FILE', JSON_OBJECT('path', 'D:\\\\Equipment\\\\Centrifuge', 'pattern', '*.xlsx')
  ),
  'ACTIVE'
),
(
  'LAB_003',
  'Spectrophotometer - Research',
  'Building B, Room 201',
  'Spectrophotometer',
  'UV-Vis spectrophotometer for molecular analysis',
  JSON_OBJECT(
    'RS232', JSON_OBJECT('port', 'COM1', 'baudrate', 115200),
    'LAN', JSON_OBJECT('host', '192.168.1.51', 'port', 5000)
  ),
  'ACTIVE'
),
(
  'LAB_004',
  'Incubator - Culture',
  'Building B, Room 202',
  'Incubator',
  'Temperature and humidity controlled incubator',
  JSON_OBJECT(
    'LAN', JSON_OBJECT('host', '192.168.1.52', 'port', 502),
    'FILE', JSON_OBJECT('path', 'E:\\\\Culture\\\\Logs', 'pattern', '*.txt')
  ),
  'INACTIVE'
),
(
  'LAB_005',
  'PCR Machine - Genetics',
  'Building C, Room 301',
  'PCR',
  'Real-time PCR machine for genetic analysis',
  JSON_OBJECT(
    'RS232', JSON_OBJECT('port', 'COM5', 'baudrate', 9600),
    'FILE', JSON_OBJECT('path', 'F:\\\\PCR\\\\Results', 'pattern', '*.csv')
  ),
  'ACTIVE'
);

-- ============================================
-- 2. INSERT PROTOCOL CONFIGURATIONS
-- ============================================

INSERT INTO `protocol_config` (
  machine_id,
  rs232_enabled, rs232_port, rs232_baudrate, rs232_databits, rs232_stopbits,
  lan_enabled, lan_host, lan_port, lan_timeout_ms,
  file_enabled, file_watch_path, file_pattern,
  checksum_enabled, checksum_type, terminator_char,
  sync_interval_ms, batch_size
) VALUES
(
  'LAB_001',
  TRUE, 'COM3', 9600, 8, 1,
  FALSE, NULL, 502, 5000,
  TRUE, 'C:\\Lab\\Results', '*.csv',
  TRUE, 'CUSTOM', '\\r\\n',
  30000, 500
),
(
  'LAB_002',
  FALSE, NULL, 9600, 8, 1,
  TRUE, '192.168.1.50', 502, 5000,
  TRUE, 'D:\\Equipment\\Centrifuge', '*.xlsx',
  TRUE, 'CRC16', '\\r\\n',
  30000, 250
),
(
  'LAB_003',
  TRUE, 'COM1', 115200, 8, 1,
  TRUE, '192.168.1.51', 5000, 10000,
  FALSE, NULL, NULL,
  TRUE, 'CUSTOM', '\\r\\n',
  15000, 1000
),
(
  'LAB_004',
  FALSE, NULL, 9600, 8, 1,
  TRUE, '192.168.1.52', 502, 5000,
  TRUE, 'E:\\Culture\\Logs', '*.txt',
  TRUE, 'CUSTOM', '\\r\\n',
  60000, 100
),
(
  'LAB_005',
  TRUE, 'COM5', 9600, 8, 1,
  FALSE, NULL, 502, 5000,
  TRUE, 'F:\\PCR\\Results', '*.csv',
  TRUE, 'CUSTOM', '\\r\\n',
  30000, 500
);

-- ============================================
-- 3. INSERT SAMPLE RAW DATA
-- ============================================

-- Note: Using current quarter for partition_key
INSERT INTO `raw_data` (
  machine_id,
  message_id,
  protocol,
  raw_payload,
  raw_payload_hash,
  is_valid,
  received_at,
  middleware_timestamp,
  partition_key,
  batch_id
) VALUES
-- LAB_001 data
(
  'LAB_001',
  UUID(),
  'RS232',
  JSON_OBJECT(
    'test_id', 'BL001',
    'result', '23.5',
    'unit', 'g/dL',
    'parameter', 'Hemoglobin',
    'status', 'NORMAL'
  ),
  SHA2(JSON_OBJECT('test_id', 'BL001', 'result', '23.5'), 256),
  TRUE,
  NOW(),
  DATE_SUB(NOW(), INTERVAL 5 MINUTE),
  '2026_Q2',
  'BATCH_LAB001_001'
),
(
  'LAB_001',
  UUID(),
  'FILE',
  JSON_OBJECT(
    'test_id', 'BL002',
    'result', '7.2',
    'unit', 'pH',
    'parameter', 'Blood_pH',
    'status', 'NORMAL'
  ),
  SHA2(JSON_OBJECT('test_id', 'BL002', 'result', '7.2'), 256),
  TRUE,
  NOW(),
  DATE_SUB(NOW(), INTERVAL 3 MINUTE),
  '2026_Q2',
  'BATCH_LAB001_001'
),
-- LAB_002 data
(
  'LAB_002',
  UUID(),
  'LAN',
  JSON_OBJECT(
    'spin_id', 'CENT001',
    'rpm', '3000',
    'duration_min', '10',
    'temperature', '4',
    'status', 'COMPLETED'
  ),
  SHA2(JSON_OBJECT('spin_id', 'CENT001', 'rpm', '3000'), 256),
  TRUE,
  NOW(),
  DATE_SUB(NOW(), INTERVAL 2 MINUTE),
  '2026_Q2',
  'BATCH_LAB002_001'
),
-- LAB_003 data
(
  'LAB_003',
  UUID(),
  'RS232',
  JSON_OBJECT(
    'wavelength', '450',
    'absorbance', '0.523',
    'sample_id', 'SPEC001',
    'unit', 'OD',
    'status', 'VALID'
  ),
  SHA2(JSON_OBJECT('wavelength', '450', 'absorbance', '0.523'), 256),
  TRUE,
  NOW(),
  DATE_SUB(NOW(), INTERVAL 1 MINUTE),
  '2026_Q2',
  'BATCH_LAB003_001'
),
-- LAB_005 data
(
  'LAB_005',
  UUID(),
  'RS232',
  JSON_OBJECT(
    'pcr_id', 'PCR001',
    'ct_value', '25.3',
    'gene', 'GAPDH',
    'cycle', '35',
    'status', 'POSITIVE'
  ),
  SHA2(JSON_OBJECT('pcr_id', 'PCR001', 'ct_value', '25.3'), 256),
  TRUE,
  NOW(),
  DATE_SUB(NOW(), INTERVAL 10 MINUTE),
  '2026_Q2',
  'BATCH_LAB005_001'
);

-- ============================================
-- 4. INSERT SAMPLE ERROR LOGS
-- ============================================

INSERT INTO `error_log` (
  machine_id,
  error_code,
  error_message,
  error_details,
  severity,
  resolved
) VALUES
(
  'LAB_001',
  'COM_ERROR_01',
  'Failed to open COM port - Port already in use',
  JSON_OBJECT(
    'port', 'COM3',
    'error_details', 'Access denied',
    'suggestion', 'Check if another application is using COM3'
  ),
  'ERROR',
  FALSE
),
(
  'LAB_002',
  'NET_TIMEOUT_01',
  'Connection timeout to device at 192.168.1.50',
  JSON_OBJECT(
    'host', '192.168.1.50',
    'port', 502,
    'timeout_ms', 5000
  ),
  'WARNING',
  TRUE
),
(
  'LAB_004',
  'DEVICE_OFFLINE',
  'Device not responding to heartbeat',
  JSON_OBJECT(
    'last_seen', '2026-04-15 10:30:00',
    'expected_heartbeat_interval', '60 seconds'
  ),
  'CRITICAL',
  FALSE
),
(
  'LAB_003',
  'INVALID_DATA',
  'Received data failed checksum validation',
  JSON_OBJECT(
    'expected_checksum', 'ABC123',
    'received_checksum', 'XYZ789',
    'raw_data_sample', 'WAVELENGTH:450,OD:0.523'
  ),
  'WARNING',
  TRUE
);

-- ============================================
-- 5. INSERT SAMPLE SYNC LOGS
-- ============================================

INSERT INTO `sync_log` (
  machine_id,
  batch_id,
  batch_count,
  success_count,
  failed_count,
  duplicate_count,
  duration_ms,
  data_size_bytes,
  status,
  error_message
) VALUES
(
  'LAB_001',
  'BATCH_LAB001_001',
  100,
  98,
  2,
  1,
  1250,
  125000,
  'PARTIAL',
  NULL
),
(
  'LAB_002',
  'BATCH_LAB002_001',
  50,
  50,
  0,
  0,
  800,
  52000,
  'SUCCESS',
  NULL
),
(
  'LAB_003',
  'BATCH_LAB003_001',
  200,
  195,
  5,
  2,
  2100,
  210000,
  'PARTIAL',
  '5 records failed validation'
),
(
  'LAB_005',
  'BATCH_LAB005_001',
  75,
  75,
  0,
  0,
  950,
  78000,
  'SUCCESS',
  NULL
);

-- ============================================
-- 6. INSERT MIDDLEWARE CACHE STATUS
-- ============================================

INSERT INTO `middleware_cache` (
  machine_id,
  cache_size_bytes,
  pending_count,
  last_sync_attempt,
  last_sync_success,
  cache_utilization_percent,
  is_healthy,
  middleware_version,
  middleware_last_seen,
  middleware_status
) VALUES
(
  'LAB_001',
  2500000,
  25,
  NOW(),
  NOW(),
  65.5,
  TRUE,
  '1.0.0',
  NOW(),
  'RUNNING'
),
(
  'LAB_002',
  1200000,
  5,
  NOW(),
  NOW(),
  35.2,
  TRUE,
  '1.0.0',
  NOW(),
  'RUNNING'
),
(
  'LAB_003',
  3800000,
  150,
  DATE_SUB(NOW(), INTERVAL 5 MINUTE),
  DATE_SUB(NOW(), INTERVAL 5 MINUTE),
  85.0,
  FALSE,
  '1.0.0',
  DATE_SUB(NOW(), INTERVAL 2 MINUTE),
  'ERROR'
),
(
  'LAB_004',
  0,
  0,
  NULL,
  NULL,
  0,
  FALSE,
  NULL,
  NULL,
  'STOPPED'
),
(
  'LAB_005',
  1800000,
  8,
  NOW(),
  NOW(),
  42.0,
  TRUE,
  '1.0.0',
  NOW(),
  'RUNNING'
);

-- ============================================
-- 7. INSERT MACHINE GROUPS
-- ============================================

INSERT INTO `machine_groups` (group_name, description, color) VALUES
('Hematology', 'Blood analysis equipment', '#FF6B6B'),
('Biochemistry', 'Chemical analysis equipment', '#4ECDC4'),
('Genetics', 'Genetic testing equipment', '#45B7D1'),
('Research', 'Research lab equipment', '#FFA07A'),
('Critical', 'Critical priority equipment', '#FF0000');

-- ============================================
-- 8. INSERT MACHINE GROUP MAPPINGS
-- ============================================

INSERT INTO `machine_group_mapping` (machine_id, group_id) VALUES
('LAB_001', 1),  -- LAB_001 -> Hematology
('LAB_002', 2),  -- LAB_002 -> Biochemistry
('LAB_003', 4),  -- LAB_003 -> Research
('LAB_004', 2),  -- LAB_004 -> Biochemistry
('LAB_005', 3);  -- LAB_005 -> Genetics

-- ============================================
-- 9. INSERT TRANSFORMATION RULES (for Phase 2)
-- ============================================

INSERT INTO `transformation_rules` (
  machine_id,
  rule_name,
  description,
  rule_type,
  source_pattern,
  target_fields,
  validation_rules,
  enabled
) VALUES
(
  'LAB_001',
  'Blood Test Parser',
  'Extract hemoglobin, pH, and temperature from raw data',
  'REGEX_EXTRACT',
  '(?P<hemoglobin>\\d+\\.\\d+),pH:(?P<pH>\\d+\\.\\d+),Temp:(?P<temperature>\\d+)',
  JSON_OBJECT(
    'hemoglobin', 'DECIMAL(5,2)',
    'pH', 'DECIMAL(3,2)',
    'temperature', 'INT'
  ),
  JSON_OBJECT(
    'hemoglobin', JSON_OBJECT('min', 7, 'max', 20, 'unit', 'g/dL'),
    'pH', JSON_OBJECT('min', 6.8, 'max', 7.8, 'unit', 'pH')
  ),
  TRUE
),
(
  'LAB_003',
  'Spectrophotometry Parser',
  'Extract wavelength and absorbance values',
  'JSON_MAP',
  NULL,
  JSON_OBJECT(
    'wavelength', 'wavelength',
    'absorbance', 'absorbance',
    'sample_id', 'sample_id'
  ),
  JSON_OBJECT(
    'wavelength', JSON_OBJECT('min', 200, 'max', 900, 'unit', 'nm'),
    'absorbance', JSON_OBJECT('min', 0, 'max', 4, 'unit', 'OD')
  ),
  TRUE
);

-- ============================================
-- 10. INSERT ALERT RULES
-- ============================================

INSERT INTO `alert_rules` (
  rule_name,
  description,
  condition_type,
  threshold_value,
  time_window_minutes,
  alert_severity,
  enabled,
  alert_channels
) VALUES
(
  'High Error Rate',
  'Alert when error rate exceeds 5% in 1 hour',
  'ERROR_THRESHOLD',
  5,
  60,
  'ERROR',
  TRUE,
  JSON_ARRAY('email', 'slack')
),
(
  'No Activity Alert',
  'Alert if no data received for 30 minutes',
  'NO_ACTIVITY',
  30,
  30,
  'WARNING',
  TRUE,
  JSON_ARRAY('email')
),
(
  'Cache Full Alert',
  'Alert when cache usage exceeds 90%',
  'CACHE_FULL',
  90,
  60,
  'CRITICAL',
  TRUE,
  JSON_ARRAY('email', 'sms', 'slack')
),
(
  'Invalid Data Rate',
  'Alert when invalid data rate exceeds 2%',
  'INVALID_DATA_RATE',
  2,
  60,
  'WARNING',
  TRUE,
  JSON_ARRAY('email')
),
(
  'Slow Response',
  'Alert when response time exceeds 10 seconds',
  'RESPONSE_TIME',
  10000,
  60,
  'WARNING',
  TRUE,
  JSON_ARRAY('email')
);

-- ============================================
-- 11. INSERT RETENTION POLICIES (already done in migrations)
-- ============================================

-- ============================================
-- 12. INSERT SYSTEM CONFIG (already done in migrations)
-- ============================================

-- ============================================
-- 13. VERIFY SEED DATA
-- ============================================

SELECT '✅ SEED DATA SUMMARY' AS status;

SELECT 
  'Machines' AS entity,
  COUNT(*) AS count
FROM machines
UNION ALL
SELECT 'Raw Data', COUNT(*) FROM raw_data
UNION ALL
SELECT 'Error Logs', COUNT(*) FROM error_log
UNION ALL
SELECT 'Sync Logs', COUNT(*) FROM sync_log
UNION ALL
SELECT 'Machine Groups', COUNT(*) FROM machine_groups
UNION ALL
SELECT 'Alert Rules', COUNT(*) FROM alert_rules
UNION ALL
SELECT 'Transformation Rules', COUNT(*) FROM transformation_rules;

-- Show sample data from each table
SELECT '\\n--- MACHINES ---' AS info;
SELECT machine_id, name, device_type, status FROM machines;

SELECT '\\n--- ACTIVE MACHINES SUMMARY ---' AS info;
SELECT * FROM v_active_machines_summary;

SELECT '\\n--- RAW DATA (Last 5) ---' AS info;
SELECT machine_id, protocol, is_valid, received_at FROM raw_data ORDER BY received_at DESC LIMIT 5;

SELECT '\\n--- ERROR LOGS ---' AS info;
SELECT machine_id, error_code, severity, resolved, error_timestamp FROM error_log;

-- ============================================
-- END OF SEED DATA SCRIPT
-- ============================================
