const mysql = require('mysql2/promise');
require('dotenv').config();

(async () => {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || ''
  });
  
  const [tables] = await conn.execute('SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = "acca_mdata" AND TABLE_NAME LIKE "tbl_%"');
  
  console.log('\n✅ Tables created in acca_mdata database:\n');
  tables.forEach((row, i) => {
    console.log(`  ${i + 1}. ${row.TABLE_NAME}`);
  });
  
  console.log(`\n📊 Total: ${tables.length} tables\n`);
  await conn.end();
})();
