/**
 * Dialogflow CX bidirectional streaming wrapper (v3beta1 — needed for tools).
 *
 * Owns ONE live conversation turn-loop with CX: push user audio in, get
 * interim transcripts + Aurobhatt's reply + synthesized TTS audio out, AND
 * handle client-side FUNCTION TOOL calls so Baba can act, not just talk.
 *
 * Tool loop (differs from the Live engine):
 *   1. User audio -> CX. CX may reply with a `tool_call` inside the turn's
 *      response_messages (ToolCall{tool, action, input_parameters}).
 *   2. We emit "tool_call" {id, name, args} — same shape the client already
 *      handles for Live — and STOP (don't cycle to a new audio turn yet).
 *   3. Client runs the tool, sends its result back; server calls
 *      sendToolResponse(). We open a FRESH turn whose first query_input is a
 *      ToolCallResult, and CX continues — producing the spoken reply (or, if it
 *      wants, another tool_call, which loops).
 *   4. When a turn finishes with no tool_call, we emit turn_end and re-arm a
 *      normal audio turn for the next utterance.
 *
 * Deliberately dumb about transport — it just emits events. server.js wires
 * those events to the browser/Flutter WebSocket. Keeps each file cohesive.
 */

import { EventEmitter } from "node:events";
import { randomUUID } from "node:crypto";
import dialogflow from "@google-cloud/dialogflow-cx";
import { CONFIG, cxApiEndpoint } from "./config.js";

// ── protobuf Struct <-> plain JS ─────────────────────────────────────────
// CX streaming responses hand back ToolCall.input_parameters as a RAW
// google.protobuf.Struct ({ fields: { k: { kind, stringValue, ... } } })
// rather than an auto-decoded plain object (unlike unary calls). If we forward
// that wrapper as-is the client sees no `destination` and every navigate is a
// silent no-op. So decode it here.
function valueToJs(v) {
    if (v == null) return null;
    // gax exposes whichever field of the Value oneof is set; check by presence
    // so we don't depend on the `kind` discriminator being populated.
    if (v.stringValue !== undefined && v.stringValue !== null) return v.stringValue;
    if (v.numberValue !== undefined && v.numberValue !== null) return v.numberValue;
    if (v.boolValue !== undefined && v.boolValue !== null) return v.boolValue;
    if (v.structValue !== undefined && v.structValue !== null) return structToJs(v.structValue);
    if (v.listValue !== undefined && v.listValue !== null)
        return (v.listValue.values || []).map(valueToJs);
    return null; // nullValue or empty
}
function structToJs(s) {
    if (s == null) return {};
    if (!s.fields) return s; // already a plain object (auto-decoded)
    const out = {};
    for (const [k, val] of Object.entries(s.fields)) out[k] = valueToJs(val);
    return out;
}

// Reuse one v3beta1 gRPC client across sessions (channels are pooled).
const client = new dialogflow.v3beta1.SessionsClient({
    apiEndpoint: cxApiEndpoint(CONFIG.location),
});

// CX ToolCall carries the tool RESOURCE + action; the client keys tools by
// NAME. We provisioned each tool with displayName == the client's tool name, so
// action == name. As a safety net we also map resource -> displayName, fetched
// once and cached process-wide.
let _toolNameByResource = null;
async function toolNameFor(resource, action) {
    if (action) return action; // fast path: action IS the function name
    if (!_toolNameByResource) {
        try {
            const toolsClient = new dialogflow.v3beta1.ToolsClient({
                apiEndpoint: cxApiEndpoint(CONFIG.location),
            });
            const parent = client.projectLocationAgentPath(
                CONFIG.project, CONFIG.location, CONFIG.agentId,
            );
            const [tools] = await toolsClient.listTools({ parent });
            _toolNameByResource = new Map(
                (tools || []).map((t) => [t.name, t.displayName]),
            );
        } catch {
            _toolNameByResource = new Map();
        }
    }
    return _toolNameByResource.get(resource) || resource;
}

