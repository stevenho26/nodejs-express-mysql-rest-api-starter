const { sequelize } = require('../../src/config/database');
const userHelper = require('../../src/helpers/user.helper');

describe('user.helper (test DB - sqlite in-memory)', () => {
  beforeAll(async () => {
    await sequelize.sync({ force: true });
  });

  beforeEach(async () => {
    await sequelize.sync({ force: true });
  });

  afterAll(async () => {
    await sequelize.close();
  });

  it('creates and finds user by email', async () => {
    const created = await userHelper.createUser({
      name: 'DB User',
      email: 'dbuser@example.com',
      password: '123456',
      role: 'user',
    });

    const found = await userHelper.findUserByEmail('dbuser@example.com');

    expect(created.id).toBeDefined();
    expect(found).toBeTruthy();
    expect(found.email).toBe('dbuser@example.com');
    expect(found.password).not.toBe('123456');
  });

  it('updates and deletes user', async () => {
    const created = await userHelper.createUser({
      name: 'Before Update',
      email: 'before@example.com',
      password: '123456',
      role: 'user',
    });

    const updated = await userHelper.updateUser(created.id, {
      name: 'After Update',
      password: '654321',
    });

    expect(updated.name).toBe('After Update');
    expect(updated.password).not.toBe('654321');

    const deleted = await userHelper.deleteUser(created.id);
    const check = await userHelper.findUserById(created.id);

    expect(deleted).toBeTruthy();
    expect(check).toBeNull();
  });
});
