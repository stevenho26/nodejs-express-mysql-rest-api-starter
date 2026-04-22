const mysql = require('mysql2/promise');
require('dotenv').config();

(async () => {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || ''
  });

  try {
    console.log('🗑️  Dropping tables...');
    await conn.execute('DROP TABLE IF EXISTS `blogs`');
    console.log('  ✓ blogs table dropped');
    
    await conn.execute('DROP TABLE IF EXISTS `users`');
    console.log('  ✓ users table dropped');
    
    console.log('\n✅ Tables deleted successfully!');
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await conn.end();
  }
})();
