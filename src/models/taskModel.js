const { randomUUID } = require('crypto');

const tasks = [];

const getAllTasks = () => tasks;

const addTask = (title) => {
  const task = {
    id: randomUUID(),
    title: title.trim(),
    completed: false,
  };
  tasks.unshift(task);
  return task;
};

const toggleTask = (id) => {
  const task = tasks.find((item) => item.id === id);
  if (task) {
    task.completed = !task.completed;
  }
  return task;
};

const deleteTask = (id) => {
  const index = tasks.findIndex((item) => item.id === id);
  if (index !== -1) {
    return tasks.splice(index, 1)[0];
  }
  return null;
};

module.exports = {
  getAllTasks,
  addTask,
  toggleTask,
  deleteTask,
};
