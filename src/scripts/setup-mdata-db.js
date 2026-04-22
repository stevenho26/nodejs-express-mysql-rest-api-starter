#!/usr/bin/env node

const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

/**
 * MData Lab Database Setup Script
 * Automatically runs all SQL migration scripts in order
 * Usage: node src/scripts/setup-mdata-db.js [--seed] [--force]
 */

const config = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  port: parseInt(process.env.DB_PORT || '3306'),
  multipleStatements: true,
  waitForConnections: true,
  connectionLimit: 1,
  queueLimit: 0
};

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logSection(title) {
  console.log('\n');
  log('='.repeat(60), 'cyan');
  log(`  ${title}`, 'bright');
  log('='.repeat(60), 'cyan');
}

function logSuccess(message) {
  log(`✅ ${message}`, 'green');
}

function logError(message) {
  log(`❌ ${message}`, 'red');
}

function logWarning(message) {
  log(`⚠️  ${message}`, 'yellow');
}

function logInfo(message) {
  log(`ℹ️  ${message}`, 'blue');
}

async function executeSqlScript(connection, scriptPath, scriptName) {
  try {
    logInfo(`Loading script: ${scriptName}`);
    
    if (!fs.existsSync(scriptPath)) {
      throw new Error(`Script not found: ${scriptPath}`);
    }
    
    const sql = fs.readFileSync(scriptPath, 'utf8');
    const fileSize = (fs.statSync(scriptPath).size / 1024).toFixed(2);
    logInfo(`Script size: ${fileSize} KB`);
    
    logInfo(`Executing ${scriptName}...`);
    
    const startTime = Date.now();
    await connection.query(sql);
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    
    logSuccess(`${scriptName} completed in ${duration}s`);
    
    return true;
  } catch (error) {
    logError(`${scriptName} failed: ${error.message}`);
    
    // Print more details for debugging
    if (error.sql) {
      logInfo(`Problem SQL: ${error.sql.substring(0, 100)}...`);
    }
    
    return false;
  }
}

