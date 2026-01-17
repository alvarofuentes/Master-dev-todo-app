const taskModel = require('../models/taskModel');

const showTasks = (req, res) => {
  res.render('index', {
    tasks: taskModel.getAllTasks(),
  });
};

const createTask = (req, res) => {
  const { title } = req.body;
  if (title && title.trim()) {
    taskModel.addTask(title);
  }
  res.redirect('/');
};

const toggleTaskStatus = (req, res) => {
  taskModel.toggleTask(req.params.id);
  res.redirect('/');
};

const removeTask = (req, res) => {
  taskModel.deleteTask(req.params.id);
  res.redirect('/');
};

module.exports = {
  showTasks,
  createTask,
  toggleTaskStatus,
  removeTask,
};
