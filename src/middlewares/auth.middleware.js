const jwt = require('jsonwebtoken');
const userHelper = require('../helpers/user.helper');
const config = require('../config/config');
const ApiError = require('../utils/ApiError');

const auth = async (req, res, next) => {
    try {
        const token = req.header('Authorization').replace('Bearer ', '');
        const decoded = jwt.verify(token, config.jwt_secret);
        const user = await userHelper.findUserById(decoded.id);
        if (!user) {
            throw new ApiError(401, 'Please authenticate.');
        }
        req.token = token;
        req.user = user;
        next();
    } catch {
        next(new ApiError(401, 'Please authenticate.'));
    }
};

module.exports = auth;
