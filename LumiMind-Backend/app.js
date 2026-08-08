//
// app.js
//
// Express app configuration. Only auth routes are mounted for now —
// game-results and users routes come in later build prompts.
//

import express from 'express';
import cors from 'cors';
import authRoutes from './src/routes/authRoutes.js';

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api/v1/auth', authRoutes);

// Catch-all for unmatched routes.
app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found.' });
});

export default app;