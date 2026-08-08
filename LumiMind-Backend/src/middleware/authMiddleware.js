//
// authMiddleware.js
//
// Protects routes by requiring a valid `Authorization: Bearer <JWT>`
// header. On success, attaches the full user document (minus
// passwordHash) to `req.user` for downstream handlers.
//
// Usage in a future route file:
//   import { requireAuth } from '../middleware/authMiddleware.js';
//   router.get('/me', requireAuth, getMe);
//

import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import { env } from '../config/env.js';

export async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const [scheme, token] = authHeader.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Missing or malformed Authorization header.' });
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET);

    // passwordHash is select: false by default, so it's never fetched here.
    const user = await User.findById(payload.sub);

    if (!user) {
      return res.status(401).json({ error: 'User for this token no longer exists.' });
    }

    req.user = user;
    next();
  } catch (err) {
    // Covers expired tokens, malformed tokens, and bad signatures alike.
    return res.status(401).json({ error: 'Invalid or expired token.' });
  }
}