// api/synchro-ai.js
//
// Vercel Serverless Function — the backend brain for the "Synchro AI"
// top-bar assistant in the SynchroM Flutter web app.
//
// REQUIRED SETUP (Vercel dashboard → Project Settings → Environment Variables):
//   GROQ_API_KEY               your Groq API key (free at console.groq.com). Required.
//
// OPTIONAL:
//   SYNCHRO_AI_SHARED_SECRET   any random string.
//   SYNCHRO_AI_ALLOWED_ORIGIN  lock CORS to your real domain.

const MODEL = "llama-3.3-70b-versatile"; // Extremely fast and free on Groq

const SYSTEM_PROMPT = `You are Synchro AI, the persistent top-bar assistant embedded in SynchroM, a synchronized medication management app. Behave like a quick-access embedded banking-app assistant: fast, concise, no filler.

You do two things only:

1. APP HELP — if the user asks how SynchroM works, how to navigate it, or about their existing schedule, answer briefly and helpfully.

2. REMINDERS — if the user asks you to remind them to take a medication, log a dose, or set an alert, confirm it in one short sentence and describe it as structured data.

Rules:
- Never give medical advice: no dosing recommendations, drug interactions, or clinical guidance. If asked, say you can't advise on that and suggest they check with their doctor, pharmacist, or caregiver — then stop there.
- Only ever schedule a reminder for what the user explicitly tells you (their own stated medication, dose, and time). Never invent or suggest a dosage or time yourself.
- Keep "reply" under 20 words.
- Respond with ONLY a single JSON object matching exactly one of these two shapes:

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

  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    console.error("GROQ_API_KEY is not set.");
    return res.status(500).json({ error: "Server is not configured." });
  }

  const { message, history, patientContext } = req.body || {};

  if (typeof message !== "string" || !message.trim()) {
    return res.status(400).json({ error: '"message" (string) is required.' });
  }
  if (message.length > 1000) {
    return res.status(400).json({ error: "Message is too long." });
  }

  // Prior turns the client chooses to resend
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
  
  const system = patientContext
    ? `${SYSTEM_PROMPT}\n\nFor your reference only, do not repeat this back verbatim: ${JSON.stringify(
        patientContext
      ).slice(0, 500)}`
    : SYSTEM_PROMPT;
    
  // Groq/OpenAI format requires the system prompt as the first message
  const groqMessages = [
    { role: "system", content: system },
    ...messages,
    { role: "user", content: message.trim() }
  ];

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);

  try {
    const upstream = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 300,
        messages: groqMessages,
        response_format: { type: "json_object" }
      }),
      signal: controller.signal,
    });

    if (!upstream.ok) {
      const errBody = await upstream.text();
      console.error("Groq API error:", upstream.status, errBody);
      return res.status(502).json({ error: "Assistant is unavailable right now." });
    }

    const data = await upstream.json();
    const raw = data.choices[0]?.message?.content || "";

    let parsed;
    try {
      parsed = JSON.parse(raw.trim());
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
      console.error("Groq request timed out.");
      return res.status(504).json({ error: "Assistant took too long to respond." });
    }
    console.error("synchro-ai handler error:", err);
    return res.status(500).json({ error: "Internal server error." });
  } finally {
    clearTimeout(timeout);
  }
};