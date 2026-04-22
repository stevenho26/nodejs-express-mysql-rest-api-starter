# 📊 MData Lab Database - SQL Scripts Guide

## 📁 Database Scripts Overview

Hệ thống quản lý dữ liệu Lab được chia thành 5 file SQL chính để dễ quản lý và bảo trì:

```
database/
├── 01_create_mdata_schema.sql    ← Main schema creation
├── 02_migrations.sql              ← Schema enhancements
├── 03_seed_data.sql               ← Sample data for testing
├── 04_partition_management.sql    ← Partition & storage optimization
└── 05_monitoring_maintenance.sql  ← Health checks & monitoring
```

---

## 🚀 Execution Order

### **Step 1: Create Main Schema** ⭐ REQUIRED
```bash
mysql -h localhost -u root mdata_lab < database/01_create_mdata_schema.sql
```

**This creates:**
- ✅ 8 core tables (machines, raw_data, error_log, sync_log, etc.)
- ✅ Partitioned raw_data table (by quarter)
- ✅ 3 pre-built views
- ✅ Triggers for automatic updates
- ✅ Stored procedures for maintenance
- ✅ Events for scheduled tasks

**Expected output:**
```
Tables created: 8+
Partitions created: 11
Stored procedures: 3
Views: 3
Events: 2
```

---

### **Step 2: Apply Migrations** (Optional but recommended)
```bash
mysql -h localhost -u root mdata_lab < database/02_migrations.sql
```

**This adds:**
- ✅ Machine status history tracking
- ✅ Performance metrics table
- ✅ Alert rules system
- ✅ Audit logging
- ✅ API request tracking
- ✅ Data retention policies
- ✅ Machine grouping
- ✅ Transformation rules (for Phase 2)
- ✅ Backup tracking
- ✅ System configuration table

**Benefits:**
- Better monitoring capabilities
- Historical data analysis
- Compliance & audit trail
- Flexible alerting system

---

### **Step 3: Load Seed Data** (For testing/demo)
```bash
mysql -h localhost -u root mdata_lab < database/03_seed_data.sql
```

**This populates:**
- ✅ 5 sample machines (LAB_001 to LAB_005)
- ✅ Protocol configurations for each machine
- ✅ 50+ sample raw data records
- ✅ Sample error logs
- ✅ Sample sync logs
- ✅ Machine groups and categorization
- ✅ Alert rules
- ✅ Transformation rules (Phase 2 preview)

**Use cases:**
- Testing API endpoints
- Verifying data flow
- Performance testing
- Development environment

**Remove before production:**
```sql
DELETE FROM raw_data;
DELETE FROM machines;
DELETE FROM error_log;
DELETE FROM sync_log;
TRUNCATE TABLE message_dedup;
```

---

### **Step 4: Setup Partition Management** (Recommended)
```bash
mysql -h localhost -u root mdata_lab < database/04_partition_management.sql
```

**This creates:**
- ✅ Procedures for partition management
- ✅ Auto-rotation of quarterly partitions
- ✅ Archive & cleanup automation
- ✅ Scheduled events for maintenance
- ✅ Growth monitoring queries

**Key procedures:**
```sql
CALL sp_create_quarterly_partitions(2026, 2);  -- Create Q2 2026
CALL sp_get_partition_statistics();             -- View partition sizes
CALL sp_monitor_partition_growth();             -- Check growth trends
CALL sp_cleanup_expired_data(730, 'archive');   -- Archive data older than 2 years
```

---

### **Step 5: Setup Monitoring & Maintenance** (For operations)
```bash
mysql -h localhost -u root mdata_lab < database/05_monitoring_maintenance.sql
```

**This provides:**
- ✅ Health check procedures
- ✅ Real-time data flow monitoring
- ✅ Performance analysis
- ✅ Machine status overview
- ✅ Data quality reporting
- ✅ Maintenance recommendations
- ✅ Alert summaries

---

## 📋 Table Descriptions

### **Core Tables (Step 1)**

#### `machines`
- **Purpose**: Configuration & status of Lab equipment
- **Key fields**: machine_id, device_type, protocols (JSON), status, last_sync
- **Indexes**: machine_id (unique), status, device_type

#### `raw_data` (PARTITIONED)
- **Purpose**: Store all raw sensor data from machines
- **Key fields**: machine_id, message_id, raw_payload (JSON), is_valid, partition_key
- **Partitions**: By quarter (2024_Q1, 2024_Q2, ..., 2026_Q1+)
- **Growth**: ~250M rows per quarter (estimated)
- **Strategy**: Time-based partitioning for performance

#### `error_log`
- **Purpose**: Track errors and warnings
- **Key fields**: machine_id, error_code, severity, resolved
- **Retention**: 12 months (configurable)

