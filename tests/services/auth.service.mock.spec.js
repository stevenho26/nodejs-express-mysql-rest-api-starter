jest.mock('../../src/helpers/user.helper', () => ({
  findUserByEmail: jest.fn(),
  createUser: jest.fn(),
}));

jest.mock('bcryptjs', () => ({
  compare: jest.fn(),
}));

jest.mock('jsonwebtoken', () => ({
  sign: jest.fn(),
}));

const userHelper = require('../../src/helpers/user.helper');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const authService = require('../../src/services/auth.service');
const ApiError = require('../../src/utils/ApiError');

describe('auth.service (mock DB)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('register should throw when email already exists', async () => {
    userHelper.findUserByEmail.mockResolvedValue({ id: 99 });

    await expect(
      authService.register({ name: 'A', email: 'a@test.com', password: '123456' })
    ).rejects.toBeInstanceOf(ApiError);
  });

  it('login should return token and user response', async () => {
    userHelper.findUserByEmail.mockResolvedValue({
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
      password: 'hashed',
    });
    bcrypt.compare.mockResolvedValue(true);
    jwt.sign.mockReturnValue('mocked.jwt.token');

    const result = await authService.login('test@example.com', '123456');

    expect(result.token).toBe('mocked.jwt.token');
    expect(result.user).toMatchObject({
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
    });
    expect(jwt.sign).toHaveBeenCalledTimes(1);
  });

  it('login should throw for wrong password', async () => {
    userHelper.findUserByEmail.mockResolvedValue({
      id: 1,
      name: 'Test User',
      email: 'test@example.com',
      password: 'hashed',
    });
    bcrypt.compare.mockResolvedValue(false);

    await expect(authService.login('test@example.com', 'wrong')).rejects.toBeInstanceOf(ApiError);
  });
});
