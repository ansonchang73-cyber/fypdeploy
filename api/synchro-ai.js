// api/synchro-ai.js
const MODEL = "llama-3.1-8b-instant"; 

const SYSTEM_PROMPT = `You are Synchro AI, the persistent top-bar digital assistant embedded in SynchroM, a synchronized medication management app. 

Your goals:
1. CONTEXTUAL APP & SCHEDULE HELP: If the user asks about their routine, adherence, medications, or how the app works, answer briefly using the provided "Patient Context" data.
2. SCHEDULE REMINDERS: If the user asks to set a reminder or schedule an alert, confirm briefly and output the structured JSON action.

Rules:
- Never give medical advice: no dosing changes, clinical recommendations, or drug interactions. Advise them to consult their doctor or caregiver.
- Reference their actual schedule, adherence, or medications when available in the context.
- Keep "reply" under 25 words.
- Always output a single JSON object in one of two formats:

For conversational replies:
{"reply": "<short concise text>", "action": null}

For reminder actions:
{"reply": "<short confirmation>", "action": {"intent": "schedule_popup", "medication_name": "<name>", "dosage": "<amount if stated, else empty string>", "trigger_time": "<time stated, e.g. '8:00 AM' or 'in 2 hours'>"}}`;

module.exports = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).end();

  try {
    const apiKey = process.env.GROQ_API_KEY ? process.env.GROQ_API_KEY.trim() : "MISSING";
    const message = req.body?.message || "";
    const history = req.body?.history || [];
    const patientContext = req.body?.patientContext || null;

    // --- DEBUG OVERRIDE ---
    if (message.trim().toLowerCase() === "debug key") {
      return res.status(200).json({ 
        reply: `DEBUG: Vercel found a key. Length: ${apiKey.length} characters. Starts with: "${apiKey.substring(0, 5)}". Ends with: "${apiKey.slice(-3)}"`, 
        action: null 
      });
    }

    if (apiKey === "MISSING") {
      return res.status(200).json({ reply: "Server error: GROQ_API_KEY missing in Vercel settings.", action: null });
    }

    const messages = Array.isArray(history)
      ? history.filter((m) => m && typeof m.content === "string").slice(-10)
      : [];
    
    let dynamicSystemPrompt = SYSTEM_PROMPT;
    if (patientContext) {
      dynamicSystemPrompt += `\n\n### CURRENT PATIENT CONTEXT:\n${JSON.stringify(patientContext, null, 2)}`;
    }

    const groqMessages = [
      { role: "system", content: dynamicSystemPrompt },
      ...messages,
      { role: "user", content: message.trim() }
    ];

    const upstream = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: MODEL,
        messages: groqMessages,
        response_format: { type: "json_object" }
      })
    });

    if (!upstream.ok) {
      const errText = await upstream.text();
      return res.status(200).json({ reply: `Groq rejected the request. Status: ${upstream.status}. Error: ${errText.slice(0, 150)}`, action: null });
    }

    const data = await upstream.json();
    const raw = data.choices[0]?.message?.content || "";
    
    let parsed;
    try { 
      parsed = JSON.parse(raw.trim()); 
    } catch (parseError) { 
      parsed = { reply: raw || "Got it.", action: null }; 
    }

    if (parsed.action && parsed.action.intent !== "schedule_popup") {
      parsed.action = null;
    }

    return res.status(200).json(parsed);

  } catch (error) {
    return res.status(200).json({ reply: `Vercel Execution Crash: ${error.message}`, action: null });
  }
};