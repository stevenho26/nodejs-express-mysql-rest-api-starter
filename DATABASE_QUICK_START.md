# 🚀 MData Lab Database - Quick Start Guide

## ⚡ Quick Setup (3 Steps)

### Step 1: Setup Database with Seed Data
```bash
npm run setup-mdata-db-seed
```
✅ Creates all tables, triggers, procedures, and loads sample data

### Step 2: Verify Setup
```bash
npm run verify-db
```
✅ Shows database structure and sample data

### Step 3: Start Application
```bash
npm start
```
✅ Server runs on http://localhost:5000

---

## 📊 Database Architecture

```
┌─────────────────────────────────────────────────────┐
│              MySQL Database (mdata_lab)              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Core Tables:                                       │
│  • machines - Device configuration & status        │
│  • raw_data - Sensor data (PARTITIONED by quarter) │
│  • error_log - Error tracking                      │
│  • sync_log - Sync audit trail                     │
│  • message_dedup - Duplicate prevention            │
│  • protocol_config - Device protocols              │
│  • middleware_cache - Cache status                 │
│  • data_transformation_log - Phase 2 prep          │
│                                                     │
│  Enhancement Tables (from migrations):             │
│  • machine_status_history                          │
│  • performance_metrics                             │
│  • alert_rules                                      │
│  • audit_log                                        │
│  • api_request_log                                  │
│  • And 5+ more...                                   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 📁 File Structure

```
database/
├── 01_create_mdata_schema.sql      Main schema (REQUIRED)
├── 02_migrations.sql                Enhancements (optional)
├── 03_seed_data.sql                 Sample data (testing only)
├── 04_partition_management.sql      Partition management
├── 05_monitoring_maintenance.sql    Monitoring queries
└── README.md                         Detailed documentation

src/scripts/
├── setup-db.js                      Original demo setup
├── verify-db.js                     Demo verification
├── setup-mdata-db.js                ← Full MData Lab setup (NEW)
└── verify-mdata-db.js               ← Verification for MData Lab

