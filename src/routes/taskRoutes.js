const express = require('express');
const taskController = require('../controllers/taskController');

const router = express.Router();

router.get('/', taskController.showTasks);
router.post('/tasks', taskController.createTask);
router.post('/tasks/:id/toggle', taskController.toggleTaskStatus);
router.post('/tasks/:id/delete', taskController.removeTask);

module.exports = router;
