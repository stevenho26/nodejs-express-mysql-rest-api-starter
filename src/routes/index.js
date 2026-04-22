const express = require('express');
const authRoutes = require('./auth.routes');
const userRoutes = require('./user.routes');
const blogRoutes = require('./blog.routes');
const mdataRoutes = require('./mdata.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/users', userRoutes);
router.use('/blogs', blogRoutes);
router.use('/mdata', mdataRoutes);

module.exports = router;
