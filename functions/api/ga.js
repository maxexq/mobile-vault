// MV-499: the GameAnalytics signing proxy on Cloudflare Pages (POST /api/ga). The logic lives in api/ga.mjs (shared
// with the Vercel function); the secrets come from the Pages project's variables (Settings > Variables and Secrets,
// Production and Preview): GA_GAME_KEY_PROD, GA_SECRET_PROD, GA_GAME_KEY_TEST, GA_SECRET_TEST.
import { handle } from "../../api/ga.mjs";

export function onRequest(context) {
  return handle(context.request, context.env);
}
