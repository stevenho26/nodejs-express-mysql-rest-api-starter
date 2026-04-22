#!/usr/bin/env node

const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

// Simple logger for this script
const logger = {
  info: (msg) => console.log(`ℹ️  ${msg}`),
  error: (msg, err) => console.error(`❌ ${msg}`, err || ''),
  warn: (msg) => console.warn(`⚠️  ${msg}`)
};

/**
 * Database Setup Script
 * Chạy SQL script để tạo tables
 * Usage: node src/scripts/setup-db.js
 */

require('dotenv').config();

const config = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  port: parseInt(process.env.DB_PORT || '3306'),
  database: process.env.DB_NAME || 'acca_mdata',
  multipleStatements: true
};

async function setupDatabase() {
  let connection;
  try {
    logger.info('🔄 Connecting to MySQL...');
    
    // Connect without database first to create it
    const tempConfig = { ...config };
    delete tempConfig.database;
    connection = await mysql.createConnection(tempConfig);
    
    logger.info('✅ Connected to MySQL');
    
    // Read SQL script
    const sqlFilePath = path.join(__dirname, '..', '..', 'create_tables.sql');
    
    if (!fs.existsSync(sqlFilePath)) {
      logger.error(`SQL file not found: ${sqlFilePath}`);
      process.exit(1);
    }
    
    const sqlScript = fs.readFileSync(sqlFilePath, 'utf8');
    logger.info('📄 SQL script loaded');
    
    // Execute SQL script
    logger.info('⏳ Executing SQL script...');
    await connection.query(sqlScript);
    
    logger.info('✅ Database setup completed successfully!');
    logger.info(`📊 Tables created in database: ${config.database}`);
    
    // Get table info
    const [tables] = await connection.query(
      `SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ?`,
      [config.database]
    );
    
    if (tables.length > 0) {
      logger.info('📋 Tables created:');
      tables.forEach(table => {
        logger.info(`   ✓ ${table.TABLE_NAME}`);
      });
    }
    
    process.exit(0);
  } catch (error) {
    logger.error('Database setup failed:', error.message);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run setup
setupDatabase();