/**
 * A single voice session. Emits:
 *   'transcript' ({ text, final })  — live STT of the user
 *   'reply'      ({ text })         — Aurobhatt's text (captions)
 *   'audio'      (Buffer)           — TTS PCM chunk to play
 *   'tool_call'  ({ id, name, args })— Baba wants the client to run a tool
 *   'turn_end'   ()                 — CX finished a response turn
 *   'error'      (Error)
 *   'close'      ()
 */
export class CxVoiceSession extends EventEmitter {
    /**
     * @param {string} sessionId stable id per user/device for context
     * @param {Array}  [_tools]  streamed client declarations — IGNORED for CX
     *   (its tools live on the agent). Kept for a uniform makeSession signature.
     * @param {string} [directive] optional KICKOFF cue. When set, we open the
     *   call with a text turn carrying this cue so Baba speaks/acts FIRST and
     *   leads, instead of waiting for the user. The playbook still owns the
     *   persona; this is just his opening move.
     */
    constructor(sessionId, _tools, directive) {
        super();
        this.sessionId = sessionId;
        this.directive = (directive || "").trim();
        this.stream = null;
        this.configSent = false;
        this.ended = false;         // true only after a real hang-up / fatal error
        this.awaitingTool = false;  // true between emitting a tool_call and its result
        // Armed = ready to open an AUDIO recognizer turn, but we hold off until
        // the first mic chunk actually arrives (lazy-open). This is what stops
        // Cloud Speech's OUT_OF_RANGE "audio timeout" from killing the call: in
        // half-duplex (waitTurn) the client mutes the mic while Baba speaks, so
        // an eagerly-opened recognizer would sit starving and die. No stream
        // exists until there's audio to feed it => it can't starve.
        this._armed = false;
        // Set once we've half-closed the write side of an audio turn (see
        // _onData). Guards sendAudio from writing after end() and stops us
        // half-closing the same turn twice.
        this._audioClosed = false;
        this._pending = new Map();  // callId -> { tool, action }
    }

    /** Build the CX session resource path (env-scoped if not draft). */
    _sessionPath() {
        const { project, location, agentId, environment } = CONFIG;
        if (environment && environment !== "draft") {
            return client.projectLocationAgentEnvironmentSessionPath(
                project, location, agentId, environment, this.sessionId,
            );
        }
        return client.projectLocationAgentSessionPath(
            project, location, agentId, this.sessionId,
        );
    }

    _outputAudioConfig() {
        const cfg = {
            audioEncoding: "OUTPUT_AUDIO_ENCODING_LINEAR_16",
            sampleRateHertz: CONFIG.outputSampleRateHertz,
        };
        if (CONFIG.voiceName) {
            cfg.synthesizeSpeechConfig = { voice: { name: CONFIG.voiceName } };
        }
        return cfg;
    }

    /** First request of an AUDIO turn: configures audio + language. */
    _configRequest() {
        return {
            session: this._sessionPath(),
            queryInput: {
                audio: {
                    config: {
                        audioEncoding: "AUDIO_ENCODING_LINEAR_16",
                        sampleRateHertz: CONFIG.inputSampleRateHertz,
                        singleUtterance: true,
                        // A stronger recognizer than the CX default — much better
                        // on English + Hindi/English code-switching. Omitted when
                        // CX_STT_MODEL="" so we cleanly fall back to the default.
                        ...(CONFIG.sttModel ? { model: CONFIG.sttModel } : {}),
                    },
                },
                languageCode: CONFIG.languageCode,
            },
            outputAudioConfig: this._outputAudioConfig(),
        };
    }

    /** First request(s) of a TOOL-RESULT turn: feed CX the tool outputs. */
    _toolResultRequests(results) {
        return results.map((r, i) => ({
            // Only the first request needs the session + output audio config.
            ...(i === 0
                ? { session: this._sessionPath(), outputAudioConfig: this._outputAudioConfig() }
                : {}),
            queryInput: {
                languageCode: CONFIG.languageCode,
                toolCallResult: {
                    tool: r.tool,
                    action: r.action,
                    outputParameters: r.response || {},
                },
            },
        }));
    }

