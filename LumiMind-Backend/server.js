//
// server.js
//
// Entry point. Run with `node server.js`.
//

import { env } from './src/config/env.js';
import { connectDB } from './src/config/db.js';
import app from './app.js';



async function start() {
  await connectDB();
  app.listen(env.PORT, () => {
    console.log(`[server] LumiMind API listening on port ${env.PORT}`);
  });
}

start();