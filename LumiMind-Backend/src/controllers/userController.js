//
// userController.js
//
// Handlers for GET /users/me, PATCH /users/onboarding, and
// GET /users/me/stats. Contract locked in API_CONTRACT.md.
//

function sendError(res, status, message) {
  return res.status(status).json({ error: message });
}

export async function getMe(req, res) {
  // req.user is attached by requireAuth and already excludes passwordHash.
  return res.status(200).json(req.user.toJSON());
}

export async function updateOnboarding(req, res) {
  try {
    const { goals, difficultyLevel } = req.body ?? {};

    const goalsValid = Array.isArray(goals) && goals.length > 0 && goals.every((g) => typeof g === 'string');
    const difficultyValid = typeof difficultyLevel === 'string' && difficultyLevel.trim().length > 0;

    if (!goalsValid || !difficultyValid) {
      return sendError(
        res,
        400,
        'goals (non-empty array of strings) and difficultyLevel (non-empty string) are required.'
      );
    }

    req.user.goals = goals;
    req.user.difficultyLevel = difficultyLevel;
    await req.user.save();

    return res.status(200).json(req.user.toJSON());
  } catch (err) {
    console.error('[users] onboarding error:', err);
    return sendError(res, 500, 'Something went wrong while updating onboarding.');
  }
}

export async function getStats(req, res) {
  const { categoryScores, streak, lastPlayedDate } = req.user;
  return res.status(200).json({ categoryScores, streak, lastPlayedDate });
}