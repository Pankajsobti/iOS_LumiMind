//
// authRoutes.js
//
// Mounted at /api/v1/auth in app.js.
//

import { Router } from 'express';
import { signup, login } from '../controllers/authController.js';

const router = Router();

router.post('/signup', signup);
router.post('/login', login);

export default router;