const app = require('./app');
const config = require('./config/config');
const logger = require('./config/logger');
const { connectDB, sequelize } = require('./config/database');
const seedDefaultData = require('./scripts/seed');

const port = config.port;
let server;

// Handle Uncaught exceptions
process.on('uncaughtException', (err) => {
  logger.error('UNCAUGHT EXCEPTION! 💥 Shutting down...');
  logger.error('uncaughtException:', err.name, err.message);
  process.exit(1);
});

connectDB().then(async () => {
  logger.info('Syncing database...');
  await sequelize.sync({ force: false }); // Set force to true to drop and re-create tables
  logger.info('Database synced.');
  logger.info('Seeding data...');
  await seedDefaultData();
  logger.info('Data seeded.');
  server = app.listen(port, () => {
    logger.info(`Server is running on port: ${port}`);
  });
}).catch(err => {
    logger.error('Error during startup: ', err);
    process.exit(1);
});


// Handle Unhandled Rejections
process.on('unhandledRejection', (err) => {
  logger.error('UNHANDLED REJECTION! 💥 Shutting down...', err);
  if (server && server.close) {
    server.close(() => {
      process.exit(1);
    });
    return;
  }
  process.exit(1);
});
