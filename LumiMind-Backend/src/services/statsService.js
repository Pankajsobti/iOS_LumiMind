//
// statsService.js
//
// Streak calculation + categoryScores update logic, kept separate from
// gameResultController.js so it can be unit-tested without spinning up
// Express or Mongo.
//

// ---------------------------------------------------------------------
// categoryScores aggregation rule — DECISION, NOT IN THE CONTRACT
// ---------------------------------------------------------------------
// API_CONTRACT.md does not specify how a new game score should combine
// with the existing per-category score. This build defaults to:
//
//   "BEST SCORE PER CATEGORY" — categoryScores[category] only updates
//   when the new score is strictly greater than the current stored
//   value. A worse score never lowers the category score.
//
// This is a product decision, not a locked spec. If the intended
// behavior is actually "running average" or "cumulative sum", this is
// the single function to change — nothing else references the rule.
export function applyScoreToCategory(currentScore, newScore) {
  return Math.max(currentScore, newScore);
}

// ---------------------------------------------------------------------
// Streak calculation
// ---------------------------------------------------------------------
// Day comparisons use UTC calendar days, not rolling 24h windows — so
// "yesterday" means the previous UTC calendar date, regardless of what
// time of day either play happened. This is a reasonable default given
// the contract doesn't specify timezone handling; switching to
// local-timezone day boundaries would require the client to send its
// timezone offset with each request.

function startOfUTCDay(date) {
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function daysBetweenUTC(earlier, later) {
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.round((startOfUTCDay(later) - startOfUTCDay(earlier)) / msPerDay);
}

/**
 * Computes the next streak value given the current streak, the user's
 * last played date, and "now".
 *
 *   - No lastPlayedDate (first-ever play)      -> 1
 *   - Same UTC calendar day as lastPlayedDate   -> unchanged
 *   - Exactly one UTC calendar day later        -> currentStreak + 1
 *   - Gap > 1 day (or any other case)           -> reset to 1
 */
export function computeNextStreak(currentStreak, lastPlayedDate, now = new Date()) {
  if (!lastPlayedDate) {
    return 1;
  }

  const gap = daysBetweenUTC(new Date(lastPlayedDate), now);

  if (gap === 0) {
    return currentStreak;
  }
  if (gap === 1) {
    return currentStreak + 1;
  }
  // Covers gap > 1 and any negative/clock-skew edge case.
  return 1;
}