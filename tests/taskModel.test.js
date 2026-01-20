const taskModel = require('../src/models/taskModel');

describe('Task Model', () => {
    beforeEach(() => {
        taskModel.clearTasks();
    });

    test('should add a task', () => {
        const task = taskModel.addTask('Test task');
        expect(task.title).toBe('Test task');
        expect(task.completed).toBe(false);
        expect(taskModel.getAllTasks().length).toBe(1);
    });

    test('should toggle a task', () => {
        const task = taskModel.addTask('Test task');
        const toggled = taskModel.toggleTask(task.id);
        expect(toggled.completed).toBe(true);
        const toggledAgain = taskModel.toggleTask(task.id);
        expect(toggledAgain.completed).toBe(false);
    });

    test('should delete a task', () => {
        const task = taskModel.addTask('Test task');
        const deleted = taskModel.deleteTask(task.id);
        expect(deleted.id).toBe(task.id);
        expect(taskModel.getAllTasks().length).toBe(0);
    });

    test('should return null when deleting non-existent task', () => {
        const result = taskModel.deleteTask('non-existent');
        expect(result).toBeNull();
    });
});
