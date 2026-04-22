const express = require('express');
const cors = require('cors');
const logger = require('./config/logger');
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./config/swagger');
const app = express();

app.use(cors());
app.use(express.json());

const routes = require('./routes');
app.use('/api', routes);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Global Error Handler
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  logger.error('Global Error Handler:', err);
  if (err.isOperational) {
    return res.status(err.statusCode).send({ success: false, messages: err.messages });
  }
  res.status(500).send({ success: false, message: 'Something broke!' });
});

module.exports = app;
