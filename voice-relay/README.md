# Aryabhatt Voice Relay

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

## Wire protocol (Flutter <-> relay)

**Client -> relay**
- Binary frame = raw audio chunk: **PCM 16-bit, 16 kHz, mono** (LINEAR16).
- JSON control:
  - `{"type":"start","sessionId":"<uid-or-random>"}` — open the CX stream.
  - `{"type":"stop"}` — end the current turn / close.

**Relay -> client**
- Binary frame = TTS audio chunk: **PCM 16-bit, 24 kHz, mono**. Play as it arrives.
- JSON events:
  - `{"type":"transcript","text":"...","final":false}` — live STT of the user.
  - `{"type":"reply","text":"..."}` — Aryabhatt's text (for captions).
  - `{"type":"speaking_done"}` — turn finished, mic can resume.
  - `{"type":"error","message":"..."}`.

---

## Env vars

| Var | Example | Notes |
|-----|---------|-------|
| `GCP_PROJECT` | `ty-dev-516d7` | |
| `CX_LOCATION` | `global` | Match where you created the agent. |
| `CX_AGENT_ID` | `xxxxxxxx-xxxx-...` | From the Console after creating the agent. |
| `CX_ENVIRONMENT` | `draft` | Or a published environment id. |
| `CX_LANGUAGE` | `en-IN` | Hinglish-friendly. |
| `CX_VOICE` | `en-IN-Chirp3-HD-...` | Pick Aryabhatt's TTS voice. |
| `PORT` | `8080` | Cloud Run sets this. |

Service account needs `roles/dialogflow.client`.

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
3. The client prints your live transcript + Aryabhatt's reply text and saves his
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

```bash
cd voice-relay
gcloud run deploy aryabhatt-voice-relay \
  --source . \
  --project ty-dev-516d7 \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars GCP_PROJECT=ty-dev-516d7,CX_LOCATION=global,CX_AGENT_ID=...,CX_ENVIRONMENT=draft,CX_LANGUAGE=en-IN,CX_VOICE=en-IN-Chirp3-HD-Achernar
```

> `--allow-unauthenticated` for the MVP. Before launch, put Firebase App Check /
> an ID-token check in front (see TODO in `server.js`).

---

## Prereqs you still owe me
1. Create the Conversational Agent (CX) + Generative Playbook with the Aryabhatt
   persona, enable a voice, and paste the **agent ID** into `CX_AGENT_ID`.
2. Confirm the credit's scope includes **Dialogflow CX** SKUs
   (Console -> Billing -> Credits).