Package scripts:
├── npm start                         Run server
├── npm test                          Run tests
├── npm run lint                      Check code
├── npm run create-db                 (Old) Create demo DB
├── npm run verify-db                 (Old) Verify demo DB
├── npm run setup-mdata-db            (NEW) Setup MData Lab
└── npm run setup-mdata-db-seed       (NEW) Setup with sample data
```

---

## 📋 Tables at a Glance

| Table | Purpose | Rows | Size |
|-------|---------|------|------|
| **machines** | Device config | 5-100 | KB |
| **raw_data** (partitioned) | Sensor data | Billions | 100s GB |
| **error_log** | Errors/alerts | Millions | GBs |
| **sync_log** | Sync tracking | Millions | MBs |
| **message_dedup** | Duplicate prevention | Millions | MBs |
| **protocol_config** | Device settings | 5-100 | KB |
| **middleware_cache** | Cache status | 5-100 | KB |
| **machine_status_history** | Status changes | Thousands | MBs |

---

## 🔄 Data Flow Architecture

```
┌──────────────────────┐
│   Lab Machines       │
│  (RS232, LAN, File)  │
└──────────────┬───────┘
               │
               ↓
    ┌──────────────────────┐
    │     Middleware       │
    │   (C# .NET Service)  │
    │  - Multi-protocol    │
    │  - Local cache       │
    │  - Auto sync         │
    └──────────────┬───────┘
                   │
                   ↓ HTTP/HTTPS
           ┌───────────────────┐
           │   Node.js API     │
           │ /api/raw-data     │
           │ /api/config       │
           │ /api/heartbeat    │
           └─────────┬─────────┘
                     │
                     ↓
         ┌─────────────────────────┐
         │   MySQL Database        │
         ├─────────────────────────┤
         │ • Raw Data (Partitioned)│
         │ • Error Logs            │
         │ • Sync Logs             │
         │ • Performance Metrics   │
         │ • Machine Status        │
         └─────────────────────────┘
```

---

## 🎯 Common Tasks

### 1. Check Machine Status
```sql
SELECT * FROM v_active_machines_summary;
```

### 2. View Recent Data
```sql
SELECT machine_id, protocol, received_at, is_valid 
FROM raw_data 
ORDER BY received_at DESC 
LIMIT 10;
```

### 3. Get Data Quality Report
```sql
CALL sp_data_quality_report(7);  -- Last 7 days
```

### 4. Monitor Real-time Activity
```sql
CALL sp_monitor_realtime_dataflow();
```

### 5. Check Database Health
```sql
CALL sp_database_health_check();
```

### 6. View Error Summary
```sql
SELECT * FROM v_error_summary_7days;
```

### 7. Get Sync Performance
```sql
CALL sp_performance_analysis();
```

### 8. Check Partition Sizes
```sql
CALL sp_get_partition_statistics();
```

---

## 🛠️ Maintenance Commands

### Daily Tasks
```bash
# Check health
mysql -h localhost -u root mdata_lab -e "CALL sp_database_health_check();"

# Monitor data flow
mysql -h localhost -u root mdata_lab -e "CALL sp_monitor_realtime_dataflow();"
```

### Weekly Tasks
```bash
# Performance analysis
mysql -h localhost -u root mdata_lab -e "CALL sp_performance_analysis();"

# Check partition growth
mysql -h localhost -u root mdata_lab -e "CALL sp_monitor_partition_growth();"
```

### Monthly Tasks
```bash
# Archive old data (older than 2 years)
mysql -h localhost -u root mdata_lab -e "CALL sp_cleanup_expired_data(730, 'archive');"

# Optimize tables
mysql -h localhost -u root mdata_lab -e "OPTIMIZE TABLE raw_data;"

# Backup database
mysqldump -h localhost -u root mdata_lab > mdata_lab_$(date +%Y%m%d).sql
```

### Quarterly Tasks
```bash
# Create new quarter partition
mysql -h localhost -u root mdata_lab -e "CALL sp_create_quarterly_partitions(2026, 3);"
```

---

## 🔐 Security Notes

### Create Application User
```sql
CREATE USER 'mdata_app'@'localhost' IDENTIFIED BY 'strong_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON mdata_lab.* TO 'mdata_app'@'localhost';
GRANT EXECUTE ON mdata_lab.* TO 'mdata_app'@'localhost';
FLUSH PRIVILEGES;
```

### Create Read-Only User
```sql
CREATE USER 'mdata_readonly'@'localhost' IDENTIFIED BY 'readonly_password';
GRANT SELECT ON mdata_lab.* TO 'mdata_readonly'@'localhost';
FLUSH PRIVILEGES;
```

---

## 📊 Monitoring Dashboard Queries

### System Health Score
```sql
SELECT 
  CASE 
    WHEN COUNT(CASE WHEN middleware_status = 'ERROR' THEN 1 END) > 0 THEN '🔴 CRITICAL'
    WHEN COUNT(CASE WHEN last_heartbeat < DATE_SUB(NOW(), INTERVAL 10 MINUTE) THEN 1 END) > 0 THEN '🟠 WARNING'
    ELSE '🟢 HEALTHY'
  END AS health_status,
  COUNT(*) AS total_machines,
  COUNT(CASE WHEN middleware_status = 'RUNNING' THEN 1 END) AS running,
  COUNT(CASE WHEN middleware_status = 'ERROR' THEN 1 END) AS errors
FROM machines m
LEFT JOIN middleware_cache mc ON m.machine_id = mc.machine_id;
```

### Data Ingestion Rate (records/hour)
```sql
SELECT 
  HOUR(received_at) AS hour,
  COUNT(*) AS records_per_hour,
  COUNT(DISTINCT machine_id) AS active_machines
FROM raw_data 
WHERE received_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
GROUP BY HOUR(received_at)
ORDER BY hour DESC;
```

### Data Quality Trend
```sql
SELECT 
  DATE(received_at) AS date,
  ROUND(100.0 * SUM(CASE WHEN is_valid THEN 1 ELSE 0 END) / COUNT(*), 2) AS quality_percent
FROM raw_data 
WHERE received_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(received_at)
ORDER BY date;
```

---

## 🚀 API Endpoints (Ready for Implementation)

### Configuration
```
GET /api/config/:machine_id
  Returns: Protocol configs, sync intervals, batch sizes

POST /api/heartbeat/:machine_id
  Receives: Cache status, pending items, protocol status

GET /api/status/:machine_id
  Returns: Machine health, middleware status, pending sync
```

### Data Collection
```
POST /api/raw-data
  Body: Machine data batch
  Returns: Ack with received IDs

POST /api/raw-data/ack
  Body: List of message IDs to acknowledge
  Returns: Cleanup status
```

### Monitoring
```
GET /api/machines
  Returns: All machines with status

GET /api/machines/:machine_id/stats
  Returns: Last 24h statistics

GET /api/errors
  Returns: Recent errors with filters

GET /api/health
  Returns: System health status
```

---

## 📈 Performance Tuning

### Index Usage
```sql
-- Check which indexes are used
SELECT * FROM performance_schema.table_io_waits_summary_by_index_usage;

-- Find missing indexes
SELECT * FROM performance_schema.table_io_waits_summary_by_table
WHERE object_schema = 'mdata_lab' AND COUNT_READ + COUNT_WRITE > 1000;
```

### Query Performance
```sql
-- Enable query profiling
SET profiling = 1;
SELECT * FROM raw_data WHERE machine_id = 'LAB_001' LIMIT 100;
SHOW PROFILE;
```

### Partition Optimization
```sql
-- Analyze partition distribution
CALL sp_monitor_partition_growth();

-- Auto-optimize
OPTIMIZE TABLE raw_data;
ANALYZE TABLE raw_data;
```

---

## 🐛 Troubleshooting

### "Partition doesn't exist" Error
```sql
-- Create missing partition
CALL sp_create_quarterly_partitions(2026, 2);
```

### Slow Queries
```sql
-- Analyze performance
CALL sp_performance_analysis();

-- Check index fragmentation
CALL sp_database_health_check();

-- Rebuild indexes
CALL sp_rebuild_partition_indexes('p2026_q2');
```

### High Memory Usage
```sql
-- Check table sizes
CALL sp_estimate_disk_usage();

-- Archive old data
CALL sp_cleanup_expired_data(730, 'archive');
```

### Deduplication Issues
```sql
-- Check dedup table
SELECT COUNT(*) FROM message_dedup;

-- Clean up old entries
CALL sp_cleanup_old_dedup_entries(30);
```

---

## 📚 Documentation Files

- `database/README.md` - Comprehensive guide
- `database/01_create_mdata_schema.sql` - Main schema details
- `PLAN.md` - Overall system architecture
- API Implementation Guide (coming)
- Middleware Implementation Guide (coming)

---

## ✅ Checklist

- [ ] Run `npm run setup-mdata-db-seed`
- [ ] Verify with `npm run verify-db`
- [ ] Check logs: `npm start`
- [ ] Access API: http://localhost:5000/api-docs
- [ ] Run tests: `npm test`
- [ ] Setup monitoring dashboard (optional)
- [ ] Configure alerting (optional)
- [ ] Deploy to production (follow deployment guide)

---

## 📞 Support

For issues or questions:
1. Check `database/README.md` for detailed documentation
2. Review PLAN.md for architecture overview
3. Check error logs in database: `SELECT * FROM error_log WHERE resolved = FALSE;`
4. Run health check: `CALL sp_database_health_check();`

