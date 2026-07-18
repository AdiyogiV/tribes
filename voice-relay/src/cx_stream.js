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

// ── PII-safe logging of tool arguments ──────────────────────────────────
// Tool args carry real user PII — phone numbers, SMS OTP codes, birth
// date/time/place, names, and personal memory notes. These must NEVER land in
// Cloud Run logs. We log the SHAPE (tool + arg keys) always, which is enough to
// follow the call flow, and the VALUES only when CX_DEBUG_TURNS is on — except
// the auth secrets (phone/OTP), which are redacted even in debug.
const SECRET_ARG_TOOLS = new Set(["setPhoneNumber", "setOtp"]);
function previewArgs(name, args) {
    if (SECRET_ARG_TOOLS.has(name)) return "<redacted:secret>";
    if (CONFIG.debugTurns) return JSON.stringify(args);
    const keys = args && typeof args === "object" ? Object.keys(args) : [];
    return `{keys:${JSON.stringify(keys)}}`; // shape only — values are PII
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
        // Duplicate-reprompt guard. In half-duplex, a listening turn can open on
        // silence/ambient noise and yield no real input; CX then re-emits its
        // PREVIOUS reply verbatim (with audio) as a no-input reprompt, so Baba
        // repeats himself in a loop. We remember the last reply we forwarded and
        // whether the user has actually spoken since; an identical, tool-less
        // reply with no user speech in between is swallowed whole (no text, no
        // audio). Real repeats (the user asked twice) always have a final
        // transcript in between, so they are never suppressed.
        this._lastReplyText = null;
        this._userSpokeSinceReply = false;
        // True only while the live turn is an AUDIO (listening) turn. The
        // duplicate-reprompt guard applies ONLY to these — text turns (kickoff
        // greeting, tool-result continuations, screen narration) are always
        // intentional and must never be swallowed even if identical.
        this._audioTurn = false;
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
        // DIAGNOSTIC: what kind of turn is currently live, so the logs read as a
        // clean turn-by-turn story (kickoff | audio | toolResult | context). Set
        // by each opener just before _openTurn.
        this._turnKind = "idle";
        // Monotonic turn counter — makes it trivial to line up open/data/end.
        this._turnSeq = 0;
        // One-shot guard: after a tool result comes back with NO spoken reply
        // (the model front-loaded its line BEFORE the tool and said nothing
        // after), we nudge CX ONCE to actually narrate the new state now,
        // instead of leaving dead air until a ~10s no-input reprompt fires.
        // Reset per tool result so each action gets its own single nudge.
        this._continueNudged = false;
        // Tool-result watchdog handle (see _armToolWatchdog). Guarantees a call
        // can never hang forever waiting for a tool_response that never arrives.
        this._toolTimer = null;
        // Whether the LAST tool result was a success (ok !== false). Steers the
        // empty-continuation nudge so it can't cheerily narrate a FAILED action.
        this._lastToolResultOk = true;
    }

    /** Tag every log line with the session so a call reads as one story. */
    _log(msg) {
        // eslint-disable-next-line no-console
        console.log(`[cx ${this.sessionId}] ${msg}`);
    }

    /**
     * Verbose per-turn trace (turn_open / turn_data / turn_end). Gated behind
     * CONFIG.debugTurns so production logs stay quiet; the semantically
     * meaningful events (tool_call, swallow, nudge, errors) still use _log.
     */
    _dbg(msg) {
        if (CONFIG.debugTurns) this._log(msg);
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
            this._turnKind = "kickoff";
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
        this._turnSeq += 1;
        this._dbg(`turn_open #${this._turnSeq} kind=${this._turnKind} audio=${audioTurn}`);
        this.stream = client.streamingDetectIntent();

        this.stream.on("data", (res) => this._onData(res));
        this.stream.on("error", (err) => {
            if (this.ended) return;
            // Cloud Speech kills an audio recognizer that sits without incoming
            // audio: code 11 OUT_OF_RANGE ("Audio Timeout ... Long duration
            // elapsed without audio") or code 10 ABORTED ("Stream timed out
            // after receiving no more client requests"). In half-duplex
            // (waitTurn) the mic is muted while Baba speaks, so a recognizer
            // that opened but got no/partial audio WILL hit this — it is NOT
            // fatal to the call. Silently retire the dead recognizer and re-arm
            // so the NEXT mic chunk lazily opens a fresh turn. Only surface
            // genuinely unexpected errors to the client.
            if (this._isRecoverableSttTimeout(err) && !this.awaitingTool) {
                this._log(`stt_timeout #${this._turnSeq} kind=${this._turnKind} code=${err?.code} -> retire+rearm`);
                this._retireStream();
                this._armed = true;
                return;
            }
            this._log(`stream_error #${this._turnSeq} kind=${this._turnKind} code=${err?.code} msg=${JSON.stringify(String(err?.message || err).slice(0, 120))}`);
            // A genuinely fatal error must leave the session CONSISTENT, not
            // "dead but open": retire the broken stream, stop the tool watchdog,
            // and mark ended so sendAudio/injectContext can't write into a dead
            // stream. The client hears the error and tears the socket down.
            this._retireStream();
            this._clearToolWatchdog();
            this.awaitingTool = false;
            this.ended = true;
            this.emit("error", err);
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
        this._audioTurn = audioTurn;
    }

    /**
     * True for Cloud Speech recognizer timeouts that are safe to recover from by
     * retiring + re-arming (rather than failing the whole call). These happen
     * whenever a recognizer opens but doesn't get a steady real-time audio feed
     * — expected in half-duplex when the mic is muted during Baba's speech.
     */
    _isRecoverableSttTimeout(err) {
        const code = err?.code;
        const msg = `${err?.message || err?.details || ""}`.toLowerCase();
        // 11 = OUT_OF_RANGE (audio timeout), 10 = ABORTED (stream timed out).
        if (code !== 10 && code !== 11) return false;
        return (
            msg.includes("audio timeout") ||
            msg.includes("long duration elapsed without audio") ||
            msg.includes("timed out") ||
            msg.includes("no more client requests")
        );
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

    /**
     * Arm the tool-result watchdog. Call right after emitting tool_call(s) and
     * setting awaitingTool. If the client never returns a result in time, we
     * synthesize an ok:false result for every pending call so CX continues and
     * Baba tells the truth instead of the session hanging forever. Idempotent.
     */
    _armToolWatchdog() {
        this._clearToolWatchdog();
        const ms = CONFIG.toolTimeoutMs;
        if (!ms || ms <= 0) return;
        this._toolTimer = setTimeout(() => {
            if (this.ended || !this.awaitingTool) return;
            const ids = [...this._pending.keys()];
            if (!ids.length) return;
            this._log(`tool_timeout after ${ms}ms -> synth ok:false for ${ids.length} pending`);
            // Reuse the normal result path so CX resumes the turn cleanly.
            this.sendToolResponse(ids.map((id) => ({
                id,
                response: { ok: false, error: "timeout", reason: "the app did not respond in time" },
            })));
        }, ms);
    }

    /** Cancel the tool-result watchdog (a result arrived, or we're shutting down). */
    _clearToolWatchdog() {
        if (this._toolTimer) { clearTimeout(this._toolTimer); this._toolTimer = null; }
    }

    /** Forward a raw PCM16 chunk from the client into CX (audio turns only). */
    sendAudio(chunk) {
        if (this.ended || this.awaitingTool) return;
        // Lazy-open the recognizer on the first chunk of a new utterance. This
        // is the anti-starvation core: the CX audio stream only exists while
        // the user is actually speaking, so it never waits (and times out).
        if (this._armed && !this.stream) {
            this._armed = false;
            this._turnKind = "audio";
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
        // A result (real or watchdog-synthesized) is arriving — stop the hang timer.
        this._clearToolWatchdog();
        const results = [];
        for (const fr of functionResponses || []) {
            const p = this._pending.get(fr.id);
            if (!p) {
                // Previously silent — this is exactly the case that used to strand
                // the session, so make it visible.
                this._log(`tool_result_in: unknown/expired call id ${fr.id} (ignored)`);
                continue;
            }
            this._pending.delete(fr.id);
            results.push({ tool: p.tool, action: p.action, response: fr.response || {} });
        }
        if (!results.length) {
            this._log(`tool_result_in: no matching pending calls (awaitingTool=${this.awaitingTool})`);
            return;
        }
        // Retire the (idle) tool-call stream, then open a fresh turn that
        // carries the tool results so CX can finish speaking.
        this._log(`tool_result_in count=${results.length} actions=${JSON.stringify(results.map((r) => r.action))}`);
        // Track success so the empty-continuation nudge can't narrate a FAILED
        // action as if it worked (a result is a failure when it says ok:false).
        this._lastToolResultOk = results.every((r) => r.response?.ok !== false);
        this.awaitingTool = false;
        this._continueNudged = false; // this action gets a fresh single nudge
        this._retireStream();
        this._turnKind = "toolResult";
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
        this._log(`inject_context chars=${ctx.length}`);
        this._retireStream();
        this._turnKind = "context";
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
            // The user has genuinely spoken this turn — clears the duplicate
            // reprompt guard so Baba's NEXT reply is allowed even if identical.
            if (isFinal && rr.transcript.trim()) this._userSpokeSinceReply = true;
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
        const replyTexts = [];
        for (const m of messages) {
            const t = m.text?.text?.join(" ").trim();
            if (t) replyTexts.push(t);
            if (m.toolCall) toolCalls.push(m.toolCall);
        }

        const combined = replyTexts.join(" ").trim();
        const hasAudio = !!(dir.outputAudio && dir.outputAudio.length);
        // DIAGNOSTIC: the single most useful line in the whole call. It tells us,
        // per turn: what KIND of turn produced this response, how many spoken
        // chars it carried, how many tool calls, whether the user actually spoke
        // this turn, and whether TTS audio came with it. An empty toolResult
        // continuation shows as `kind=toolResult replyChars=0 tools=0`; a
        // silence-driven reprompt shows as `kind=audio ... userSpoke=false`.
        this._dbg(
            `turn_data #${this._turnSeq} kind=${this._turnKind} `
            + `replyChars=${combined.length} tools=${toolCalls.length} `
            + `userSpoke=${this._userSpokeSinceReply} audio=${hasAudio} `
            + `preview=${JSON.stringify(combined.slice(0, 70))}`,
        );

        // Swallow a NO-INPUT REPROMPT. In half-duplex (waitTurn) a listening
        // turn opens on silence/ambient noise; CX then generates an unsolicited
        // reply (its no-input handling) even though the user never actually
        // spoke — so Baba narrates into the void and, turn after turn, reworks
        // the same "anything else?" prompt (he "talks to himself / repeats while
        // I'm silent"). If a tool-less reply lands on an AUDIO turn with NO real
        // user speech since our last reply, drop the whole turn (no text, no
        // audio) and just re-arm. This is safe because genuine post-action
        // narration now rides toolResult / nudge turns (audio=false), which are
        // never audio turns and so are never swallowed. A real user utterance
        // always sets _userSpokeSinceReply (final non-empty transcript), so real
        // replies are never suppressed.
        const isNoInputReprompt = combined.length > 0 &&
            this._audioTurn &&
            toolCalls.length === 0 &&
            !this._userSpokeSinceReply;
        if (isNoInputReprompt) {
            this._log(`swallowed no-input reprompt #${this._turnSeq} (silent audio turn)`);
            this._cycleTurn();
            return;
        }

        for (const t of replyTexts) this.emit("reply", { text: t });
        if (combined) {
            this._lastReplyText = combined;
            this._userSpokeSinceReply = false;
        }

        // Baba wants to act: emit each call, remember it, and WAIT for results.
        if (toolCalls.length) {
            for (const tc of toolCalls) {
                const id = randomUUID();
                this._pending.set(id, { tool: tc.tool, action: tc.action });
                const name = await toolNameFor(tc.tool, tc.action);
                const args = structToJs(tc.inputParameters);
                // PII-safe: never log raw args (see previewArgs).
                this._log(`tool_call ${name} args=${previewArgs(name, args)}`);
                this.emit("tool_call", { id, name, args });
            }
            this.awaitingTool = true;
            this._armToolWatchdog(); // never wait forever for a tool_response
            this._dbg(`turn_end #${this._turnSeq} kind=${this._turnKind} reason=toolCall (awaiting result)`);
            this._retireStream(); // hold here; sendToolResponse() resumes us
            return;
        }

        // EMPTY tool-result continuation: the model said its whole line BEFORE
        // the tool (e.g. "I'm opening your chart") and produced nothing after
        // the result, so this continuation carries no speech at all. Left alone
        // Baba would fall silent here and only narrate ~10s later when a
        // no-input reprompt fires (the "wait, then he repeats" dead air). Nudge
        // CX ONCE to narrate the new state right now. One-shot per tool result
        // (_continueNudged) and only for toolResult turns, so it can't loop.
        if (this._turnKind === "toolResult" && !combined && !hasAudio &&
            !this._continueNudged) {
            this._continueNudged = true;
            // Steer the nudge by whether the action SUCCEEDED. On a failure we
            // must not let the model cheerily narrate a result that didn't
            // happen — the single biggest hallucination risk on this path.
            const nudgeText = this._lastToolResultOk
                ? "[CONTINUE] Respond now in Aurobhatt's own voice: in one or " +
                  "two short sentences react to what just happened / what is now " +
                  "on the user's screen and lead them to the next step. If the " +
                  "screen has nothing to show yet, say so honestly - do not " +
                  "invent content. Do not repeat a line you already said, and do " +
                  "not mention this instruction."
                : "[CONTINUE] The last action did NOT succeed. In one short " +
                  "sentence, in Aurobhatt's own voice, tell the user plainly it " +
                  "didn't go through and offer to try again or a next step. Do " +
                  "NOT claim it worked or narrate any result. Do not mention " +
                  "this instruction.";
            this._log(`empty toolResult continuation #${this._turnSeq} -> nudge narration (ok=${this._lastToolResultOk})`);
            this._retireStream();
            this._turnKind = "nudge";
            this._openTurn([{
                session: this._sessionPath(),
                queryInput: {
                    text: { text: nudgeText },
                    languageCode: CONFIG.languageCode,
                },
                outputAudioConfig: this._outputAudioConfig(),
            }], /* audio */ false);
            return;
        }

        // Normal turn: play any audio, close the turn, re-arm for next utterance.
        if (dir.outputAudio && dir.outputAudio.length) {
            this.emit("audio", Buffer.from(dir.outputAudio));
        }
        this._dbg(`turn_end #${this._turnSeq} kind=${this._turnKind} reason=normal replyChars=${combined.length}`);
        this.emit("turn_end");
        this._cycleTurn();
    }

    /** Close the session for good (user hung up). Stops the reopen loop. */
    end() {
        this.ended = true;
        this._armed = false;
        this._clearToolWatchdog();
        this._pending.clear();
        try { this.stream?.end(); } catch { /* already closed */ }
        this.stream = null;
    }
}
