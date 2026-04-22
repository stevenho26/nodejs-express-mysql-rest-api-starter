-- ============================================
-- Monitoring & Maintenance Scripts
-- ============================================
-- Database health checks, monitoring queries, and maintenance tasks

USE `mdata_lab`;

-- ============================================
-- 1. CREATE PROCEDURE: Database Health Check
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_database_health_check()
BEGIN
  SELECT '=== DATABASE HEALTH CHECK ===' AS status;
  
  -- 1. Check database size
  SELECT 
    'Database Size' AS check_type,
    ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2) AS size_gb,
    CASE 
      WHEN SUM(data_length + index_length) / 1024 / 1024 / 1024 > 100 THEN '🔴 CRITICAL'
      WHEN SUM(data_length + index_length) / 1024 / 1024 / 1024 > 50 THEN '🟠 WARNING'
      ELSE '🟢 NORMAL'
    END AS status
  FROM information_schema.tables
  WHERE table_schema = 'mdata_lab';
  
  -- 2. Check table integrity
  SELECT 
    'Table Integrity' AS check_type,
    COUNT(*) AS total_tables,
    SUM(CASE WHEN engine = 'InnoDB' THEN 1 ELSE 0 END) AS innodb_tables,
    SUM(CASE WHEN auto_increment IS NOT NULL THEN 1 ELSE 0 END) AS tables_with_ai
  FROM information_schema.tables
  WHERE table_schema = 'mdata_lab';
  
  -- 3. Check for fragmentation
  SELECT 
    'Table Fragmentation' AS check_type,
    table_name,
    ROUND((data_free / (data_length + index_length)) * 100, 2) AS fragmentation_percent,
    CASE 
      WHEN (data_free / (data_length + index_length)) * 100 > 10 THEN '⚠️  OPTIMIZE NEEDED'
      ELSE '✅ OK'
    END AS recommendation
  FROM information_schema.tables
  WHERE table_schema = 'mdata_lab'
    AND (data_free / (data_length + index_length)) * 100 > 5
  ORDER BY fragmentation_percent DESC;
  
  -- 4. Check partition status
  SELECT 
    'Partition Status' AS check_type,
    COUNT(*) AS total_partitions,
    SUM(CASE WHEN row_count = 0 THEN 1 ELSE 0 END) AS empty_partitions,
    ROUND(AVG(data_length) / 1024 / 1024, 2) AS avg_partition_size_mb
  FROM information_schema.partitions
  WHERE table_schema = 'mdata_lab'
    AND table_name = 'raw_data'
    AND partition_name IS NOT NULL;
  
  -- 5. Check index usage
  SELECT 
    'Index Status' AS check_type,
    SUM(CASE WHEN seq_in_index = 1 THEN 1 ELSE 0 END) AS total_indexes,
    COUNT(*) AS total_index_columns
  FROM information_schema.statistics
  WHERE table_schema = 'mdata_lab'
    AND index_type NOT IN ('FULLTEXT', 'SPATIAL');
  
END //
DELIMITER ;

-- ============================================
-- 2. CREATE PROCEDURE: Monitor Real-Time Data Flow
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_monitor_realtime_dataflow()
BEGIN
  SELECT '=== REAL-TIME DATA FLOW MONITORING ===' AS status;
  
  -- 1. Records received in last hour
  SELECT 
    'Last Hour Activity' AS metric,
    COUNT(*) AS records_received,
    COUNT(DISTINCT machine_id) AS active_machines,
    SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) AS valid_records,
    SUM(CASE WHEN is_valid = FALSE THEN 1 ELSE 0 END) AS invalid_records,
    ROUND(100.0 * SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS valid_percentage
  FROM raw_data
  WHERE received_at > DATE_SUB(NOW(), INTERVAL 1 HOUR);
  
  -- 2. Machine-wise activity
  SELECT 
    'Machine Activity' AS metric,
    machine_id,
    COUNT(*) AS records_1h,
    MAX(received_at) AS last_record,
    TIMEDIFF(NOW(), MAX(received_at)) AS time_since_last,
    SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) AS valid_count
  FROM raw_data
  WHERE received_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)
  GROUP BY machine_id
  ORDER BY COUNT(*) DESC;
  
  -- 3. Error count by severity (last 24h)
  SELECT 
    'Recent Errors' AS metric,
    severity,
    COUNT(*) AS error_count,
    SUM(CASE WHEN resolved = FALSE THEN 1 ELSE 0 END) AS unresolved
  FROM error_log
  WHERE error_timestamp > DATE_SUB(NOW(), INTERVAL 24 HOUR)
  GROUP BY severity
  ORDER BY FIELD(severity, 'CRITICAL', 'ERROR', 'WARNING', 'INFO');
  
