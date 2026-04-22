const Joi = require('joi');
const ApiError = require('../utils/ApiError');

const validate = (schema) => (req, res, next) => {
  const { value, error } = Joi.compile(schema)
    .prefs({ errors: { label: 'key' } })
    .validate(req.body);

  if (error) {
    const errorMessages = error.details.map((details) => details.message.replace(/"/g, ''));
    return next(new ApiError(400, errorMessages));
  }
  req.body = value;
  return next();
};

module.exports = validate;
