const MDataService = require('../services/mdata.service');
const logger = require('../config/logger');

class MDataController {
  /**
   * POST /api/mdata/raw-data - Receive raw data from middleware
   */
  static async receiveRawData(req, res) {
    try {
      const { machine_id, message_id, protocol, raw_payload, batch_id, partition_key } = req.body;

      logger.info(`Received raw data from machine: ${machine_id}`);

      // Validate format
      const validation = MDataService.validateRawDataFormat({
        machine_id,
        message_id,
        protocol,
        raw_payload
      });

      if (!validation.isValid) {
        return res.status(400).json({
          success: false,
          message: 'Validation failed',
          errors: validation.errors
        });
      }

      // Process data
      const result = await MDataService.processRawData({
        machine_id,
        message_id,
        protocol,
        raw_payload,
        batch_id,
        partition_key
      });

      res.status(201).json({
        success: true,
        data: result,
        message: 'Raw data received and processed'
      });
    } catch (error) {
      logger.error(`Error receiving raw data: ${error.message}`);
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  /**
   * POST /api/mdata/machines - Create or update machine
   */
  static async createOrUpdateMachine(req, res) {
    try {
      const { machine_id, name, location, device_type, description, protocols } = req.body;

      logger.info(`Creating/updating machine: ${machine_id}`);

      const result = await MDataService.createOrUpdateMachine({
        machine_id,
        name,
        location,
        device_type,
        description,
        protocols
      });

      res.status(201).json(result);
    } catch (error) {
      logger.error(`Error creating/updating machine: ${error.message}`);
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  /**
   * GET /api/mdata/machines - Get all machines
   */
  static async getAllMachines(req, res) {
    try {
      logger.info('Fetching all machines');

      const machines = await MDataService.getAllMachinesWithStatus();

      res.status(200).json({
        success: true,
        data: machines,
        count: machines.length
      });
    } catch (error) {
      logger.error(`Error fetching machines: ${error.message}`);
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  /**
   * GET /api/mdata/machines/:machineId - Get machine details
   */
  static async getMachineDetails(req, res) {
    try {
      const { machineId } = req.params;

      logger.info(`Fetching machine details: ${machineId}`);

      const machine = await MDataService.getMachineDetails(machineId);
      if (!machine) {
        return res.status(404).json({
          success: false,
          message: `Machine ${machineId} not found`
        });
      }

      res.status(200).json({
        success: true,
        data: machine
      });
    } catch (error) {
      logger.error(`Error fetching machine details: ${error.message}`);
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  /**
   * GET /api/mdata/config/:machineId - Get machine configuration
   */
  static async getMachineConfig(req, res) {
    try {
      const { machineId } = req.params;

      logger.info(`Fetching config for machine: ${machineId}`);

      const MachineModel = require('../models/machine.model');
      const ProtocolConfigModel = require('../models/protocolconfig.model');

      const machine = await MachineModel.getMachineById(machineId);
      if (!machine) {
        return res.status(404).json({
          success: false,
          message: `Machine ${machineId} not found`
        });
      }

      const config = await ProtocolConfigModel.getConfigByMachineId(machineId);

      res.status(200).json({
        success: true,
        data: config || {
          message: 'No configuration found for this machine',
          machine_id: machineId
        }
      });
    } catch (error) {
      logger.error(`Error fetching config: ${error.message}`);
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  /**
   * PUT /api/mdata/config/:machineId - Update machine configuration
   */
  static async updateMachineConfig(req, res) {
    try {
      const { machineId } = req.params;
      const config = req.body;

      logger.info(`Updating config for machine: ${machineId}`);

      const result = await MDataService.updateMachineConfig(machineId, config);

      res.status(200).json(result);
    } catch (error) {
      logger.error(`Error updating config: ${error.message}`);
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  /**
   * POST /api/mdata/heartbeat - Record heartbeat from middleware
   */
  static async recordHeartbeat(req, res) {
    try {
      const { machine_id, middleware_version, status, pending_count, cache_size_bytes } = req.body;

      logger.info(`Heartbeat received from machine: ${machine_id}`);

      const result = await MDataService.recordHeartbeat({
        machine_id,
        middleware_version,
        status,
        pending_count,
        cache_size_bytes
      });

      res.status(200).json(result);
    } catch (error) {
      logger.error(`Error recording heartbeat: ${error.message}`);
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  /**
   * GET /api/mdata/health - Get API health status
   */
  static async getHealth(req, res) {
    try {
      const health = await MDataService.getHealthStatus();
      const statusCode = health.status === 'healthy' ? 200 : 503;

      res.status(statusCode).json(health);
    } catch (error) {
      logger.error(`Error getting health status: ${error.message}`);
      res.status(503).json({
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        error: error.message
      });
    }
  }
}

// Add missing method
MDataController.prototype.getMachineDetails = async function(machineId) {
  const MachineModel = require('../models/machine.model');
  return await MachineModel.getMachineById(machineId);
};

module.exports = MDataController;