    /** First request of a KICKOFF turn: a text cue so Baba leads (speaks first). */
    _kickoffRequest() {
        return {
            session: this._sessionPath(),
            queryInput: {
                text: { text: this.directive },
                languageCode: CONFIG.languageCode,
            },
            outputAudioConfig: this._outputAudioConfig(),
        };
    }

    /**
     * Begin the session. With a directive, Baba OPENS the call and leads;
     * otherwise we just open the mic and wait for the user to speak.
     */
    start() {
        this.ended = false;
        if (this.directive) {
            // Kickoff is a text turn (not audio): Baba responds/acts first, then
            // the normal turn cycle re-arms an audio turn to listen.
            this._openTurn([this._kickoffRequest()], /* audio */ false);
        } else {
            // No opener: just arm. The recognizer opens lazily on the user's
            // first mic chunk (see sendAudio) so it never starves waiting.
            this._armed = true;
        }
    }

    /**
     * Open ONE turn's bidi stream and write its initial request(s).
     * @param {Array}   firstRequests requests to write immediately.
     * @param {boolean} audioTurn     true => keep forwarding mic (configSent).
     */
    _openTurn(firstRequests, audioTurn) {
        if (this.ended) return;
        this._armed = false; // a turn is now live; lazy-open no longer pending
        this.configSent = false;
        this._audioClosed = false; // fresh turn: write side is open again
        this.stream = client.streamingDetectIntent();

        this.stream.on("data", (res) => this._onData(res));
        this.stream.on("error", (err) => {
            if (!this.ended) this.emit("error", err);
        });
        this.stream.on("end", () => {
            // We proactively retire streams in _onData; only reach here on an
            // unsolicited close. Re-ARM (don't eagerly reopen) unless shutting
            // down or mid tool-call — the fresh audio turn opens lazily on the
            // next mic chunk, so an idle recognizer can never starve out.
            if (this.ended) this.emit("close");
            else if (!this.awaitingTool) { this._retireStream(); this._armed = true; }
        });

        for (const req of firstRequests) this.stream.write(req);
        this.configSent = audioTurn; // only audio turns accept mic frames
    }

    /**
     * Retire a spent stream WITHOUT auto-reopening. Strip listeners so the old
     * stream's eventual end/error can't double-open or surface a spurious error.
     */
    _retireStream() {
        const spent = this.stream;
        this.stream = null;
        this.configSent = false;
        if (spent) {
            spent.removeAllListeners();
            spent.on("error", () => {}); // swallow post-close cancels
            try { spent.end(); } catch { /* already closed */ }
        }
    }

    /** Retire the current stream and ARM a fresh AUDIO turn for next utterance. */
    _cycleTurn() {
        if (this.ended) return;
        this._retireStream();
        // Lazy: the new recognizer opens when the next mic chunk arrives, not
        // now — so it can't sit idle and hit Cloud Speech's audio timeout.
        this._armed = true;
    }

    /** Forward a raw PCM16 chunk from the client into CX (audio turns only). */
    sendAudio(chunk) {
        if (this.ended || this.awaitingTool) return;
        // Lazy-open the recognizer on the first chunk of a new utterance. This
        // is the anti-starvation core: the CX audio stream only exists while
        // the user is actually speaking, so it never waits (and times out).
        if (this._armed && !this.stream) {
            this._armed = false;
            this._openTurn([this._configRequest()], /* audio */ true);
        }
        if (!this.stream || !this.configSent || this._audioClosed) return;
        this.stream.write({ queryInput: { audio: { audio: chunk } } });
    }

