const express = require('express');
const router = express.Router();
const MDataController = require('../controllers/mdata.controller');
const {
  validateRawData,
  validateMachine,
  validateProtocolConfig,
  validateHeartbeat,
  validateMachineIdParam,
  validatePagination,
  handleValidationErrors
} = require('../validators/mdata.validator');

/**
 * Raw Data Endpoints
 */

// Receive raw data from middleware
router.post(
  '/raw-data',
  validateRawData,
  handleValidationErrors,
  MDataController.receiveRawData
);

/**
 * Machine Endpoints
 */

// Create or update machine
router.post(
  '/machines',
  validateMachine,
  handleValidationErrors,
  MDataController.createOrUpdateMachine
);

// Get all machines
router.get(
  '/machines',
  MDataController.getAllMachines
);

// Get machine details
router.get(
  '/machines/:machineId',
  validateMachineIdParam,
  handleValidationErrors,
  MDataController.getMachineDetails
);

/**
 * Configuration Endpoints
 */

// Get machine configuration
router.get(
  '/config/:machineId',
  validateMachineIdParam,
  handleValidationErrors,
  MDataController.getMachineConfig
);

// Update machine configuration
router.put(
  '/config/:machineId',
  validateMachineIdParam,
  validateProtocolConfig,
  handleValidationErrors,
  MDataController.updateMachineConfig
);

/**
 * Heartbeat Endpoints
 */

// Record heartbeat from middleware
router.post(
  '/heartbeat',
  validateHeartbeat,
  handleValidationErrors,
  MDataController.recordHeartbeat
);

/**
 * Health Endpoints
 */

// Get API health status
router.get(
  '/health',
  MDataController.getHealth
);

module.exports = router;
