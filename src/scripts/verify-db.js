#!/usr/bin/env node

const mysql = require('mysql2/promise');
require('dotenv').config();

/**
 * Database Verification Script
 * Kiểm tra tables, structures, và data
 */

const config = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  port: parseInt(process.env.DB_PORT || '3306'),
  database: process.env.DB_NAME || 'acca_mdata'
};

async function verifyDatabase() {
  let connection;
  try {
    connection = await mysql.createConnection(config);
    
    console.log('\n✅ Connected to MySQL\n');
    
    // Show tables
    console.log('📋 Tables in database:');
    const [tables] = await connection.query(
      `SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ?`,
      [config.database]
    );
    tables.forEach(t => console.log(`   ✓ ${t.TABLE_NAME}`));
    
    // Users structure
    console.log('\n📊 Users Table Structure:');
    const [usersStructure] = await connection.query('DESCRIBE users');
    usersStructure.forEach(col => {
      console.log(`   ${col.Field.padEnd(15)} ${col.Type.padEnd(25)} ${col.Null === 'NO' ? 'NOT NULL' : 'NULLABLE'} ${col.Key ? `(${col.Key})` : ''}`);
    });
    
    // Blogs structure
    console.log('\n📊 Blogs Table Structure:');
    const [blogsStructure] = await connection.query('DESCRIBE blogs');
    blogsStructure.forEach(col => {
      console.log(`   ${col.Field.padEnd(15)} ${col.Type.padEnd(25)} ${col.Null === 'NO' ? 'NOT NULL' : 'NULLABLE'} ${col.Key ? `(${col.Key})` : ''}`);
    });
    
    // Data count
    console.log('\n📈 Data Summary:');
    const [userCount] = await connection.query('SELECT COUNT(*) as count FROM users');
    const [blogCount] = await connection.query('SELECT COUNT(*) as count FROM blogs');
    console.log(`   Users: ${userCount[0].count}`);
    console.log(`   Blogs: ${blogCount[0].count}`);
    
    // Users data
    console.log('\n👥 Users Data:');
    const [users] = await connection.query('SELECT id, name, email, role FROM users');
    users.forEach(user => {
      console.log(`   ID: ${user.id} | Name: ${user.name} | Email: ${user.email} | Role: ${user.role}`);
    });
    
    // Blogs data
    console.log('\n📝 Blogs Data:');
    const [blogs] = await connection.query('SELECT id, title, author FROM blogs LIMIT 5');
    blogs.forEach(blog => {
      console.log(`   ID: ${blog.id} | Title: ${blog.title} | Author: ${blog.author}`);
    });
    
    console.log('\n✅ Database verification completed!\n');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    if (connection) await connection.end();
  }
}

verifyDatabase();
