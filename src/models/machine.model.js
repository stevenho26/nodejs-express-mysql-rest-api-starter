const pool = require('../config/database');

class MachineModel {
  /**
   * Create or update a machine
   */
  static async createOrUpdateMachine(machineId, name, location, deviceType, description, protocols) {
    const query = `
      INSERT INTO tbl_machines (
        machine_id, name, location, device_type, description, protocols, status
      ) VALUES (?, ?, ?, ?, ?, ?, 'ACTIVE')
      ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        location = VALUES(location),
        device_type = VALUES(device_type),
        description = VALUES(description),
        protocols = VALUES(protocols),
        updated_at = NOW()
    `;
    
    try {
      const [result] = await pool.execute(query, [
        machineId, name, location, deviceType, description, JSON.stringify(protocols)
      ]);
      return result;
    } catch (error) {
      throw new Error(`Failed to create/update machine: ${error.message}`);
    }
  }

  /**
   * Get all machines
   */
  static async getAllMachines() {
    const query = `
      SELECT 
        id, machine_id, name, location, device_type, description, 
        protocols, status, last_sync, last_heartbeat, 
        total_records_sent, total_errors, created_at, updated_at
      FROM tbl_machines
      ORDER BY created_at DESC
    `;
    
    try {
      const [rows] = await pool.execute(query);
      return rows.map(row => ({
        ...row,
        protocols: typeof row.protocols === 'string' ? JSON.parse(row.protocols) : row.protocols
      }));
    } catch (error) {
      throw new Error(`Failed to get machines: ${error.message}`);
    }
  }

  /**
   * Get machine by ID
   */
  static async getMachineById(machineId) {
    const query = `
      SELECT * FROM tbl_machines WHERE machine_id = ?
    `;
    
    try {
      const [rows] = await pool.execute(query, [machineId]);
      if (rows.length > 0) {
        const machine = rows[0];
        machine.protocols = typeof machine.protocols === 'string' ? JSON.parse(machine.protocols) : machine.protocols;
        return machine;
      }
      return null;
    } catch (error) {
      throw new Error(`Failed to get machine: ${error.message}`);
    }
  }

  /**
   * Update machine status
   */
  static async updateStatus(machineId, status) {
    const query = `
      UPDATE tbl_machines 
      SET status = ?, updated_at = NOW()
      WHERE machine_id = ?
    `;
    
    try {
      const [result] = await pool.execute(query, [status, machineId]);
      return result;
    } catch (error) {
      throw new Error(`Failed to update machine status: ${error.message}`);
    }
  }

  /**
   * Update last heartbeat and sync time
   */
  static async updateHeartbeat(machineId) {
    const query = `
      UPDATE tbl_machines 
      SET last_heartbeat = NOW(), last_sync = NOW()
      WHERE machine_id = ?
    `;
    
    try {
      const [result] = await pool.execute(query, [machineId]);
      return result;
    } catch (error) {
      throw new Error(`Failed to update heartbeat: ${error.message}`);
    }
  }

  /**
   * Get active machines
   */
  static async getActiveMachines() {
    const query = `
      SELECT * FROM tbl_machines 
      WHERE status = 'ACTIVE'
      ORDER BY last_heartbeat DESC
    `;
    
    try {
      const [rows] = await pool.execute(query);
      return rows.map(row => ({
        ...row,
        protocols: typeof row.protocols === 'string' ? JSON.parse(row.protocols) : row.protocols
      }));
    } catch (error) {
      throw new Error(`Failed to get active machines: ${error.message}`);
    }
  }

  /**
   * Get machine statistics
   */
  static async getMachineStats(machineId) {
    const query = `
      SELECT 
        machine_id,
        COUNT(*) as total_records,
        SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) as valid_records,
        SUM(CASE WHEN is_valid = FALSE THEN 1 ELSE 0 END) as invalid_records,
        MAX(received_at) as last_data_received
      FROM tbl_raw_data
      WHERE machine_id = ?
      GROUP BY machine_id
    `;
    
    try {
      const [rows] = await pool.execute(query, [machineId]);
      return rows[0] || null;
    } catch (error) {
      throw new Error(`Failed to get machine stats: ${error.message}`);
    }
  }
}

module.exports = MachineModel;
