//
// userRoutes.js
//
// Mounted at /api/v1/users in app.js. All routes require auth.
//

import { Router } from 'express';
import { requireAuth } from '../middleware/authMiddleware.js';
import { getMe, updateOnboarding, getStats } from '../controllers/userController.js';

const router = Router();

router.use(requireAuth);

router.get('/me', getMe);
router.patch('/onboarding', updateOnboarding);
router.get('/me/stats', getStats);

export default router;