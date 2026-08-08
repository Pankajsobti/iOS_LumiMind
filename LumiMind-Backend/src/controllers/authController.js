//
// authController.js
//
// Handlers for POST /auth/signup and POST /auth/login.
// Contract locked in API_CONTRACT.md — body/response shapes must match
// exactly, error shape is always { error: "<message>" }.
//

import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import { env } from '../config/env.js';

const SALT_ROUNDS = 10;

function signToken(userId) {
  return jwt.sign({ sub: userId }, env.JWT_SECRET, {
    expiresIn: env.JWT_EXPIRES_IN,
  });
}

function sendError(res, status, message) {
  return res.status(status).json({ error: message });
}

export async function signup(req, res) {
  try {
    const { email, password } = req.body ?? {};

    if (!email || !password) {
      return sendError(res, 400, 'Email and password are required.');
    }

    const normalizedEmail = String(email).toLowerCase().trim();

    const existing = await User.findOne({ email: normalizedEmail });
    if (existing) {
      return sendError(res, 409, 'An account with this email already exists.');
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    const user = await User.create({ email: normalizedEmail, passwordHash });

    const token = signToken(user._id.toString());

    // user.toJSON() strips passwordHash via the schema transform.
    return res.status(201).json({ token, user: user.toJSON() });
  } catch (err) {
    console.error('[auth] signup error:', err);
    return sendError(res, 500, 'Something went wrong during signup.');
  }
}

export async function login(req, res) {
  try {
    const { email, password } = req.body ?? {};

    if (!email || !password) {
      return sendError(res, 400, 'Email and password are required.');
    }

    const normalizedEmail = String(email).toLowerCase().trim();

    // passwordHash has select: false on the schema, so it must be
    // explicitly requested here for comparison.
    const user = await User.findOne({ email: normalizedEmail }).select('+passwordHash');

    // Same message whether the email doesn't exist or the password is
    // wrong, so we never leak which one failed.
    const invalidCredentialsMessage = 'Invalid email or password.';

    if (!user) {
      return sendError(res, 401, invalidCredentialsMessage);
    }

    const passwordMatches = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatches) {
      return sendError(res, 401, invalidCredentialsMessage);
    }

    const token = signToken(user._id.toString());

    return res.status(200).json({ token, user: user.toJSON() });
  } catch (err) {
    console.error('[auth] login error:', err);
    return sendError(res, 500, 'Something went wrong during login.');
  }
}