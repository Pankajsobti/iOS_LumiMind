//
// gameResultController.js
//
// Handlers for POST /game-results and GET /game-results.
// Contract locked in API_CONTRACT.md.
//

import GameResult, { GAME_NAMES, CATEGORIES, CATEGORY_TO_SCORE_KEY } from '../models/GameResult.js';
import { applyScoreToCategory, computeNextStreak } from '../services/statsService.js';

function sendError(res, status, message) {
  return res.status(status).json({ error: message });
}

export async function createGameResult(req, res) {
  try {
    const { gameName, category, score, durationSeconds, isFitTest } = req.body ?? {};

    if (
      !gameName ||
      !category ||
      score === undefined ||
      score === null ||
      durationSeconds === undefined ||
      durationSeconds === null
    ) {
      return sendError(
        res,
        400,
        'gameName, category, score, and durationSeconds are required.'
      );
    }
    if (!GAME_NAMES.includes(gameName)) {
      return sendError(res, 400, `gameName must be one of: ${GAME_NAMES.join(', ')}`);
    }
    if (!CATEGORIES.includes(category)) {
      return sendError(res, 400, `category must be one of: ${CATEGORIES.join(', ')}`);
    }
    if (typeof score !== 'number' || typeof durationSeconds !== 'number') {
      return sendError(res, 400, 'score and durationSeconds must be numbers.');
    }

    const user = req.user;

    const gameResult = await GameResult.create({
      userId: user._id,
      gameName,
      category,
      score,
      durationSeconds,
      isFitTest: Boolean(isFitTest ?? false),
    });

    // --- Update the user's categoryScores (see statsService.js for the
    //     locked "best score" aggregation rule and why it's a decision,
    //     not a contract-fixed behavior). ---
    const categoryKey = CATEGORY_TO_SCORE_KEY[category];
    const currentCategoryScore = user.categoryScores[categoryKey] ?? 0;
    user.categoryScores[categoryKey] = applyScoreToCategory(currentCategoryScore, score);

    // --- Update streak + lastPlayedDate (see statsService.js for the
    //     UTC-calendar-day rule). ---
    const now = new Date();
    user.streak = computeNextStreak(user.streak, user.lastPlayedDate, now);
    user.lastPlayedDate = now;

    await user.save();

    return res.status(201).json({
      gameResult,
      updatedUser: user.toJSON(),
    });
  } catch (err) {
    console.error('[gameResults] create error:', err);
    return sendError(res, 500, 'Something went wrong while saving the game result.');
  }
}

export async function getGameResults(req, res) {
  try {
    const { category, limit } = req.query;

    const filter = { userId: req.user._id };

    if (category !== undefined) {
      if (!CATEGORIES.includes(category)) {
        return sendError(res, 400, `category must be one of: ${CATEGORIES.join(', ')}`);
      }
      filter.category = category;
    }

    let query = GameResult.find(filter).sort({ playedAt: -1 });

    if (limit !== undefined) {
      const parsedLimit = Number(limit);
      if (!Number.isInteger(parsedLimit) || parsedLimit <= 0) {
        return sendError(res, 400, 'limit must be a positive integer.');
      }
      query = query.limit(parsedLimit);
    }

    const results = await query.exec();
    return res.status(200).json(results);
  } catch (err) {
    console.error('[gameResults] list error:', err);
    return sendError(res, 500, 'Something went wrong while fetching game results.');
  }
}