END //
DELIMITER ;

-- ============================================
-- 3. CREATE PROCEDURE: Performance Analysis
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_performance_analysis()
BEGIN
  SELECT '=== PERFORMANCE ANALYSIS ===' AS status;
  
  -- 1. Sync performance
  SELECT 
    'Sync Performance' AS metric,
    COUNT(*) AS total_syncs,
    ROUND(AVG(duration_ms), 0) AS avg_duration_ms,
    MIN(duration_ms) AS min_duration_ms,
    MAX(duration_ms) AS max_duration_ms,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful_syncs,
    ROUND(100.0 * SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate
  FROM sync_log
  WHERE sync_timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY);
  
  -- 2. Data throughput
  SELECT 
    'Data Throughput' AS metric,
    ROUND(AVG(data_size_bytes) / 1024 / 1024, 2) AS avg_batch_size_mb,
    SUM(batch_count) AS total_records_synced,
    ROUND(SUM(data_size_bytes) / 1024 / 1024 / 1024, 2) AS total_data_gb,
    ROUND(SUM(data_size_bytes) / 1024 / 1024 / DATEDIFF(NOW(), DATE_SUB(NOW(), INTERVAL 7 DAY)), 2) AS avg_mb_per_day
  FROM sync_log
  WHERE sync_timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY);
  
  -- 3. Processing efficiency
  SELECT 
    'Processing Efficiency' AS metric,
    COUNT(*) AS total_batches,
    ROUND(AVG(success_count / batch_count * 100), 2) AS avg_success_rate,
    SUM(duplicate_count) AS total_duplicates_detected,
    SUM(failed_count) AS total_failed_records
  FROM sync_log
  WHERE sync_timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY);
  
  -- 4. Query performance (longest queries)
  SELECT 
    'Top Time-Consuming Operations' AS metric;
    
  -- This shows tables with most queries (estimated from row operations)
  SELECT 
    table_name,
    SUM(rows_read) AS rows_read,
    SUM(rows_inserted) AS rows_inserted,
    SUM(rows_updated) AS rows_updated,
    SUM(rows_deleted) AS rows_deleted
  FROM performance_schema.table_io_waits_summary_by_table
  WHERE object_schema = 'mdata_lab'
  ORDER BY (SUM(rows_read) + SUM(rows_inserted) + SUM(rows_updated) + SUM(rows_deleted)) DESC;
  
END //
DELIMITER ;

-- ============================================
-- 4. CREATE PROCEDURE: Machine Status Overview
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_machine_status_overview()
BEGIN
  SELECT '=== MACHINE STATUS OVERVIEW ===' AS status;
  
  SELECT 
    m.machine_id,
    m.name,
    m.status,
    mc.middleware_status,
    m.last_heartbeat,
    TIMEDIFF(NOW(), m.last_heartbeat) AS time_since_heartbeat,
    mc.pending_count,
    ROUND(mc.cache_size_bytes / 1024 / 1024, 2) AS cache_size_mb,
    mc.cache_utilization_percent,
    m.total_records_sent,
    m.total_errors,
    (SELECT COUNT(*) FROM raw_data WHERE machine_id = m.machine_id AND received_at > DATE_SUB(NOW(), INTERVAL 1 DAY)) AS records_24h,
    (SELECT COUNT(*) FROM error_log WHERE machine_id = m.machine_id AND resolved = FALSE) AS unresolved_errors,
    CASE 
      WHEN mc.middleware_status = 'RUNNING' AND m.last_heartbeat > DATE_SUB(NOW(), INTERVAL 5 MINUTE) THEN '🟢 HEALTHY'
      WHEN mc.middleware_status = 'ERROR' OR m.last_heartbeat < DATE_SUB(NOW(), INTERVAL 30 MINUTE) THEN '🔴 CRITICAL'
      WHEN m.last_heartbeat < DATE_SUB(NOW(), INTERVAL 10 MINUTE) THEN '🟠 WARNING'
      ELSE '🟡 UNKNOWN'
    END AS health_status
  FROM machines m
  LEFT JOIN middleware_cache mc ON m.machine_id = mc.machine_id
  ORDER BY CASE 
    WHEN mc.middleware_status = 'ERROR' THEN 1
    WHEN m.last_heartbeat < DATE_SUB(NOW(), INTERVAL 30 MINUTE) THEN 2
    WHEN m.last_heartbeat < DATE_SUB(NOW(), INTERVAL 10 MINUTE) THEN 3
    ELSE 4
  END;
  
