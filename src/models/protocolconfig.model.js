const pool = require('../config/database');

class ProtocolConfigModel {
  /**
   * Create or update protocol configuration for a machine
   */
  static async createOrUpdateConfig(machineId, config) {
    const query = `
      INSERT INTO tbl_protocol_config (
        machine_id, rs232_enabled, rs232_port, rs232_baudrate, 
        rs232_databits, rs232_stopbits, rs232_parity, rs232_handshake,
        lan_enabled, lan_host, lan_port, lan_timeout_ms, lan_retry_count,
        file_enabled, file_watch_path, file_pattern, file_encoding,
        checksum_enabled, checksum_type, terminator_char, max_payload_size,
        sync_interval_ms, batch_size, cache_flush_on_sync
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        rs232_enabled = VALUES(rs232_enabled),
        rs232_port = VALUES(rs232_port),
        rs232_baudrate = VALUES(rs232_baudrate),
        lan_enabled = VALUES(lan_enabled),
        lan_host = VALUES(lan_host),
        lan_port = VALUES(lan_port),
        file_enabled = VALUES(file_enabled),
        file_watch_path = VALUES(file_watch_path),
        sync_interval_ms = VALUES(sync_interval_ms),
        batch_size = VALUES(batch_size),
        updated_at = NOW()
    `;
    
    try {
      const [result] = await pool.execute(query, [
        machineId,
        config.rs232?.enabled || false,
        config.rs232?.port || 'COM1',
        config.rs232?.baudrate || 9600,
        config.rs232?.databits || 8,
        config.rs232?.stopbits || 1,
        config.rs232?.parity || 'NONE',
        config.rs232?.handshake || 'NONE',
        config.lan?.enabled || false,
        config.lan?.host || 'localhost',
        config.lan?.port || 502,
        config.lan?.timeout_ms || 5000,
        config.lan?.retry_count || 3,
        config.file?.enabled || false,
        config.file?.watch_path || null,
        config.file?.pattern || '*.csv',
        config.file?.encoding || 'UTF-8',
        config.checksum?.enabled !== false,
        config.checksum?.type || 'CUSTOM',
        config.checksum?.terminator_char || '\r\n',
        config.checksum?.max_payload_size || 65536,
        config.sync?.interval_ms || 30000,
        config.sync?.batch_size || 500,
        config.sync?.cache_flush_on_sync !== false
      ]);
      return result;
    } catch (error) {
      throw new Error(`Failed to create/update protocol config: ${error.message}`, { cause: error });
    }
  }

  /**
   * Get configuration for a machine
   */
  static async getConfigByMachineId(machineId) {
    const query = `
      SELECT * FROM tbl_protocol_config WHERE machine_id = ?
    `;
    
    try {
      const [rows] = await pool.execute(query, [machineId]);
      if (rows.length > 0) {
        return this._formatConfig(rows[0]);
      }
      return null;
    } catch (error) {
      throw new Error(`Failed to get protocol config: ${error.message}`, { cause: error });
    }
  }

  /**
   * Get all configurations
   */
  static async getAllConfigs() {
    const query = `SELECT * FROM tbl_protocol_config`;
    
    try {
      const [rows] = await pool.execute(query);
      return rows.map(row => this._formatConfig(row));
    } catch (error) {
      throw new Error(`Failed to get all configs: ${error.message}`, { cause: error });
    }
  }

  /**
   * Format configuration from database format
   */
  static _formatConfig(dbConfig) {
    return {
      machine_id: dbConfig.machine_id,
      rs232: {
        enabled: dbConfig.rs232_enabled,
        port: dbConfig.rs232_port,
        baudrate: dbConfig.rs232_baudrate,
        databits: dbConfig.rs232_databits,
        stopbits: dbConfig.rs232_stopbits,
        parity: dbConfig.rs232_parity,
        handshake: dbConfig.rs232_handshake
      },
      lan: {
        enabled: dbConfig.lan_enabled,
        host: dbConfig.lan_host,
        port: dbConfig.lan_port,
        timeout_ms: dbConfig.lan_timeout_ms,
        retry_count: dbConfig.lan_retry_count
      },
      file: {
        enabled: dbConfig.file_enabled,
        watch_path: dbConfig.file_watch_path,
        pattern: dbConfig.file_pattern,
        encoding: dbConfig.file_encoding
      },
      checksum: {
        enabled: dbConfig.checksum_enabled,
        type: dbConfig.checksum_type,
        terminator_char: dbConfig.terminator_char,
        max_payload_size: dbConfig.max_payload_size
      },
      sync: {
        interval_ms: dbConfig.sync_interval_ms,
        batch_size: dbConfig.batch_size,
        cache_flush_on_sync: dbConfig.cache_flush_on_sync
      }
    };
  }
}

module.exports = ProtocolConfigModel;
