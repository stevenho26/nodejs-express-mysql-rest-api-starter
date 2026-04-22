const { body, param, query, validationResult } = require('express-validator');

/**
 * Validate raw data payload
 */
const validateRawData = [
  body('machine_id')
    .trim()
    .notEmpty().withMessage('machine_id is required')
    .isLength({ min: 1, max: 50 }).withMessage('machine_id must be between 1-50 characters'),
  body('message_id')
    .trim()
    .notEmpty().withMessage('message_id is required')
    .isLength({ min: 1, max: 100 }).withMessage('message_id must be between 1-100 characters'),
  body('protocol')
    .trim()
    .notEmpty().withMessage('protocol is required')
    .isIn(['RS232', 'LAN', 'FILE', 'USB']).withMessage('protocol must be one of: RS232, LAN, FILE, USB'),
  body('raw_payload')
    .notEmpty().withMessage('raw_payload is required')
    .isLength({ min: 1 }).withMessage('raw_payload cannot be empty'),
  body('batch_id')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('batch_id must be max 100 characters'),
  body('partition_key')
    .optional()
    .trim()
    .matches(/^\d{4}_Q[1-4]$/).withMessage('partition_key must be in format: YYYY_Qn (e.g., 2024_Q1)'),
];

/**
 * Validate machine creation/update
 */
const validateMachine = [
  body('machine_id')
    .trim()
    .notEmpty().withMessage('machine_id is required')
    .isLength({ min: 1, max: 50 }).withMessage('machine_id must be between 1-50 characters'),
  body('name')
    .trim()
    .notEmpty().withMessage('name is required')
    .isLength({ min: 1, max: 100 }).withMessage('name must be between 1-100 characters'),
  body('device_type')
    .trim()
    .notEmpty().withMessage('device_type is required')
    .isLength({ max: 50 }).withMessage('device_type must be max 50 characters'),
  body('location')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('location must be max 100 characters'),
  body('description')
    .optional()
    .trim(),
  body('protocols')
    .optional()
    .isObject().withMessage('protocols must be an object'),
];

/**
 * Validate protocol configuration
 */
const validateProtocolConfig = [
  body('machine_id')
    .trim()
    .notEmpty().withMessage('machine_id is required'),
  body('rs232')
    .optional()
    .isObject().withMessage('rs232 must be an object'),
  body('lan')
    .optional()
    .isObject().withMessage('lan must be an object'),
  body('file')
    .optional()
    .isObject().withMessage('file must be an object'),
];

/**
 * Validate heartbeat
 */
const validateHeartbeat = [
  body('machine_id')
    .trim()
    .notEmpty().withMessage('machine_id is required'),
  body('middleware_version')
    .optional()
    .trim()
    .isLength({ max: 20 }).withMessage('middleware_version must be max 20 characters'),
  body('status')
    .optional()
    .isIn(['RUNNING', 'STOPPED', 'ERROR']).withMessage('status must be one of: RUNNING, STOPPED, ERROR'),
  body('pending_count')
    .optional()
    .isInt({ min: 0 }).withMessage('pending_count must be a non-negative integer'),
  body('cache_size_bytes')
    .optional()
    .isInt({ min: 0 }).withMessage('cache_size_bytes must be a non-negative integer'),
];

/**
 * Validate machine ID parameter
 */
const validateMachineIdParam = [
  param('machineId')
    .trim()
    .notEmpty().withMessage('machineId is required')
    .isLength({ min: 1, max: 50 }).withMessage('machineId must be between 1-50 characters'),
];

/**
 * Validate pagination query parameters
 */
const validatePagination = [
  query('limit')
    .optional()
    .isInt({ min: 1, max: 1000 }).withMessage('limit must be between 1-1000'),
  query('offset')
    .optional()
    .isInt({ min: 0 }).withMessage('offset must be a non-negative integer'),
];

/**
 * Handle validation errors
 */
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array().map(err => ({
        field: err.param,
        message: err.msg
      }))
    });
  }
  next();
};

module.exports = {
  validateRawData,
  validateMachine,
  validateProtocolConfig,
  validateHeartbeat,
  validateMachineIdParam,
  validatePagination,
  handleValidationErrors
};
