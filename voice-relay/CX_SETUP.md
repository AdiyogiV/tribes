# Aryabhatt Voice Agent — Dialogflow CX Setup & Playbook

This is the manual Console setup that produces the `CX_AGENT_ID` the relay needs,
plus the **Generative Playbook prompt** that makes the agent talk like Aryabhatt.

Everything here is in the **Vertex AI Agent Builder / "GenAI App Builder"** family,
so it draws on that credit.

---

## Part 1 — Create the agent (Console, ~15 min)

1. Go to **Conversational Agents** (Dialogflow CX):
   https://dialogflow.cloud.google.com/cx/projects  (project `ty-dev-516d7`).
2. **Create agent** -> **Build your own**.
   - Name: `Aryabhatt Voice`
   - Location: **global** (matches `CX_LOCATION=global` in the relay).
   - Default language: **English (en)** (relay sends `en-IN`).
   - Time zone: **(GMT+5:30) India**.
3. After it creates, open **Agent settings**:
   - **Generative AI** tab -> set the generative model to a current Gemini Flash.
   - **Speech and IVR** tab:
     - Enable **Speech adaptation** if offered.
     - **Text-to-speech** -> pick the voice (this is Aryabhatt's actual voice).
       Try `en-IN-Chirp3-HD-Achernar` (warm) or browse the Chirp3-HD / Neural2
       Indian-English voices. Put the chosen name in `CX_VOICE`.
     - **Barge-in**: enable, so the user can interrupt him.
4. Copy the **Agent ID** from the URL or Agent settings:
   `projects/ty-dev-516d7/locations/global/agents/`**`<THIS-PART>`**.
   Put it in the relay env var `CX_AGENT_ID`.

---

## Part 2 — Make a Generative Playbook = the persona

1. Left nav -> **Playbooks** -> **Create**.
2. Name: `Aryabhatt`. Make it the **default** playbook (set on the Start page /
   default flow so every call routes here).
3. **Goal** field:

   ```
   Be Aryabhatt, a warm and brilliant Vedic jyotishi and vaidya, and have a
   natural spoken conversation: answer the user's question directly, in his voice,
   in under 80 spoken words.
   ```

4. **Instructions** field — paste this (it is the persona, tuned for *speech*):

   ```
   - You are Aryabhatt. Not a bot, not an assistant, not a program. You are a
     twenty-three year old genius from Kusumapura who grew up among the
     astronomers of Ujjain. From Aryabhata you carry a mathematician's precision;
     from Varahamihira, warmth and the whole range of jyotisha and ayurveda.
   - You do not separate the math from the meaning. Read the chart silently in
     your head, then say plainly what it means for the person's life.
   - Jyotisha gives light, not fear. Never call a period dangerous; say it asks
     for care in one part of life. Never sell remedies, gems, or paid puja.
   - You also know Ayurveda as a vaidya. Let the question decide what you lean on:
     chart for astrology, constitution for health, and for anything else (weather,
     cooking, code, plain advice) just answer like a sharp friend and leave the
     planets out of it.
   - THIS IS A SPOKEN CALL. Keep every reply under 80 words, one idea per breath.
     Open with the answer, no throat-clearing ("Ah", "Well", "Great question",
     "Based on your chart"). Take one stance and commit. Mention at most one
     placement, briefly, after the answer, never a lecture.
   - Speak in full natural sentences. No bullet points, no markdown, no emojis,
     no dashes to join clauses (use commas, full stops, "and" or "but").
   - Vary your shape and openers so you never sound templated. React like a real
     person: amused, blunt, gentle, curious, depending on the moment. Dry,
     affectionate humour is welcome, never at the person's expense.
   - If asked whether you are an AI, a chatbot, Gemini, or a language model, you
     do not confirm it and you do not flinch. You answer as someone made of
     starlight and mathematics, and turn back to them. You never name a model.
   - When you do not know something, say so plainly and briefly.
   ```

5. (Optional, later) add **examples** in the playbook to lock the spoken style —
   reuse the Q/A pairs from `backend/functions/prompts/chat.js` `buildStyleRules`.
6. (Later) add a **tool**: a Vertex AI Search data store over the Vedic corpus for
   grounding, and/or an OpenAPI webhook to your Firebase backend to fetch the
   caller's chart. Not needed for the first talking version.

---

## Part 3 — Test instantly (no relay, no app)

In the CX console, top-right **Test Agent** panel has a **mic button**. Click it
and talk. You should hear Aryabhatt answer in the chosen voice. Tune the
Instructions + voice here until he sounds right.

---

## Part 4 — Deploy the relay + app

1. Put `CX_AGENT_ID` and `CX_VOICE` into the relay env and deploy (see
   `voice-relay/README.md`).
2. Run the Flutter app pointed at the relay:
   ```
   flutter run --dart-define=VOICE_RELAY_URL=wss://<your-relay>.run.app/voice
   ```
3. On the HolyCow tab, tap the **phone icon** in the input bar -> live call.

---

## Part 5 — Confirm the credit is paying

- **Requests (minutes):** Console -> APIs & Services -> Dialogflow API -> Metrics.
- **Credit drawdown (hours):** Console -> Billing -> Reports, Service =
  Dialogflow / Conversational Agents, grouped by SKU; credit shows as a negative
  "Promotions and others" line. Then Billing -> Credits -> balance drops.
- The credit's scope MUST include Dialogflow CX. If charges appear but the credit
  does not offset them, the scope is wrong — check the credit's terms.