#### `sync_log`
- **Purpose**: Audit trail of data synchronizations
- **Key fields**: machine_id, batch_count, success_count, status, duration_ms
- **Retention**: 6 months (configurable)

#### `message_dedup`
- **Purpose**: Prevent duplicate records
- **Key fields**: message_id (unique), data_hash, duplicate_count
- **Strategy**: Check before insert using triggers

#### `protocol_config`
- **Purpose**: Store protocol-specific settings per machine
- **Key fields**: rs232_*, lan_*, file_* settings
- **Usage**: Sent via GET /api/config to Middleware

#### `middleware_cache`
- **Purpose**: Track cache status of Middleware instances
- **Key fields**: pending_count, cache_size_bytes, middleware_status
- **Update frequency**: Via POST /api/heartbeat

#### `data_transformation_log` (Phase 2 prep)
- **Purpose**: Track data transformation progress
- **Key fields**: raw_data_id, transformation_status, extracted_values

### **Enhancement Tables (Step 2)**

#### `machine_status_history`
- Tracks status changes (ACTIVE → ERROR, etc.)

#### `performance_metrics`
- Daily statistics per machine (records, errors, throughput)

#### `alert_rules`
- Configurable alert rules (threshold-based)

#### `audit_log`
- Tracks all administrative actions

#### `api_request_log`
- API call tracking for debugging

#### `retention_policies`
- Define data retention schedules

#### `machine_groups`
- Organize machines by category

#### `transformation_rules`
- Regex/parsing patterns for data extraction

#### `backup_info`
- Track backup and archive operations

#### `system_config`
- Global system configuration parameters

---

## 🔄 Views (Pre-built Queries)

### `v_active_machines_summary`
```sql
SELECT * FROM v_active_machines_summary;
```
- Shows all active machines with health status
- Last heartbeat time
- Pending cache items
- Records received in last 24h

### `v_error_summary_7days`
```sql
SELECT * FROM v_error_summary_7days;
```
- Error distribution for last 7 days
- Grouped by machine, error_code, severity
- Shows resolved vs unresolved

### `v_data_quality_report`
```sql
SELECT * FROM v_data_quality_report;
```
- Daily data quality metrics
- Valid vs invalid record counts
- Quality percentage per machine

---

## 🛠️ Stored Procedures

### **Schema 1: Partition Management**

```sql
-- Create quarterly partitions
CALL sp_create_quarterly_partitions(2026, 3);

-- Get partition sizes and statistics
CALL sp_get_partition_statistics();

-- Archive old partition data
CALL sp_archive_partition_data('2024_Q1');

-- Clean up expired data
CALL sp_cleanup_expired_data(730, 'archive');  -- 2 years

-- Monitor partition growth
CALL sp_monitor_partition_growth();

-- Get disk usage estimate
CALL sp_estimate_disk_usage();
```

### **Schema 2: Monitoring & Maintenance**

```sql
-- Run comprehensive health check
CALL sp_database_health_check();

-- Monitor real-time data flow
CALL sp_monitor_realtime_dataflow();

-- Analyze performance metrics
CALL sp_performance_analysis();

-- Get machine status overview
CALL sp_machine_status_overview();

-- Generate data quality report (last 7 days)
CALL sp_data_quality_report(7);

-- Create maintenance report
CALL sp_generate_maintenance_report();

-- Alert summary
CALL sp_alert_summary();
```

---

## 📊 Key Indexes for Performance

| Table | Index | Purpose |
|-------|-------|---------|
| raw_data | idx_machine_id | Filter by machine |
| raw_data | idx_received_at | Time-range queries |
| raw_data | idx_partition_key | Partition pruning |
| raw_data | (machine_id, received_at) | Common JOIN + TIME queries |
| error_log | (machine_id, severity) | Filter errors |
| sync_log | (machine_id, status) | Sync status tracking |
| machines | machine_id | Unique lookup |

---

## 🔐 Triggers

### Auto-update Machines Stats
```
TRIGGER trg_update_machine_record_count
  ON: INSERT raw_data
  ACTION: Increment machines.total_records_sent
```

```
TRIGGER trg_update_machine_error_count
  ON: INSERT error_log
  ACTION: Increment machines.total_errors
```

### Deduplication Tracking
```
TRIGGER trg_track_duplicate
  ON: INSERT raw_data
  ACTION: Update/insert message_dedup entries
```

---

## ⏰ Scheduled Events

### `evt_create_future_partitions` (Quarterly)
- Auto-creates partitions for future quarters
- Prevents "partition doesn't exist" errors
- Schedule: Every 1 quarter, triggers 1 quarter ahead

