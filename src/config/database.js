const { Sequelize } = require('sequelize');
const config = require('./config');
const logger = require('./logger');

const sequelize = config.db.dialect === 'sqlite'
    ? new Sequelize({
        dialect: 'sqlite',
        storage: config.db.storage || ':memory:',
        logging: false
    })
    : new Sequelize(config.db.name, config.db.user, config.db.password, {
        host: config.db.host,
        dialect: config.db.dialect,
        logging: false
    });

const connectDB = async () => {
    try {
        await sequelize.authenticate();
        logger.info(`${config.db.dialect || 'database'} connected`);
    } catch (err) {
        logger.error('Database connection error:', err);
        process.exit(1);
    }
};

module.exports = {
    sequelize,
    connectDB
};
