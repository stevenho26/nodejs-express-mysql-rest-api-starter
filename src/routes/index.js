const express = require('express');
const mdataRoutes = require('./mdata.routes');

const router = express.Router();

router.use('/mdata', mdataRoutes);

module.exports = router;
