const express = require('express');
const router = express.Router();
const MDataController = require('../controllers/mdata.controller');
const {
  validateRawData,
  validateMachine,
  validateProtocolConfig,
  validateHeartbeat,
  validateMachineIdParam,
  handleValidationErrors
} = require('../validators/mdata.validator');

/**
 * @openapi
 * /api/mdata/raw-data:
 *   post:
 *     summary: Receive raw data from middleware
 *     tags: [Raw Data]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - machine_id
 *               - message_id
 *               - protocol
 *               - raw_payload
 *             properties:
 *               machine_id:
 *                 type: string
 *               message_id:
 *                 type: string
 *               protocol:
 *                 type: string
 *                 enum: [RS232, LAN, FILE, USB]
 *               raw_payload:
 *                 type: string
 *               batch_id:
 *                 type: string
 *               partition_key:
 *                 type: string
 *     responses:
 *       201:
 *         description: Raw data received successfully
 *       400:
 *         description: Validation failed
 *       500:
 *         description: Server error
 */
router.post(
  '/raw-data',
  validateRawData,
  handleValidationErrors,
  MDataController.receiveRawData
);

/**
 * @openapi
 * /api/mdata/machines:
 *   post:
 *     summary: Create or update machine
 *     tags: [Machines]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - machine_id
 *               - name
 *               - device_type
 *             properties:
 *               machine_id:
 *                 type: string
 *               name:
 *                 type: string
 *               location:
 *                 type: string
 *               device_type:
 *                 type: string
 *               description:
 *                 type: string
 *               protocols:
 *                 type: object
 *     responses:
 *       201:
 *         description: Machine created/updated
 *       500:
 *         description: Server error
 *   get:
 *     summary: Get all machines
 *     tags: [Machines]
 *     responses:
 *       200:
 *         description: List of machines
 *       500:
 *         description: Server error
 */
router.post(
  '/machines',
  validateMachine,
  handleValidationErrors,
  MDataController.createOrUpdateMachine
);

router.get(
  '/machines',
  MDataController.getAllMachines
);

/**
 * @openapi
 * /api/mdata/machines/{machineId}:
 *   get:
 *     summary: Get machine details
 *     tags: [Machines]
 *     parameters:
 *       - in: path
 *         name: machineId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Machine details
 *       404:
 *         description: Machine not found
 *       500:
 *         description: Server error
 */
router.get(
  '/machines/:machineId',
  validateMachineIdParam,
  handleValidationErrors,
  MDataController.getMachineDetails
);

/**
 * @openapi
 * /api/mdata/config/{machineId}:
 *   get:
 *     summary: Get machine configuration
 *     tags: [Configuration]
 *     parameters:
 *       - in: path
 *         name: machineId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Machine configuration
 *       404:
 *         description: Machine not found
 *       500:
 *         description: Server error
 *   put:
 *     summary: Update machine configuration
 *     tags: [Configuration]
 *     parameters:
 *       - in: path
 *         name: machineId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *     responses:
 *       200:
 *         description: Configuration updated
 *       404:
 *         description: Machine not found
 *       500:
 *         description: Server error
 */
router.get(
  '/config/:machineId',
  validateMachineIdParam,
  handleValidationErrors,
  MDataController.getMachineConfig
);

router.put(
  '/config/:machineId',
  validateMachineIdParam,
  validateProtocolConfig,
  handleValidationErrors,
  MDataController.updateMachineConfig
);

/**
 * @openapi
 * /api/mdata/protocol-config/{machineId}:
 *   get:
 *     summary: Get protocol configuration
 *     tags: [Protocol Config]
 *     description: Get protocol configuration from tbl_protocol_config
 *     parameters:
 *       - in: path
 *         name: machineId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Protocol configuration
 *       404:
 *         description: Protocol config not found
 *       500:
 *         description: Server error
 */
router.get(
  '/protocol-config/:machineId',
  validateMachineIdParam,
  handleValidationErrors,
  MDataController.getProtocolConfig
);

/**
 * @openapi
 * /api/mdata/heartbeat:
 *   post:
 *     summary: Record heartbeat from middleware
 *     tags: [Heartbeat]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - machine_id
 *             properties:
 *               machine_id:
 *                 type: string
 *               middleware_version:
 *                 type: string
 *               status:
 *                 type: string
 *               pending_count:
 *                 type: integer
 *               cache_size_bytes:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Heartbeat recorded
 *       500:
 *         description: Server error
 */
router.post(
  '/heartbeat',
  validateHeartbeat,
  handleValidationErrors,
  MDataController.recordHeartbeat
);

/**
 * @openapi
 * /api/mdata/health:
 *   get:
 *     summary: Get API health status
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: API is healthy
 *       503:
 *         description: API is unhealthy
 */
router.get(
  '/health',
  MDataController.getHealth
);

module.exports = router;