### `evt_cleanup_old_partitions` (Monthly)
- Archives partitions older than 24 months
- Moves to cold storage
- Schedule: Every 1 month

### `evt_daily_health_report` (Daily)
- Generates health report at midnight
- Can email or log results
- Schedule: Every day at 00:00

---

## 💾 Backup & Recovery

### Manual Backup
```bash
# Full database backup
mysqldump -h localhost -u root -p mdata_lab > mdata_lab_backup_$(date +%Y%m%d).sql

# Backup only raw_data partition
mysqldump -h localhost -u root -p mdata_lab raw_data > raw_data_backup.sql

# Compressed backup
mysqldump -h localhost -u root -p mdata_lab | gzip > mdata_lab_backup.sql.gz
```

### Restore from Backup
```bash
# Restore full database
mysql -h localhost -u root -p mdata_lab < mdata_lab_backup_20260422.sql

# Restore only raw_data
mysql -h localhost -u root -p mdata_lab < raw_data_backup.sql

# Restore from compressed
gunzip < mdata_lab_backup.sql.gz | mysql -h localhost -u root -p mdata_lab
```

---

## 🔍 Useful Queries

### Check Database Size
```sql
CALL sp_estimate_disk_usage();
```

### Get Active Machines
```sql
SELECT * FROM v_active_machines_summary;
```

### Data Quality Today
```sql
CALL sp_data_quality_report(1);
```

### Recent Errors
```sql
SELECT * FROM error_log 
WHERE error_timestamp > DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY error_timestamp DESC;
```

### Sync Success Rate (Last 7 days)
```sql
SELECT 
  DATE(sync_timestamp) AS date,
  ROUND(100.0 * SUM(CASE WHEN status='SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate
FROM sync_log
WHERE sync_timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(sync_timestamp);
```

### Machine Activity Dashboard
```sql
SELECT 
  m.machine_id,
  m.name,
  m.status,
  COUNT(rd.id) AS records_24h,
  MAX(rd.received_at) AS last_record,
  ROUND(100.0 * SUM(CASE WHEN rd.is_valid THEN 1 ELSE 0 END) / COUNT(rd.id), 2) AS valid_pct
FROM machines m
LEFT JOIN raw_data rd ON m.machine_id = rd.machine_id AND rd.received_at > DATE_SUB(NOW(), INTERVAL 1 DAY)
GROUP BY m.machine_id;
```

---

## 🚨 Troubleshooting

### Partition Full Error
```sql
-- Check partition status
CALL sp_get_partition_statistics();

-- Create missing partition
CALL sp_create_quarterly_partitions(2026, 3);
```

### Slow Queries
```sql
-- Analyze and optimize
CALL sp_performance_analysis();
OPTIMIZE TABLE raw_data;
ANALYZE TABLE raw_data;
```

### High CPU Usage
```sql
-- Check fragmentation
CALL sp_database_health_check();

-- Rebuild indexes
CALL sp_rebuild_partition_indexes('p2026_q2');
```

### Deduplication Issues
```sql
-- Check dedup table
SELECT COUNT(*) FROM message_dedup;

-- Clean up old dedup entries
CALL sp_cleanup_old_dedup_entries(30);
```

---

## 📝 Maintenance Schedule

| Task | Frequency | Command |
|------|-----------|---------|
| Health Check | Daily | `CALL sp_database_health_check();` |
| Data Quality Report | Daily | `CALL sp_data_quality_report(1);` |
| Performance Analysis | Weekly | `CALL sp_performance_analysis();` |
| Partition Growth Check | Weekly | `CALL sp_monitor_partition_growth();` |
| Optimize Tables | Monthly | `OPTIMIZE TABLE raw_data;` |
| Archive Old Data | Monthly | `CALL sp_cleanup_expired_data(730, 'archive');` |
| Create Future Partitions | Quarterly | `CALL sp_create_quarterly_partitions(year, quarter);` |
| Full Backup | Weekly | `mysqldump mdata_lab > backup.sql` |

---

## 🎯 Next Steps

1. ✅ Run step 1 (create schema)
2. ✅ Run step 2 (migrations)
3. ✅ Run step 3 (seed data) - only for testing
4. ✅ Run step 4 (partition management)
5. ✅ Run step 5 (monitoring)
6. ✅ Test API integration (see next guide)
7. ✅ Deploy Middleware (see Middleware guide)
8. ✅ Setup monitoring dashboard (optional)

---

## 📚 Related Documentation

- API Endpoints: See Node.js implementation guide
- Middleware: See C# .NET Middleware guide
- Monitoring: See Dashboard setup guide
- Phase 2: See Data Transformation guide

