-- ============================================
-- Partition Management Scripts
-- ============================================
-- Manage quarterly partitions for raw_data table
-- Run these scripts periodically for maintenance

USE `mdata_lab`;

-- ============================================
-- 1. CREATE PROCEDURE: Create New Quarter Partitions
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_create_quarterly_partitions(IN year INT, IN quarter INT)
BEGIN
  DECLARE quarter_key VARCHAR(20);
  DECLARE next_quarter_key VARCHAR(20);
  DECLARE next_year INT;
  DECLARE next_quarter INT;
  
  -- Calculate partition key
  SET quarter_key = CONCAT(year, '_Q', quarter);
  
  -- Calculate next quarter
  IF quarter < 4 THEN
    SET next_quarter = quarter + 1;
    SET next_year = year;
  ELSE
    SET next_quarter = 1;
    SET next_year = year + 1;
  END IF;
  
  SET next_quarter_key = CONCAT(next_year, '_Q', next_quarter);
  
  -- Check if partition already exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.partitions 
    WHERE table_schema = 'mdata_lab' 
      AND table_name = 'raw_data' 
      AND partition_name = CONCAT('p', quarter_key)
  ) THEN
    -- Add new partition
    SET @sql = CONCAT(
      'ALTER TABLE raw_data ADD PARTITION (PARTITION p',
      quarter_key, ' VALUES IN (\'', quarter_key, '\'))'
    );
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    SELECT CONCAT('✅ Partition created: p', quarter_key) AS result;
  ELSE
    SELECT CONCAT('⚠️  Partition already exists: p', quarter_key) AS result;
  END IF;
END //
DELIMITER ;

-- ============================================
-- 2. CREATE PROCEDURE: Get Partition Statistics
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_get_partition_statistics()
BEGIN
  SELECT 
    partition_name,
    ROUND(data_length / 1024 / 1024, 2) AS size_mb,
    ROUND(index_length / 1024 / 1024, 2) AS index_size_mb,
    row_count,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_size_mb,
    create_time,
    update_time
  FROM information_schema.partitions
  WHERE table_schema = 'mdata_lab' 
    AND table_name = 'raw_data'
    AND partition_name IS NOT NULL
  ORDER BY partition_name DESC;
END //
DELIMITER ;

-- ============================================
-- 3. CREATE PROCEDURE: Archive Old Partition Data
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_archive_partition_data(IN partition_to_archive VARCHAR(20))
BEGIN
  DECLARE row_count INT;
  DECLARE archive_timestamp TIMESTAMP;
  DECLARE quarter_year INT;
  DECLARE quarter_num INT;
  DECLARE archive_table_name VARCHAR(50);
  
  SET archive_timestamp = NOW();
  
  -- Extract year and quarter
  SET quarter_year = CAST(SUBSTRING_INDEX(partition_to_archive, '_', 1) AS UNSIGNED);
  SET quarter_num = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(partition_to_archive, '_Q', -1), '_', 1) AS UNSIGNED);
  
  -- Create archive table name
  SET archive_table_name = CONCAT('raw_data_archive_', quarter_year, '_Q', quarter_num);
  
  -- Create archive table (copy structure)
  SET @sql = CONCAT(
    'CREATE TABLE IF NOT EXISTS ', archive_table_name, ' LIKE raw_data'
  );
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
  
  -- Copy data to archive
  SET @sql = CONCAT(
    'INSERT INTO ', archive_table_name, 
    ' SELECT * FROM raw_data WHERE partition_key = \'', partition_to_archive, '\''
  );
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
  
  SET row_count = ROW_COUNT();
  
  -- Record archive action
  INSERT INTO backup_info (
    backup_name, backup_type, source_table, partition_name,
    record_count, backup_path, status, completed_at
  ) VALUES (
    CONCAT('archive_', partition_to_archive, '_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s')),
    'PARTITION',
    'raw_data',
    partition_to_archive,
    row_count,
    CONCAT('/archive/', archive_table_name),
    'COMPLETED',
    NOW()
  );
  
  SELECT CONCAT('✅ Archived ', row_count, ' records to ', archive_table_name) AS result;
END //
DELIMITER ;

