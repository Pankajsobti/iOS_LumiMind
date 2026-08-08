//
// env.js
//
// Centralized access to environment variables. Import `env` instead of
// reading `process.env` directly elsewhere in the codebase.
//

import dotenv from 'dotenv';

dotenv.config();

function required(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const env = {
  PORT: process.env.PORT || 5000,
  MONGO_URI: required('MONGO_URI'),
  JWT_SECRET: required('JWT_SECRET'),
  // Default choice, not a locked contract value — change via .env if needed.
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '30d',
};