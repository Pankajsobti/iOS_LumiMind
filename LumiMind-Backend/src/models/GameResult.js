//
// GameResult.js
//
// Mongoose schema matching LumiMind/Models/GameResult.swift field-for-field.
// See API_CONTRACT.md for the canonical JSON shape returned to clients.
//
// Converted to ES Modules in Build Prompt #3 for consistency with the
// rest of the backend (was CommonJS in Build Prompt #2).
//

import mongoose from 'mongoose';

// Locked list — mirrors GameName.swift. Do not add/rename without
// updating GameResult.swift and API_CONTRACT.md.
export const GAME_NAMES = [
  'Memory Matrix',
  'Speed Match',
  'Lost in Migration',
  'Brain Shift',
  'Pirate Passage',
  'Splitting Seeds',
];

// Locked list — mirrors GameCategory.rawValue in DesignSystem.swift.
// Do not add/rename without updating DesignSystem.swift and API_CONTRACT.md.
export const CATEGORIES = [
  'Speed',
  'Memory',
  'Attention',
  'Flexibility',
  'Problem Solving',
  'Math',
];

// Locked mapping from display category name -> categoryScores camelCase
// key. Mirrors GameCategory.categoryScoresKey in GameResult.swift exactly
// (see API_CONTRACT.md's canonical category table). This is the ONLY
// place this mapping is defined on the backend — do not re-derive it
// in controllers or services.
export const CATEGORY_TO_SCORE_KEY = {
  Speed: 'speed',
  Memory: 'memory',
  Attention: 'attention',
  Flexibility: 'flexibility',
  'Problem Solving': 'problemSolving',
  Math: 'math',
};

const gameResultSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  gameName: {
    type: String,
    required: true,
    enum: GAME_NAMES,
  },
  category: {
    type: String,
    required: true,
    enum: CATEGORIES,
  },
  score: {
    type: Number,
    required: true,
  },
  durationSeconds: {
    type: Number,
    required: true,
  },
  isFitTest: {
    type: Boolean,
    default: false,
  },
  playedAt: {
    type: Date,
    default: Date.now,
  },
});

const GameResult = mongoose.model('GameResult', gameResultSchema);

export default GameResult;