require('dotenv').config();

const config = {
    port: process.env.PORT || 5000,
    node_env: process.env.NODE_ENV || 'development',
    db: {
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        name: process.env.DB_NAME,
        dialect: process.env.DB_DIALECT,
        storage: process.env.DB_STORAGE
    },
    jwt_secret: process.env.JWT_SECRET,
    jwt_expires_in: process.env.JWT_EXPIRES_IN || '1h',
    seed_default_data: process.env.SEED_DEFAULT_DATA === 'true',
    default_seed_password: process.env.DEFAULT_SEED_PASSWORD || 'password123'
};

module.exports = config;
