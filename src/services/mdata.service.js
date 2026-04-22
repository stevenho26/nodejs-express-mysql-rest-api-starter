const crypto = require('crypto');
const RawDataModel = require('../models/rawdata.model');
const MachineModel = require('../models/machine.model');
const ProtocolConfigModel = require('../models/protocolconfig.model');

class MDataService {
  /**
   * Get current partition key (e.g., 2024_Q1)
   */
  static getCurrentPartitionKey() {
    const now = new Date();
    const year = now.getFullYear();
    const quarter = Math.ceil((now.getMonth() + 1) / 3);
    return `${year}_Q${quarter}`;
  }

  /**
   * Calculate SHA256 hash of payload
   */
  static calculateHash(payload) {
    return crypto
      .createHash('sha256')
      .update(JSON.stringify(payload))
      .digest('hex');
  }

  /**
   * Validate raw data format
   */
  static validateRawDataFormat(data) {
    const errors = [];

    if (!data.machine_id) errors.push('machine_id is required');
    if (!data.message_id) errors.push('message_id is required');
    if (!data.protocol) errors.push('protocol is required');
    if (!data.raw_payload) errors.push('raw_payload is required');

    if (!['RS232', 'LAN', 'FILE', 'USB'].includes(data.protocol)) {
      errors.push('protocol must be one of: RS232, LAN, FILE, USB');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }

  /**
   * Process incoming raw data
   */
  static async processRawData(data) {
    try {
      // Validate machine exists
      const machine = await MachineModel.getMachineById(data.machine_id);
      if (!machine) {
        throw new Error(`Machine ${data.machine_id} not found`);
      }

      // Check for duplicates
      const existingData = await RawDataModel.getRawDataByMessageId(data.message_id);
      if (existingData) {
        throw new Error(`Duplicate message_id: ${data.message_id}`);
      }

      // Calculate hash
      const dataHash = this.calculateHash(data.raw_payload);

      // Get partition key
      const partitionKey = data.partition_key || this.getCurrentPartitionKey();

      // Parse payload if string
      const payload = typeof data.raw_payload === 'string' 
        ? data.raw_payload 
        : JSON.stringify(data.raw_payload);

      // Insert raw data
      const result = await RawDataModel.insertRawData(
        data.machine_id,
        data.message_id,
        data.protocol,
        payload,
        dataHash,
        data.batch_id || null,
        partitionKey
      );

      // Update machine heartbeat
      await MachineModel.updateHeartbeat(data.machine_id);

      return {
        success: true,
        id: result.insertId,
        message: 'Raw data processed successfully'
      };
    } catch (error) {
      throw new Error(`Error processing raw data: ${error.message}`, { cause: error });
    }
  }

  /**
   * Get all machines with health status
   */
  static async getAllMachinesWithStatus() {
    try {
      const machines = await MachineModel.getAllMachines();

      return machines.map(machine => ({
        id: machine.id,
        machine_id: machine.machine_id,
        name: machine.name,
        location: machine.location,
        device_type: machine.device_type,
        status: machine.status,
        last_sync: machine.last_sync,
        last_heartbeat: machine.last_heartbeat,
        total_records_sent: machine.total_records_sent,
        total_errors: machine.total_errors,
        is_online: this._isOnline(machine.last_heartbeat),
        time_since_heartbeat: this._getTimeSinceHeartbeat(machine.last_heartbeat)
      }));
} catch (error) {
      throw new Error(`Failed to get machines: ${error.message}`, { cause: error });
    }
  }

  /**
   * Check if machine is online
   */
  static _isOnline(lastHeartbeat) {
    if (!lastHeartbeat) return false;
    const now = new Date();
    const lastHeartbeatTime = new Date(lastHeartbeat);
    const diffMs = now - lastHeartbeatTime;
    const diffMinutes = diffMs / (1000 * 60);
    return diffMinutes < 5;
  }

  /**
   * Get human-readable time since last heartbeat
   */
  static _getTimeSinceHeartbeat(lastHeartbeat) {
    if (!lastHeartbeat) return 'Never';
    const now = new Date();
    const lastHeartbeatTime = new Date(lastHeartbeat);
    const diffMs = now - lastHeartbeatTime;
    
    const seconds = Math.floor(diffMs / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days} day${days > 1 ? 's' : ''} ago`;
    if (hours > 0) return `${hours} hour${hours > 1 ? 's' : ''} ago`;
    if (minutes > 0) return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
    return `${seconds} second${seconds > 1 ? 's' : ''} ago`;
  }

  /**
   * Create or update machine
   */
  static async createOrUpdateMachine(data) {
    try {
      await MachineModel.createOrUpdateMachine(
        data.machine_id,
        data.name,
        data.location || null,
        data.device_type,
        data.description || null,
        data.protocols || {}
      );

      const machine = await MachineModel.getMachineById(data.machine_id);
      return {
        success: true,
        data: machine,
        message: 'Machine created/updated successfully'
      };
    } catch (error) {
      throw new Error(`Failed to create/update machine: ${error.message}`, { cause: error });
    }
  }

  /**
   * Update machine configuration
   */
  static async updateMachineConfig(machineId, config) {
    try {
      // Verify machine exists
      const machine = await MachineModel.getMachineById(machineId);
      if (!machine) {
        throw new Error(`Machine ${machineId} not found`);
      }

      await ProtocolConfigModel.createOrUpdateConfig(machineId, config);

      const updatedConfig = await ProtocolConfigModel.getConfigByMachineId(machineId);
      return {
        success: true,
        data: updatedConfig,
        message: 'Configuration updated successfully'
      };
    } catch (error) {
      throw new Error(`Failed to update configuration: ${error.message}`, { cause: error });
    }
  }

  /**
   * Record heartbeat from middleware
   */
  static async recordHeartbeat(data) {
    try {
      // Verify machine exists
      const machine = await MachineModel.getMachineById(data.machine_id);
      if (!machine) {
        throw new Error(`Machine ${data.machine_id} not found`);
      }

      // Update heartbeat
      await MachineModel.updateHeartbeat(data.machine_id);

      return {
        success: true,
        message: 'Heartbeat recorded successfully'
      };
    } catch (error) {
      throw new Error(`Failed to record heartbeat: ${error.message}`, { cause: error });
    }
  }

  /**
   * Get API health status
   */
  static async getHealthStatus() {
    try {
      // Get machine count
      const machines = await MachineModel.getAllMachines();
      const activeMachines = machines.filter(m => m.status === 'ACTIVE');
      const onlineMachines = activeMachines.filter(m => this._isOnline(m.last_heartbeat));

      return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        machines: {
          total: machines.length,
          active: activeMachines.length,
          online: onlineMachines.length
        }
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        error: error.message
      };
    }
  }
}

module.exports = MDataService;