    /**
     * Client ran the tool(s) Baba requested; feed the result(s) back and let CX
     * continue the turn. `functionResponses` matches the Live interface:
     *   [{ id, name, response }]
     */
    async sendToolResponse(functionResponses) {
        if (this.ended) return;
        const results = [];
        for (const fr of functionResponses || []) {
            const p = this._pending.get(fr.id);
            if (!p) continue; // unknown/expired call id
            this._pending.delete(fr.id);
            results.push({ tool: p.tool, action: p.action, response: fr.response || {} });
        }
        if (!results.length) return;
        // Retire the (idle) tool-call stream, then open a fresh turn that
        // carries the tool results so CX can finish speaking.
        this.awaitingTool = false;
        this._retireStream();
        this._openTurn(this._toolResultRequests(results), /* audio */ false);
    }

    /**
     * Inject what the user is now looking at as a TEXT turn so Baba reacts to
     * the screen (e.g. narrate the chart reveal). CX is turn-based, so a text
     * turn always produces a spoken reply — `speak` is accepted for a uniform
     * signature with the Live engine but CX effectively always narrates. No-op
     * while a tool call is in flight (don't disturb that loop).
     */
    injectContext(text, _speak = true) {
        if (this.ended || this.awaitingTool) return;
        const ctx = typeof text === "string" ? text.trim() : "";
        if (!ctx) return;
        this._retireStream();
        this._openTurn([{
            session: this._sessionPath(),
            queryInput: {
                text: { text: `[SCREEN CONTEXT] ${ctx}` },
                languageCode: CONFIG.languageCode,
            },
            outputAudioConfig: this._outputAudioConfig(),
        }], /* audio */ false);
    }

    /** Translate one CX streaming response into our events. */
    async _onData(res) {
        // Interim / final speech recognition of what the USER said.
        const rr = res.recognitionResult;
        if (rr && rr.transcript) {
            const isFinal = rr.messageType === "END_OF_SINGLE_UTTERANCE"
                || rr.isFinal === true;
            this.emit("transcript", { text: rr.transcript, final: isFinal });
            // Chirp/USM recognizers (chirp_2) do NOT honor `singleUtterance`
            // endpointing, so CX never auto-closes the recognizer when the user
            // stops. The client mutes its mic in half-duplex (waitTurn), so no
            // more audio arrives and Cloud Speech ABORTs with "Stream timed out
            // after receiving no more client requests" ~10s later. On a FINAL
            // recognition result we half-close the write side ourselves — this
            // tells CX "utterance complete, go think" and it proceeds to the
            // reply. Harmless for endpointing models (latest_long); essential
            // for chirp. We keep the READ side open to receive the response.
            if (isFinal && this.configSent && this.stream && !this._audioClosed) {
                this._audioClosed = true;
                try { this.stream.end(); } catch { /* already half-closed */ }
            }
        }

        const dir = res.detectIntentResponse;
        if (!dir) return;

        const messages = dir.queryResult?.responseMessages || [];
        const toolCalls = [];
        for (const m of messages) {
            const t = m.text?.text?.join(" ").trim();
            if (t) this.emit("reply", { text: t });
            if (m.toolCall) toolCalls.push(m.toolCall);
        }

        // Baba wants to act: emit each call, remember it, and WAIT for results.
        if (toolCalls.length) {
            for (const tc of toolCalls) {
                const id = randomUUID();
                this._pending.set(id, { tool: tc.tool, action: tc.action });
                const name = await toolNameFor(tc.tool, tc.action);
                const args = structToJs(tc.inputParameters);
                console.log(
                    `[cx ${this.sessionId}] tool_call ${name} args=${JSON.stringify(args)}`,
                );
                this.emit("tool_call", { id, name, args });
            }
            this.awaitingTool = true;
            this._retireStream(); // hold here; sendToolResponse() resumes us
            return;
        }

        // Normal turn: play any audio, close the turn, re-arm for next utterance.
        if (dir.outputAudio && dir.outputAudio.length) {
            this.emit("audio", Buffer.from(dir.outputAudio));
        }
        this.emit("turn_end");
        this._cycleTurn();
    }

    /** Close the session for good (user hung up). Stops the reopen loop. */
    end() {
        this.ended = true;
        this._armed = false;
        this._pending.clear();
        try { this.stream?.end(); } catch { /* already closed */ }
        this.stream = null;
    }
}