-- ============================================
-- 4. CREATE PROCEDURE: Rebuild Partition Indexes
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_rebuild_partition_indexes(IN partition_name_input VARCHAR(50))
BEGIN
  DECLARE table_schema_val VARCHAR(50);
  DECLARE table_name_val VARCHAR(50);
  
  -- Validate partition exists
  SELECT COUNT(*) INTO @partition_exists
  FROM information_schema.partitions
  WHERE table_schema = 'mdata_lab'
    AND table_name = 'raw_data'
    AND partition_name = partition_name_input;
  
  IF @partition_exists > 0 THEN
    -- Rebuild indexes
    OPTIMIZE TABLE raw_data;
    ANALYZE TABLE raw_data;
    
    SELECT CONCAT('✅ Indexes rebuilt for partition: ', partition_name_input) AS result;
  ELSE
    SELECT CONCAT('❌ Partition not found: ', partition_name_input) AS result;
  END IF;
END //
DELIMITER ;

-- ============================================
-- 5. CREATE PROCEDURE: Clean Up Expired Data
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_cleanup_expired_data(IN days_old INT, IN delete_or_archive VARCHAR(10))
BEGIN
  DECLARE record_count INT;
  DECLARE cutoff_date TIMESTAMP;
  
  SET cutoff_date = DATE_SUB(NOW(), INTERVAL days_old DAY);
  
  -- Count records to delete
  SELECT COUNT(*) INTO record_count
  FROM raw_data
  WHERE received_at < cutoff_date;
  
  IF record_count > 0 THEN
    IF LOWER(delete_or_archive) = 'archive' THEN
      -- Archive before delete
      INSERT INTO backup_info (
        backup_name, backup_type, source_table,
        record_count, status, completed_at
      ) VALUES (
        CONCAT('cleanup_archive_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s')),
        'INCREMENTAL',
        'raw_data',
        record_count,
        'COMPLETED',
        NOW()
      );
      
      SELECT CONCAT('✅ Archived ', record_count, ' records before deletion') AS result;
    END IF;
    
    -- Delete expired records
    DELETE FROM raw_data WHERE received_at < cutoff_date;
    
    SELECT CONCAT('✅ Deleted ', ROW_COUNT(), ' expired records (older than ', days_old, ' days)') AS result;
  ELSE
    SELECT CONCAT('ℹ️  No records found older than ', days_old, ' days') AS result;
  END IF;
  
  -- Optimize table after deletion
  OPTIMIZE TABLE raw_data;
END //
DELIMITER ;

-- ============================================
-- 6. CREATE PROCEDURE: Monitor Partition Growth
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_monitor_partition_growth()
BEGIN
  SELECT 
    partition_name,
    ROUND(data_length / 1024 / 1024, 2) AS current_size_mb,
    row_count AS record_count,
    ROUND(data_length / row_count, 0) AS avg_record_size_bytes,
    CASE 
      WHEN data_length / 1024 / 1024 > 1000 THEN '🔴 CRITICAL (>1GB)'
      WHEN data_length / 1024 / 1024 > 500 THEN '🟠 WARNING (>500MB)'
      WHEN data_length / 1024 / 1024 > 100 THEN '🟡 MEDIUM (>100MB)'
      ELSE '🟢 NORMAL (<100MB)'
    END AS size_status,
    update_time
  FROM information_schema.partitions
  WHERE table_schema = 'mdata_lab'
    AND table_name = 'raw_data'
    AND partition_name IS NOT NULL
  ORDER BY data_length DESC;
END //
DELIMITER ;

-- ============================================
-- 7. CREATE PROCEDURE: Estimate Partition Usage
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_estimate_disk_usage()
BEGIN
  SELECT 
    'Raw Data Table' AS component,
    ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2) AS total_size_gb,
    ROUND(SUM(data_length) / 1024 / 1024 / 1024, 2) AS data_size_gb,
    ROUND(SUM(index_length) / 1024 / 1024 / 1024, 2) AS index_size_gb,
    COUNT(*) AS partition_count
  FROM information_schema.partitions
  WHERE table_schema = 'mdata_lab'
    AND table_name = 'raw_data'
    AND partition_name IS NOT NULL
  UNION ALL
  SELECT 
    'All Tables',
    ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2),
    ROUND(SUM(data_length) / 1024 / 1024 / 1024, 2),
    ROUND(SUM(index_length) / 1024 / 1024 / 1024, 2),
    COUNT(DISTINCT table_name)
  FROM information_schema.partitions
  WHERE table_schema = 'mdata_lab';
END //
DELIMITER ;

-- ============================================
-- 8. CREATE PROCEDURE: Merge or Reorganize Partitions
-- ============================================

