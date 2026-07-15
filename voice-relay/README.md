# Aurobhatt Voice Relay

A tiny Cloud Run service that bridges the Flutter app to **Dialogflow CX**
(Conversational Agents) **bidirectional streaming voice**.

```
Flutter (mic PCM)  --WebSocket-->  THIS RELAY  --gRPC stream-->  Dialogflow CX
Flutter (speaker)  <--WebSocket--  THIS RELAY  <--gRPC stream--  CX (TTS audio)
```

Why a relay: CX streaming is gRPC + a service account. We never ship SA creds
to the device. The relay holds creds and proxies audio both ways. It also lets
us keep the existing text chat untouched — this is purely the new voice surface.

This rides the **Vertex AI Agent Builder / "GenAI App Builder"** credit family
(Dialogflow CX SKUs), which is the whole point.

---

## Engines (`VOICE_ENGINE`)

The relay can drive two back-ends. Pick with `VOICE_ENGINE` (default `cx`):

| Value | What it does |
|-------|--------------|
| `cx` | **Dialogflow CX** bidi stream — ONE agent does STT + brain (generative playbook with **tool-calling**, v3beta1) + TTS. Funded by the Dialogflow CX trial credit. **Production default.** Half-duplex (`waitTurn`): the recognizer opens lazily per utterance so it never starves on Cloud Speech's audio timeout. |
| `live` | **Gemini Live API** — ONE model does STT + brain + TTS **and native barge-in** (built-in VAD). Persona/context fetched from `aiChat` (`promptOnly`). **Currently PARKED** — needs Vertex AI Live quota + billing; unprovisioned sessions fail to start. |

The wire protocol to the Flutter client is **identical** across engines, so
swapping engines needs no app rebuild.

