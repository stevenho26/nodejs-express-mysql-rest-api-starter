const app = require('./app');
const config = require('./config/config');
const logger = require('./config/logger');

const port = config.port;
let server;

// Handle Uncaught exceptions
process.on('uncaughtException', (err) => {
  logger.error('UNCAUGHT EXCEPTION! 💥 Shutting down...');
  logger.error('uncaughtException:', err.name, err.message);
  process.exit(1);
});

server = app.listen(port, () => {
  logger.info(`Server is running on port: ${port}`);
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