END //
DELIMITER ;

-- ============================================
-- 5. CREATE PROCEDURE: Data Quality Report
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_data_quality_report(IN days_back INT)
BEGIN
  DECLARE start_date TIMESTAMP;
  SET start_date = DATE_SUB(NOW(), INTERVAL days_back DAY);
  
  SELECT CONCAT('=== DATA QUALITY REPORT (Last ', days_back, ' Days) ===') AS status;
  
  -- 1. Overall quality metrics
  SELECT 
    'Overall Quality' AS metric,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) AS valid_records,
    SUM(CASE WHEN is_valid = FALSE THEN 1 ELSE 0 END) AS invalid_records,
    ROUND(100.0 * SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS valid_percentage,
    COUNT(DISTINCT machine_id) AS machines_reporting,
    COUNT(DISTINCT protocol) AS protocols_used
  FROM raw_data
  WHERE received_at >= start_date;
  
  -- 2. Per-machine quality
  SELECT 
    'Per-Machine Quality' AS metric,
    machine_id,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) AS valid_records,
    ROUND(100.0 * SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS valid_percentage,
    COUNT(DISTINCT protocol) AS protocols_used
  FROM raw_data
  WHERE received_at >= start_date
  GROUP BY machine_id
  ORDER BY ROUND(100.0 * SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) ASC;
  
  -- 3. Error distribution
  SELECT 
    'Error Distribution' AS metric,
    validation_error,
    COUNT(*) AS error_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM raw_data WHERE received_at >= start_date AND is_valid = FALSE), 2) AS percentage
  FROM raw_data
  WHERE received_at >= start_date
    AND is_valid = FALSE
    AND validation_error IS NOT NULL
  GROUP BY validation_error
  ORDER BY error_count DESC
  LIMIT 10;
  
  -- 4. Deduplication effectiveness
  SELECT 
    'Deduplication' AS metric,
    COUNT(*) AS total_unique_messages,
    SUM(duplicate_count) AS total_duplicates_detected,
    ROUND(100.0 * SUM(duplicate_count) / (COUNT(*) + SUM(duplicate_count)), 2) AS duplicate_rate
  FROM message_dedup
  WHERE first_received_at >= start_date;
  
END //
DELIMITER ;

-- ============================================
-- 6. CREATE PROCEDURE: Generate Maintenance Report
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_generate_maintenance_report()
BEGIN
  SELECT '=== SYSTEM MAINTENANCE REPORT ===' AS status;
  
  -- 1. Recommended maintenance tasks
  SELECT 
    'Maintenance Tasks' AS recommendation,
    'TABLE OPTIMIZATION' AS task_type,
    GROUP_CONCAT(table_name) AS affected_tables,
    'Run OPTIMIZE TABLE to reduce fragmentation' AS description
  FROM information_schema.tables
  WHERE table_schema = 'mdata_lab'
    AND (data_free / (data_length + index_length)) * 100 > 10;
  
  -- 2. Disk space analysis
  SELECT 
    'Disk Space' AS metric,
    ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2) AS total_size_gb,
    ROUND(SUM(data_free) / 1024 / 1024 / 1024, 2) AS free_space_gb,
    ROUND(100.0 * SUM(data_free) / (data_length + index_length), 2) AS free_percent
  FROM information_schema.tables
  WHERE table_schema = 'mdata_lab';
  
  -- 3. Backup status
  SELECT 
    'Recent Backups' AS metric,
    backup_name,
    backup_type,
    backup_size_mb,
    record_count,
    status,
    completed_at
  FROM backup_info
  WHERE backup_type IN ('FULL', 'INCREMENTAL')
  ORDER BY completed_at DESC
  LIMIT 10;
  
  -- 4. Events and triggers status
  SELECT 
    'Scheduled Events' AS metric,
    event_name,
    status,
    CONCAT('Every ', interval_value, ' ', interval_field) AS schedule,
    last_executed,
    next_scheduled
  FROM information_schema.events
  WHERE event_schema = 'mdata_lab';
  
