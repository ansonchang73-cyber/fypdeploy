// api/synchro-ai.js
//
// Vercel Serverless Function — the backend brain for the "Synchro AI"
// top-bar assistant in the SynchroM Flutter web app.
//
// Drop this file in an /api folder at the project ROOT (same level as
// vercel.json, next to vercel-build.sh). Vercel auto-detects anything
// under /api as a Node.js Serverless Function — no extra config needed,
// and it deploys alongside the static Flutter web build, not instead of
// it. The existing catch-all rewrite in vercel.json won't shadow it:
// Vercel always gives the filesystem (including /api functions)
// precedence over rewrites.
//
// REQUIRED SETUP (Vercel dashboard → Project Settings → Environment
// Variables):
//   ANTHROPIC_API_KEY          your Anthropic API key. Required.
//
// OPTIONAL:
//   SYNCHRO_AI_SHARED_SECRET   any random string. If set, the caller must
//                              send it back as the `x-synchro-token`
//                              header, or the request is rejected. Without
//                              this, anyone who finds the URL can call it
//                              and spend your Anthropic credits — worth
//                              setting once you're past local testing.
//   SYNCHRO_AI_ALLOWED_ORIGIN  lock CORS to your real domain instead of
//                              the "*" default, e.g.
//                              "https://your-app.vercel.app".

const ANTHROPIC_VERSION = "2023-06-01";
// Fast + cheap, which fits short intent-parsing replies. Swap to
// 'claude-sonnet-5' if you want sturdier handling of vaguer phrasing
// like "remind me before dinner".
const MODEL = "claude-haiku-4-5-20251001";

const SYSTEM_PROMPT = `You are Synchro AI, the persistent top-bar assistant embedded in SynchroM, a synchronized medication management app. Behave like a quick-access embedded banking-app assistant: fast, concise, no filler.

You do two things only:

1. APP HELP — if the user asks how SynchroM works, how to navigate it, or about their existing schedule, answer briefly and helpfully.

2. REMINDERS — if the user asks you to remind them to take a medication, log a dose, or set an alert, confirm it in one short sentence and describe it as structured data.

Rules:
- Never give medical advice: no dosing recommendations, drug interactions, or clinical guidance. If asked, say you can't advise on that and suggest they check with their doctor, pharmacist, or caregiver — then stop there.
- Only ever schedule a reminder for what the user explicitly tells you (their own stated medication, dose, and time). Never invent or suggest a dosage or time yourself.
- Keep "reply" under 20 words.
- Respond with ONLY a single JSON object — no markdown fences, no commentary before or after — matching exactly one of these two shapes:

{"reply": "<short text for the top bar>", "action": null}

{"reply": "<short confirmation>", "action": {"intent": "schedule_popup", "medication_name": "<name>", "dosage": "<amount if stated, else empty string>", "trigger_time": "<time as the user stated it, e.g. '8:00 AM' or 'in 2 hours'>"}}

If the medication name or time is missing or unclear, use the first shape (action: null) and ask one short clarifying question in "reply" instead of guessing.`;

function setCors(res) {
  res.setHeader(
    "Access-Control-Allow-Origin",
    process.env.SYNCHRO_AI_ALLOWED_ORIGIN || "*"
  );
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, x-synchro-token");
}

module.exports = async (req, res) => {
  setCors(res);

  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Use POST." });
  }

  const expectedSecret = process.env.SYNCHRO_AI_SHARED_SECRET;
  if (expectedSecret && req.headers["x-synchro-token"] !== expectedSecret) {
    return res.status(401).json({ error: "Unauthorized." });
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY is not set.");
    return res.status(500).json({ error: "Server is not configured." });
  }

  const { message, history, patientContext } = req.body || {};

  if (typeof message !== "string" || !message.trim()) {
    return res.status(400).json({ error: '"message" (string) is required.' });
  }
  if (message.length > 1000) {
    return res.status(400).json({ error: "Message is too long." });
  }

  // Prior turns the client chooses to resend, plus the new message. Kept
  // short so payloads (and cost) stay small.
  const messages = Array.isArray(history)
    ? history
        .filter(
          (m) =>
            m &&
            (m.role === "user" || m.role === "assistant") &&
            typeof m.content === "string"
        )
        .slice(-10)
    : [];
  messages.push({ role: "user", content: message.trim() });

  const system = patientContext
    ? `${SYSTEM_PROMPT}\n\nFor your reference only, do not repeat this back verbatim: ${JSON.stringify(
        patientContext
      ).slice(0, 500)}`
    : SYSTEM_PROMPT;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);

  try {
    const upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 300,
        system,
        messages,
      }),
      signal: controller.signal,
    });

    if (!upstream.ok) {
      const errBody = await upstream.text();
      console.error("Anthropic API error:", upstream.status, errBody);
      return res.status(502).json({ error: "Assistant is unavailable right now." });
    }

    const data = await upstream.json();
    const textBlock = (data.content || []).find((b) => b.type === "text");
    const raw = ((textBlock && textBlock.text) || "").trim();

    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch {
      // Model didn't return clean JSON — fail safe, no action triggered.
      parsed = { reply: raw || "Sorry, I didn't catch that.", action: null };
    }

    if (typeof parsed.reply !== "string") parsed.reply = "Got it.";
    if (parsed.action && parsed.action.intent !== "schedule_popup") {
      parsed.action = null;
    }

    return res.status(200).json(parsed);
  } catch (err) {
    if (err.name === "AbortError") {
      console.error("Anthropic request timed out.");
      return res.status(504).json({ error: "Assistant took too long to respond." });
    }
    console.error("synchro-ai handler error:", err);
    return res.status(500).json({ error: "Internal server error." });
  } finally {
    clearTimeout(timeout);
  }
};