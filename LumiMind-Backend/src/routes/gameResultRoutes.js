//
// gameResultRoutes.js
//
// Mounted at /api/v1/game-results in app.js. All routes require auth.
//

import { Router } from 'express';
import { requireAuth } from '../middleware/authMiddleware.js';
import { createGameResult, getGameResults } from '../controllers/gameResultController.js';

const router = Router();

router.use(requireAuth);

router.post('/', createGameResult);
router.get('/', getGameResults);

export default router;