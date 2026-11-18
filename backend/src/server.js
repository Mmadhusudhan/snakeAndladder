import { createApp } from './app.js';
import { realDeps } from './config/firebase.js';

const PORT = process.env.PORT || 3000;
const app = createApp(realDeps());

const server = app.listen(PORT, () => {
  console.log(`🐍🎲 Snakes & Ladders API listening on http://localhost:${PORT}`);
});

function shutdown() {
  server.close(() => process.exit(0));
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
