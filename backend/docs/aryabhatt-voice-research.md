# Aryabhatt → Voice: Research & Roadmap

*Status: research / decision doc. No code changed yet.*
*Author: Jo (code-puppy), for Abhinav.*

---

## TL;DR

"Aryabhatt" is **not a model**. It is `gemini-2.5-flash` (Vertex AI, `asia-southeast1`)
plus a system-prompt persona (`ARYABHATT_PERSONA` in `functions/prompts/chat.js`).
There is nothing to "convert" — there are no weights we own.

So "make Aryabhatt a voice model" really means: **wrap the existing brain in a voice
I/O layer.** And the good news is you already built ~half of it.

| Stage | Today | Gap |
|-------|-------|-----|
| **Voice IN** |  Done | Flutter records + transcribes (`speech_to_text`, `en_IN`), uploads audio; backend feeds raw audio to Gemini as `inlineData` (`ai_gemini.js > buildAudioParts`). Gemini understands the audio natively. |
| **Brain** |  Done | Gemini 2.5-flash, persona prompt, streaming, `isVoice` style rules (40–80 word spoken replies) already exist. |
| **Voice OUT** |  Missing | Aryabhatt never literally *speaks*. The reply is streamed **text**. The `isVoice` flag only shortens the text; nothing synthesizes audio. |

**The whole job = add Text-To-Speech (voice OUT), and optionally upgrade to a
real-time full-duplex voice loop.**

---

## Three ways to do it (pick one)

### Tier 1 — Bolt TTS onto the existing text stream  *(fastest, lowest risk)*

Keep the entire current pipeline. After (or while) the text streams back, synthesize
it to audio and play it in the app.

```
user voice ──► Gemini (unchanged) ──► text stream ──► sentence chunker ──► TTS ──► audio ──► play
```

- **Effort:** small. One new backend endpoint + one Flutter audio player.
- **Latency trick:** chunk the streamed text by sentence and TTS each sentence as it
  lands, so Aryabhatt starts speaking before the full reply is done.
- **Voice engine options** (this is where Aryabhatt's actual *voice* is chosen):
  - **Google Cloud TTS — Chirp 3 HD** voices. Same GCP project (`ty-dev-516d7`), same
    ADC auth you already use for Vertex. Cleanest fit. Supports Indian English + Hindi.
  - **Gemini TTS** (`gemini-2.5-flash-preview-tts`) — controllable, expressive,
    prompt-steerable ("speak warmly, like a 23-year-old scholar"). Stays in-family.
  - **ElevenLabs** — best raw voice quality + voice cloning (you could craft a
    *bespoke* Aryabhatt voice). External vendor, extra cost, data leaves GCP.
  - **Sarvam AI / Bhashini** — built for **Indian languages & accents**. Strong pick
    given the Hinglish/Hindi audience. Sarvam is a paid API; Bhashini is govt-backed.
- **Cost:** TTS is ~$4–16 per 1M chars (Google) — at 40–80 word replies this is
  pennies per conversation. Cheaper than the search-grounding line item you flagged.

**Recommended starting voice engine: Google Cloud TTS Chirp 3 HD** (zero new auth,
same project, low latency from your Singapore region) — then A/B against ElevenLabs /
Sarvam for "does it actually *sound* like Aryabhatt."

---

### Tier 2 — Gemini Live API (native real-time audio)  *(the "true" voice model)*

`gemini-2.5-flash` (and the Live/native-audio variants) support **bidirectional
streaming audio**: speech in → speech out, in one socket, no separate STT or TTS.
The model speaks in a chosen native voice with sub-second latency and natural
interruption ("barge-in").

```
user mic ──(WebSocket, live)──► Gemini Live ──► native audio out ──► speaker
                         (persona prompt injected as systemInstruction)
```

- **Effort:** medium. New WebSocket/Live session layer; the persona prompt ports over
  almost verbatim. The `@google/genai` SDK supports Live (the `@google-cloud/vertexai`
  SDK you use today does **not** — note the comment in `vertex_client.js`).
- **Wins:** lowest latency, natural turn-taking, true conversation. This is what people
  mean by "a voice model."
- **Watch-outs:**
  - Different SDK (`@google/genai`) and a persistent connection — heavier than your
    current request/response Cloud Function model. Likely wants a small dedicated
    service or a Functions-with-WebSocket setup.
  - Less control over each individual TTS line than Tier 1.
  - Voice selection is from Gemini's native voice set (no custom-cloned voice).

---

### Tier 3 — Agora Conversational AI  *(telephony-grade, you already pay for Agora)*

You already integrate **Agora** for video/voice calls (`functions/agora_token.js`,
`triggers/on_call_write.js`). Agora's Conversational AI Engine can host an LLM voice
agent inside an Agora channel — so "call Aryabhatt" becomes a literal phone-style call
with echo cancellation, noise suppression, and global low-latency transport built in.

- **Effort:** medium–high, but reuses Agora infra/tokens you already have.
- **Best if:** you want a " Talk to Aryabhatt" call experience, not just voice replies
  in chat.
- **Trade-off:** ties the voice product to Agora; more moving parts than Tier 1.

---

## Recommendation

1. **Ship Tier 1 first.** It reuses 100% of the current brain, is a few days of work,
   and immediately makes Aryabhatt *audible*. Use it to nail the **voice identity**
   (warm, ~23, classical-but-not-archaic — matches the persona bible) before investing
   in real-time plumbing.
2. **Then evaluate Tier 2 (Gemini Live)** for the flagship "talk to him live"
   experience once the voice itself is validated.
3. **Reach for Tier 3 (Agora)** only if the product direction is literally *calling*
   Aryabhatt, since you already own that infra.

Do **not** try to fine-tune or "train a voice model" from scratch — there's no upside.
The persona lives in the prompt; the voice lives in the TTS engine. Swap engines freely.

---

## Concrete first steps for Tier 1 (when you greenlight)

1. **Backend:** new `synthesizeSpeech` helper (Google Cloud TTS, Chirp 3 HD, ADC auth).
   Either a new callable that takes text → returns audio URL/bytes, or stream audio
   chunks alongside the existing `token` events in `ai.js`.
2. **Chunking:** split the streamed reply on sentence boundaries; TTS per sentence for
   early playback (first audio out before full text is done).
3. **Flutter:** audio playback service (you already have `audio_input_service.dart` for
   record/transcribe — add a player) + a play button / auto-play toggle on Aryabhatt's
   bubbles.
4. **Voice tuning:** pick voice + rate + pitch to match the persona; A/B Chirp 3 HD vs
   ElevenLabs vs Sarvam on real replies.
5. **Languages:** decide English-only v1 vs Hindi/Hinglish. If Hinglish matters early,
   bias toward Sarvam/Bhashini or Google's Indian-locale voices.

## Cost note (ties to your existing unit-economics work)

TTS adds a *small* per-message cost (pennies). It is far below the Google Search
grounding line you identified as ~51% of cost-to-serve. Voice will not blow up unit
economics at Tier 1. Tier 2/3 add connection-time costs worth modeling separately.
