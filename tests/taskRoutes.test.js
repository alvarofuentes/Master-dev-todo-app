const request = require('supertest');
const express = require('express');
const path = require('path');
const bodyParser = require('body-parser');
const taskRoutes = require('../src/routes/taskRoutes');
const taskModel = require('../src/models/taskModel');

const app = express();
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '../views'));
app.use(bodyParser.urlencoded({ extended: false }));
app.use('/', taskRoutes);

describe('Task Routes', () => {
    beforeEach(() => {
        taskModel.clearTasks();
    });

    test('GET / should render index', async () => {
        const res = await request(app).get('/');
        expect(res.statusCode).toBe(200);
        expect(res.text).toContain('Tus Pendientes');
    });

    test('POST /tasks should create a task', async () => {
        const res = await request(app)
            .post('/tasks')
            .type('form')
            .send({ title: 'New Integration Test' });
        expect(res.statusCode).toBe(302);
        expect(taskModel.getAllTasks()[0].title).toBe('New Integration Test');
    });

    test('POST /tasks/:id/toggle should toggle status', async () => {
        const task = taskModel.addTask('Toggle Me');
        const res = await request(app).post(`/tasks/${task.id}/toggle`);
        expect(res.statusCode).toBe(302);
        expect(taskModel.getAllTasks()[0].completed).toBe(true);
    });

    test('POST /tasks/:id/delete should remove task', async () => {
        const task = taskModel.addTask('Delete Me');
        const res = await request(app).post(`/tasks/${task.id}/delete`);
        expect(res.statusCode).toBe(302);
        expect(taskModel.getAllTasks().length).toBe(0);
    });
});
