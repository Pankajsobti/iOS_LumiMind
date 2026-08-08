//
// User.js
//
// Mongoose schema matching LumiMind/Models/User.swift field-for-field.
// See API_CONTRACT.md for the canonical JSON shape returned to clients.
//
// NOTE: `passwordHash` is never sent to the client — it is excluded
// from JSON output via `select: false` and must be manually .select()'d
// when needed (e.g. during login password comparison).
//
// Converted to ES Modules in Build Prompt #3 for consistency with the
// rest of the backend (was CommonJS in Build Prompt #2).
//

import mongoose from 'mongoose';

// Locked to match DesignSystem.swift's GameCategory + GameResult.swift's
// `categoryScoresKey` mapping exactly. Do not rename these keys without
// updating DesignSystem.swift, GameResult.swift, and API_CONTRACT.md.
const categoryScoresSchema = new mongoose.Schema(
  {
    speed: { type: Number, default: 0 },
    memory: { type: Number, default: 0 },
    attention: { type: Number, default: 0 },
    flexibility: { type: Number, default: 0 },
    problemSolving: { type: Number, default: 0 },
    math: { type: Number, default: 0 },
  },
  { _id: false }
);

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    passwordHash: {
      type: String,
      required: true,
      select: false, // never returned by default queries or toJSON
    },

    // Undefined/absent until PATCH /users/onboarding is called.
    goals: {
      type: [String],
      default: undefined,
    },
    difficultyLevel: {
      type: String,
      default: undefined,
    },

    categoryScores: {
      type: categoryScoresSchema,
      default: () => ({}),
    },

    streak: {
      type: Number,
      default: 0,
    },
    lastPlayedDate: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true, // adds createdAt, updatedAt automatically
    toJSON: {
      transform: (_doc, ret) => {
        delete ret.passwordHash;
        delete ret.__v;
        return ret;
      },
    },
  }
);

const User = mongoose.model('User', userSchema);

export default User;