async function setupDatabase() {
  let connection;
  
  try {
    logSection('MData Lab Database Setup');
    
    // Parse command line arguments
    const args = process.argv.slice(2);
    const includeSeed = args.includes('--seed');
    const forceSetup = args.includes('--force');
    
    logInfo(`Setup mode: ${includeSeed ? 'WITH SEED DATA' : 'WITHOUT SEED DATA'}`);
    
    // Connect to MySQL
    logSection('Step 1: Connecting to MySQL');
    logInfo(`Host: ${config.host}`);
    logInfo(`Port: ${config.port}`);
    logInfo(`User: ${config.user}`);
    
    // First connect without database
    const tempConfig = { ...config };
    delete tempConfig.multipleStatements;
    
    connection = await mysql.createConnection(tempConfig);
    logSuccess('Connected to MySQL server');
    
    // Create database if not exists
    logInfo('Creating database mdata_lab...');
    await connection.query('CREATE DATABASE IF NOT EXISTS mdata_lab CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
    logSuccess('Database created or already exists');
    
    // Now connect to the specific database
    await connection.end();
    
    config.database = 'mdata_lab';
    config.multipleStatements = true;
    connection = await mysql.createConnection(config);
    logSuccess('Connected to mdata_lab database');
    
    // Disable foreign key checks temporarily
    await connection.query('SET FOREIGN_KEY_CHECKS = 0');
    
    // Step 1: Create main schema
    logSection('Step 2: Creating Main Schema');
    const scriptPath1 = path.join(__dirname, '..', '..', 'database', '01_create_mdata_schema.sql');
    if (!await executeSqlScript(connection, scriptPath1, '01_create_mdata_schema.sql')) {
      throw new Error('Main schema creation failed');
    }
    
    // Step 2: Apply migrations
    logSection('Step 3: Applying Migrations');
    const scriptPath2 = path.join(__dirname, '..', '..', 'database', '02_migrations.sql');
    if (!await executeSqlScript(connection, scriptPath2, '02_migrations.sql')) {
      logWarning('Migrations partially failed - continuing with setup');
    }
    
    // Step 3: Load seed data (optional)
    if (includeSeed) {
      logSection('Step 4: Loading Seed Data');
      const scriptPath3 = path.join(__dirname, '..', '..', 'database', '03_seed_data.sql');
      if (!await executeSqlScript(connection, scriptPath3, '03_seed_data.sql')) {
        logWarning('Seed data loading partially failed');
      }
    } else {
      logSection('Step 4: Skipping Seed Data');
      logInfo('Run with --seed flag to include sample data');
    }
    
    // Step 4: Setup partition management
    logSection('Step 5: Setting Up Partition Management');
    const scriptPath4 = path.join(__dirname, '..', '..', 'database', '04_partition_management.sql');
    if (!await executeSqlScript(connection, scriptPath4, '04_partition_management.sql')) {
      logWarning('Partition management setup partially failed');
    }
    
    // Step 5: Setup monitoring
    logSection('Step 6: Setting Up Monitoring & Maintenance');
    const scriptPath5 = path.join(__dirname, '..', '..', 'database', '05_monitoring_maintenance.sql');
    if (!await executeSqlScript(connection, scriptPath5, '05_monitoring_maintenance.sql')) {
      logWarning('Monitoring setup partially failed');
    }
    
    // Re-enable foreign key checks
    await connection.query('SET FOREIGN_KEY_CHECKS = 1');
    
    // Final verification
    logSection('Step 7: Database Verification');
    
    try {
      const [tables] = await connection.query(
        'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = "mdata_lab" ORDER BY TABLE_NAME'
      );
      logSuccess(`Database contains ${tables.length} tables:`);
      tables.forEach(t => {
        log(`   ✓ ${t.TABLE_NAME}`, 'dim');
      });
      
      // Get partitions
      const [partitions] = await connection.query(
        `SELECT COUNT(*) as count FROM information_schema.partitions 
         WHERE table_schema = 'mdata_lab' AND table_name = 'raw_data' AND partition_name IS NOT NULL`
      );
      logSuccess(`Partitions created: ${partitions[0].count}`);
      
      // Get size
      const [size] = await connection.query(
        `SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2) as size_gb 
         FROM information_schema.tables WHERE table_schema = 'mdata_lab'`
      );
      logSuccess(`Database size: ${size[0].size_gb || 0} GB`);
      
      if (includeSeed) {
        const [recordCount] = await connection.query('SELECT COUNT(*) as count FROM raw_data');
        logSuccess(`Sample data records: ${recordCount[0].count}`);
      }
      
    } catch (error) {
      logWarning(`Verification query failed: ${error.message}`);
    }
    
    // Summary
    logSection('Setup Completed Successfully! 🎉');
    log('\nNext steps:', 'bright');
    log('1. Run tests: npm test', 'dim');
    log('2. Start API server: npm start', 'dim');
    log('3. Access Swagger docs: http://localhost:5000/api-docs', 'dim');
    log('4. Check database: mysql -h localhost -u root mdata_lab', 'dim');
    log('\nUseful queries:', 'bright');
    log('   SELECT * FROM v_active_machines_summary;', 'dim');
    log('   CALL sp_database_health_check();', 'dim');
    log('   CALL sp_monitor_realtime_dataflow();', 'dim');
    log('\nDocumentation: See database/README.md', 'bright');
    
    process.exit(0);
    
  } catch (error) {
    logError(`Setup failed: ${error.message}`);
    if (error.sql) {
      logInfo(`Last executed SQL: ${error.sql.substring(0, 150)}...`);
    }
    process.exit(1);
  } finally {
    if (connection) {
      try {
        await connection.end();
        logInfo('Database connection closed');
      } catch (e) {
        // Ignore
      }
    }
  }
}

// Show usage
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  log('\n🔧 MData Lab Database Setup', 'bright');
  log('\nUsage:', 'bright');
  log('  node src/scripts/setup-mdata-db.js [options]\n', 'dim');
  log('Options:', 'bright');
  log('  --seed              Include sample data for testing', 'dim');
  log('  --force             Force recreate all objects', 'dim');
  log('  --help, -h          Show this help message\n', 'dim');
  log('Examples:', 'bright');
  log('  # Full setup with sample data:', 'dim');
  log('  node src/scripts/setup-mdata-db.js --seed\n', 'cyan');
  log('  # Basic setup without sample data:', 'dim');
  log('  node src/scripts/setup-mdata-db.js\n', 'cyan');
  process.exit(0);
}

// Run setup
setupDatabase();