END //
DELIMITER ;

-- ============================================
-- 7. CREATE PROCEDURE: Alert Summary
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_alert_summary()
BEGIN
  SELECT '=== ALERT SUMMARY ===' AS status;
  
  -- 1. Active alert rules
  SELECT 
    'Alert Rules' AS metric,
    COUNT(*) AS total_rules,
    SUM(CASE WHEN enabled = TRUE THEN 1 ELSE 0 END) AS active_rules,
    SUM(CASE WHEN enabled = FALSE THEN 1 ELSE 0 END) AS disabled_rules
  FROM alert_rules;
  
  -- 2. Recent error log
  SELECT 
    'Recent Critical Errors' AS metric,
    machine_id,
    error_code,
    error_message,
    severity,
    error_timestamp,
    resolved
  FROM error_log
  WHERE error_timestamp > DATE_SUB(NOW(), INTERVAL 24 HOUR)
    AND severity IN ('CRITICAL', 'ERROR')
  ORDER BY error_timestamp DESC;
  
  -- 3. Machines with ongoing issues
  SELECT 
    'Problem Machines' AS metric,
    machine_id,
    COUNT(*) AS error_count,
    MIN(error_timestamp) AS first_error,
    MAX(error_timestamp) AS last_error,
    SUM(CASE WHEN resolved = FALSE THEN 1 ELSE 0 END) AS unresolved_count
  FROM error_log
  WHERE error_timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
    AND resolved = FALSE
  GROUP BY machine_id
  ORDER BY unresolved_count DESC;
  
END //
DELIMITER ;

-- ============================================
-- 8. USEFUL MONITORING QUERIES
-- ============================================

-- Query 1: Current system load
SELECT 
  'System Load' AS metric,
  (SELECT COUNT(*) FROM raw_data WHERE received_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)) AS records_per_hour,
  (SELECT COUNT(*) FROM raw_data WHERE received_at > DATE_SUB(NOW(), INTERVAL 1 DAY)) AS records_per_day,
  (SELECT COUNT(*) FROM error_log WHERE error_timestamp > DATE_SUB(NOW(), INTERVAL 1 DAY) AND resolved = FALSE) AS unresolved_errors_24h,
  ROUND((SELECT SUM(data_length + index_length) FROM information_schema.tables WHERE table_schema = 'mdata_lab') / 1024 / 1024 / 1024, 2) AS total_db_size_gb;

-- Query 2: Cache statistics
SELECT 
  machine_id,
  pending_count AS pending_records,
  ROUND(cache_size_bytes / 1024 / 1024, 2) AS cache_size_mb,
  cache_utilization_percent,
  middleware_status,
  last_sync_success
FROM middleware_cache
WHERE is_healthy = FALSE OR cache_utilization_percent > 80;

-- Query 3: Sync success rate trend (last 7 days)
SELECT 
  DATE(sync_timestamp) AS date,
  COUNT(*) AS total_syncs,
  SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful,
  ROUND(100.0 * SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate,
  AVG(duration_ms) AS avg_duration_ms
FROM sync_log
WHERE sync_timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(sync_timestamp)
ORDER BY date;

-- Query 4: Slowest machines (by average processing time)
SELECT 
  sl.machine_id,
  COUNT(*) AS sync_count,
  ROUND(AVG(sl.duration_ms), 0) AS avg_duration_ms,
  ROUND(AVG(sl.data_size_bytes) / 1024 / 1024, 2) AS avg_batch_size_mb,
  ROUND(AVG(sl.data_size_bytes) / sl.duration_ms, 2) AS throughput_mb_per_second
FROM sync_log sl
WHERE sl.sync_timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY sl.machine_id
ORDER BY avg_duration_ms DESC;

-- ============================================
-- END OF MONITORING & MAINTENANCE SCRIPTS
-- ============================================