> **Live API IAM:** the Cloud Run runtime service account needs
> `roles/aiplatform.user` (in addition to `roles/dialogflow.client` for the
> legacy engines). The Live call runs *from* Cloud Run (Google's network), so it
> is NOT subject to the Walmart VPC-SC perimeter that blocks local testing.

---

## Wire protocol (Flutter <-> relay)

**Client -> relay**
- Binary frame = raw audio chunk: **PCM 16-bit, 16 kHz, mono** (LINEAR16).
- JSON control:
  - `{"type":"start","sessionId":"<uid-or-random>"}` — open the CX stream.
  - `{"type":"tool_response","id":"...","name":"...","response":{...}}` — result of a tool Baba called.
  - `{"type":"context","text":"...","speak":true}` — tell Baba what the user is now looking at, mid-call (e.g. the onboarding chart reveal). `speak:true` (default) => he narrates it now; `speak:false` => silent awareness, he only mentions it if asked (**Live only** — CX is turn-based so it always answers). Injected as a tagged `[SCREEN CONTEXT]` user turn, not as spoken user input.
  - `{"type":"stop"}` — end the current turn / close.

**Relay -> client**
- Binary frame = TTS audio chunk: **PCM 16-bit, 24 kHz, mono**. Play as it arrives.
- JSON events:
  - `{"type":"transcript","text":"...","final":false}` — live STT of the user.
  - `{"type":"reply","text":"..."}` — Aurobhatt's text (for captions).
  - `{"type":"speaking_done"}` — turn finished, mic can resume.
  - `{"type":"error","message":"..."}`.

---

## Env vars

| Var | Example | Notes |
|-----|---------|-------|
| `VOICE_ENGINE` | `cx` | `cx` (Dialogflow CX, production default) / `live` (Gemini Live API, parked). |
| `LIVE_MODEL` | `gemini-live-2.5-flash-preview-native-audio-09-2025` | Live API model. Native-audio = best multilingual voice + VAD. |
| `LIVE_LOCATION` | `us-central1` | Vertex region for the Live API. |
| `LIVE_VOICE` | `Charon` | Aurobhatt's prebuilt voice (deeper/male). |
| `LIVE_LANGUAGE` | _(empty)_ | Empty = native multilingual auto-detect. Set e.g. `hi-IN` to pin. |
| `LIVE_PROMPT_URL` | `https://aichat-...run.app` | `aiChat` endpoint; called in `promptOnly` mode for the systemInstruction. Defaults to `AI_CHAT_URL`. |
| `GCP_PROJECT` | `ty-dev-516d7` | |
| `CX_LOCATION` | `global` | Match where you created the agent. |
| `CX_AGENT_ID` | `xxxxxxxx-xxxx-...` | From the Console after creating the agent. |
| `CX_ENVIRONMENT` | `draft` | Or a published environment id. |
| `CX_LANGUAGE` | `en-IN` | Hinglish-friendly. |
| `CX_VOICE` | `en-IN-Chirp3-HD-...` | Pick Aurobhatt's TTS voice. |
| `BARGE_IN` | `true` | Interrupt-to-talk: user can cut in while Aurobhatt speaks and he stops to listen. Set `false` to fall back to half-duplex (no rebuild) if a device's echo cancellation causes false interrupts. |
| `BARGE_IN_MIN_CHARS` | `6` | Min transcribed chars during playback before it counts as an interruption (filters echo/cough fragments). |
| `BARGE_IN_MIN_WORDS` | `2` | Min word count too — echo usually transcribes as one garbled token, so ≥2 words kills most false interrupts. |
| `BARGE_IN_GRACE_MS` | `600` | Deaf window (ms) after Aurobhatt STARTS speaking, where his own onset echoes hardest — no barge-in during it. |
| `PORT` | `8080` | Cloud Run sets this. |

Service account needs `roles/dialogflow.client` (legacy engines) and, for the
Live API engine, `roles/aiplatform.user`.

---

## Run locally

```bash
cd voice-relay
npm install
GCP_PROJECT=ty-dev-516d7 CX_LOCATION=global CX_AGENT_ID=... \
CX_ENVIRONMENT=draft CX_VOICE=en-IN-Chirp3-HD-Achernar \
npm start
# WebSocket at ws://localhost:8080/voice
```

## Test it end-to-end (no Flutter needed)

1. Make a compatible WAV (PCM16, 16 kHz, mono) from any clip:
   ```bash
   ffmpeg -i question.m4a -ac 1 -ar 16000 -sample_fmt s16 input.wav
   ```
2. Start the relay (see "Run locally" above), then in another terminal:
   ```bash
   cd voice-relay
   npm run test:client -- input.wav
   # or: node tools/test_client.js input.wav ws://localhost:8080/voice
   ```
3. The client prints your live transcript + Aurobhatt's reply text and saves his
   spoken answer to `out.wav`. Play it: `open out.wav`.

If `out.wav` is empty, the agent's voice config or the credit scope is off.

### Verify the credit is actually paying
- **Requests landing (minutes):** Console -> APIs & Services -> Dialogflow API ->
  Metrics, or Metrics Explorer `serviceruntime.googleapis.com/api/request_count`
  filtered to `dialogflow.googleapis.com`.
- **Credit drawdown (hours):** Console -> Billing -> Reports, filter
  Service = Dialogflow / Conversational Agents, group by SKU; the credit shows as
  a negative "Promotions and others" line. Then Billing -> Credits -> balance drops.
- Charges must land on `ty-dev-516d7` and the credit scope must include CX.

## Deploy to Cloud Run

### Live API engine (recommended)

```bash
# 1) Grant the Cloud Run runtime SA access to Vertex AI (one-time).
#    Find the SA with: gcloud run services describe aryabhatt-voice-relay \
#      --region us-central1 --format='value(spec.template.spec.serviceAccountName)'
gcloud projects add-iam-policy-binding ty-dev-516d7 \
  --member="serviceAccount:<RUNTIME_SA>" \
  --role="roles/aiplatform.user"

# 2) Deploy with the live engine.
cd voice-relay
gcloud run deploy aryabhatt-voice-relay \
  --source . \
  --project ty-dev-516d7 \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GCP_PROJECT=ty-dev-516d7,VOICE_ENGINE=live,LIVE_VOICE=Charon
```

The Live call runs *from* Cloud Run, so it is NOT blocked by the Walmart VPC-SC
perimeter (that only bites local testing). The persona/context comes from the
`aiChat` backend in `promptOnly` mode — redeploy that backend too (it gained the
`promptOnly` short-circuit).

### CX engine (production default)

```bash
cd voice-relay
gcloud run deploy aryabhatt-voice-relay \
  --source . \
  --project ty-dev-516d7 \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GCP_PROJECT=ty-dev-516d7,VOICE_ENGINE=cx,CX_LOCATION=global,CX_AGENT_ID=...,CX_ENVIRONMENT=draft,CX_LANGUAGE=hi-IN,CX_VOICE=hi-IN-Chirp3-HD-Charon
```

> The service lives in **us-central1**. From a Walmart machine the source
> deploy hits a VPC-SC perimeter on Artifact Registry — route gcloud through the
> sysproxy: prefix the command with
> `HTTPS_PROXY=http://sysproxy.wal-mart.com:8080 HTTP_PROXY=http://sysproxy.wal-mart.com:8080`.
> Omit `--set-env-vars` when redeploying existing code so Cloud Run PRESERVES
> the current env + `--min-instances 1`.

> `--allow-unauthenticated` for the MVP. Before launch, put Firebase App Check /
> an ID-token check in front (see TODO in `server.js`).

---

## Prereqs you still owe me
1. Create the Conversational Agent (CX) + Generative Playbook with the Aurobhatt
   persona, enable a voice, and paste the **agent ID** into `CX_AGENT_ID`.
2. Confirm the credit's scope includes **Dialogflow CX** SKUs
   (Console -> Billing -> Credits).
