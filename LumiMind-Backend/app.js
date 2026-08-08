//
// app.js
//
// Express app configuration.
//

import express from 'express';
import cors from 'cors';
import authRoutes from './src/routes/authRoutes.js';
import gameResultRoutes from './src/routes/gameResultRoutes.js';
import userRoutes from './src/routes/userRoutes.js';

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/game-results', gameResultRoutes);
app.use('/api/v1/users', userRoutes);

// Catch-all for unmatched routes.
app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found.' });
});

export default app;