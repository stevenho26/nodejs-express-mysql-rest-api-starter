const request = require('supertest');
const app = require('../src/app');

describe('Application smoke tests', () => {
  it('serves API docs endpoint', async () => {
    const response = await request(app).get('/api-docs');

    expect(response.statusCode).toBeLessThan(400);
  });
});