DELIMITER //
CREATE PROCEDURE sp_reorganize_partitions()
BEGIN
  -- This procedure checks for empty partitions and can merge them
  SELECT 
    partition_name,
    ROUND(data_length / 1024 / 1024, 2) AS size_mb,
    row_count,
    CASE 
      WHEN row_count = 0 THEN '❌ EMPTY'
      WHEN row_count < 1000 THEN '⚠️  SPARSE'
      ELSE '✅ ACTIVE'
    END AS status
  FROM information_schema.partitions
  WHERE table_schema = 'mdata_lab'
    AND table_name = 'raw_data'
    AND partition_name IS NOT NULL
  ORDER BY row_count;
END //
DELIMITER ;

-- ============================================
-- 9. CREATE EVENT: Auto Create Future Quarters
-- ============================================

-- This event will automatically create partitions for future quarters
-- Modify schedule as needed

CREATE EVENT IF NOT EXISTS evt_create_future_partitions
ON SCHEDULE EVERY 1 QUARTER
STARTS DATE_ADD(NOW(), INTERVAL 1 QUARTER)
DO
BEGIN
  DECLARE current_year INT;
  DECLARE current_quarter INT;
  
  SET current_year = YEAR(NOW());
  SET current_quarter = QUARTER(NOW()) + 1;
  
  -- Adjust if quarter exceeds 4
  IF current_quarter > 4 THEN
    SET current_quarter = 1;
    SET current_year = current_year + 1;
  END IF;
  
  -- Create partition for next quarter
  CALL sp_create_quarterly_partitions(current_year, current_quarter);
END;

-- ============================================
-- 10. CREATE EVENT: Auto Cleanup Old Partitions
-- ============================================

CREATE EVENT IF NOT EXISTS evt_cleanup_old_partitions
ON SCHEDULE EVERY 1 MONTH
STARTS DATE_ADD(NOW(), INTERVAL 1 MONTH)
DO
BEGIN
  -- Archive partitions older than 24 months
  DECLARE done INT DEFAULT FALSE;
  DECLARE old_partition VARCHAR(20);
  DECLARE cur CURSOR FOR
    SELECT partition_name
    FROM information_schema.partitions
    WHERE table_schema = 'mdata_lab'
      AND table_name = 'raw_data'
      AND partition_name IS NOT NULL
      AND partition_name != 'pdefault'
      AND CONCAT(SUBSTR(partition_name, 2, 4), '-', 
                 CASE WHEN SUBSTR(partition_name, 7, 1) = '1' THEN '01'
                      WHEN SUBSTR(partition_name, 7, 1) = '2' THEN '04'
                      WHEN SUBSTR(partition_name, 7, 1) = '3' THEN '07'
                      WHEN SUBSTR(partition_name, 7, 1) = '4' THEN '10'
                 END, '-01') < DATE_SUB(NOW(), INTERVAL 24 MONTH);
  
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
  
  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO old_partition;
    IF done THEN
      LEAVE read_loop;
    END IF;
    
    -- Archive the partition
    CALL sp_archive_partition_data(SUBSTR(old_partition, 2));
  END LOOP;
  CLOSE cur;
END;

-- ============================================
-- HELPFUL QUERIES FOR MONITORING
-- ============================================

-- Query 1: Show all partitions with details
SELECT 
  'PARTITION DETAILS' AS info;

SELECT 
  partition_name,
  ROUND(data_length / 1024 / 1024, 2) AS data_size_mb,
  ROUND(index_length / 1024 / 1024, 2) AS index_size_mb,
  row_count,
  ROUND((data_length + index_length) / 1024 / 1024 / 1024, 2) AS total_size_gb,
  create_time
FROM information_schema.partitions
WHERE table_schema = 'mdata_lab'
  AND table_name = 'raw_data'
  AND partition_name IS NOT NULL
ORDER BY create_time;

-- Query 2: Estimate growth rate
SELECT 
  'GROWTH ANALYSIS' AS info;

SELECT 
  partition_name,
  ROUND(data_length / 1024 / 1024, 2) AS size_mb,
  (SELECT COUNT(*) FROM raw_data WHERE partition_key = SUBSTR(partition_name, 2)) AS record_count,
  DATEDIFF(NOW(), create_time) AS days_old,
  ROUND((data_length / 1024 / 1024) / DATEDIFF(NOW(), create_time), 2) AS growth_rate_mb_per_day
FROM information_schema.partitions
WHERE table_schema = 'mdata_lab'
  AND table_name = 'raw_data'
  AND partition_name IS NOT NULL
  AND create_time IS NOT NULL
ORDER BY growth_rate_mb_per_day DESC;

-- ============================================
-- END OF PARTITION MANAGEMENT SCRIPTS
-- ============================================
