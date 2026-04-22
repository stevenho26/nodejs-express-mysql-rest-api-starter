const userHelper = require('../helpers/user.helper');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const UserResponse = require('../dto/user.response');
const config = require('../config/config');
const ApiError = require('../utils/ApiError');

const register = async (userData) => {
    if (await userHelper.findUserByEmail(userData.email)) {
        throw new ApiError(400, 'Email already taken');
    }
    const user = await userHelper.createUser(userData);
    return new UserResponse(user);
};

const login = async (email, password) => {
    const user = await userHelper.findUserByEmail(email);
    if (!user) {
        throw new ApiError(401, 'Incorrect email or password');
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
        throw new ApiError(401, 'Incorrect email or password');
    }

    const token = jwt.sign(
        { id: user.id.toString() },
        config.jwt_secret,
        { expiresIn: config.jwt_expires_in }
    );
    return { user: new UserResponse(user), token };
};

module.exports = {
    register,
    login
};
