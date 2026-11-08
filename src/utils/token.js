const jwt = require('jsonwebtoken');
const { env } = require('../config/env');

const signToken = (userId) => jwt.sign({ sub: String(userId) }, env.jwtSecret, { algorithm: 'HS256', expiresIn: env.jwtExpiresIn });
const verifyToken = (token) => jwt.verify(token, env.jwtSecret, { algorithms: ['HS256'] }) // pin the algorithm;

module.exports = { signToken, verifyToken };
