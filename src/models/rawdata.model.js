const pool = require('../config/database');

class RawDataModel {
  /**
   * Insert raw data received from middleware
   */
  static async insertRawData(machineId, messageId, protocol, rawPayload, dataHash, batchId, partitionKey) {
    const query = `
      INSERT INTO tbl_raw_data (
        machine_id, message_id, protocol, raw_payload, raw_payload_hash, 
        batch_id, partition_key, is_valid, received_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
    `;
    
    try {
      const [result] = await pool.execute(query, [
        machineId, messageId, protocol, rawPayload, dataHash, 
        batchId, partitionKey, true
      ]);
      return result;
    } catch (error) {
      throw new Error(`Failed to insert raw data: ${error.message}`);
    }
  }

  /**
   * Mark data as invalid with error message
   */
  static async markAsInvalid(messageId, errorMessage, errorCode) {
    const query = `
      UPDATE tbl_raw_data 
      SET is_valid = FALSE, 
          validation_error = ?, 
          error_code = ?
      WHERE message_id = ?
    `;
    
    try {
      const [result] = await pool.execute(query, [errorMessage, errorCode, messageId]);
      return result;
    } catch (error) {
      throw new Error(`Failed to mark data as invalid: ${error.message}`);
    }
  }

  /**
   * Get raw data by ID
   */
  static async getRawDataById(id) {
    const query = `
      SELECT * FROM tbl_raw_data WHERE id = ?
    `;
    
    try {
      const [rows] = await pool.execute(query, [id]);
      return rows[0] || null;
    } catch (error) {
      throw new Error(`Failed to get raw data: ${error.message}`);
    }
  }

  /**
   * Get raw data by message ID
   */
  static async getRawDataByMessageId(messageId) {
    const query = `
      SELECT * FROM tbl_raw_data WHERE message_id = ?
    `;
    
    try {
      const [rows] = await pool.execute(query, [messageId]);
      return rows[0] || null;
    } catch (error) {
      throw new Error(`Failed to get raw data: ${error.message}`);
    }
  }

  /**
   * Get recent raw data for a machine
   */
  static async getRecentDataForMachine(machineId, limit = 100, offset = 0) {
    const query = `
      SELECT * FROM tbl_raw_data 
      WHERE machine_id = ?
      ORDER BY received_at DESC
      LIMIT ? OFFSET ?
    `;
    
    try {
      const [rows] = await pool.execute(query, [machineId, limit, offset]);
      return rows;
    } catch (error) {
      throw new Error(`Failed to get recent data: ${error.message}`);
    }
  }

  /**
   * Get data quality report
   */
  static async getDataQualityReport(machineId) {
    const query = `
      SELECT 
        machine_id,
        COUNT(*) AS total_records,
        SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) AS valid_records,
        SUM(CASE WHEN is_valid = FALSE THEN 1 ELSE 0 END) AS invalid_records,
        ROUND(100.0 * SUM(CASE WHEN is_valid = TRUE THEN 1 ELSE 0 END) / COUNT(*), 2) AS valid_percentage,
        MIN(received_at) AS first_record,
        MAX(received_at) AS last_record
      FROM tbl_raw_data
      WHERE machine_id = ? AND received_at > DATE_SUB(NOW(), INTERVAL 1 DAY)
      GROUP BY machine_id
    `;
    
    try {
      const [rows] = await pool.execute(query, [machineId]);
      return rows[0] || null;
    } catch (error) {
      throw new Error(`Failed to get data quality report: ${error.message}`);
    }
  }
}

module.exports = RawDataModel;
