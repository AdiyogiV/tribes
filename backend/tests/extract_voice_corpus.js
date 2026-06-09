/**
 * VOICE + FULL CORPUS EXTRACTOR (resumable).
 *
 * Walks every HolyCow AI conversation and pulls the COMPLETE message corpus:
 *   - user questions (text)
 *   - HolyCow answers (for answer-quality audit)
 *   - voice messages -> downloads audio, converts via ffmpeg, transcribes with
 *     local whisper-cli (free, private), with auto language detection.
 *
 * Resumable: caches downloads + transcripts on disk; safe to re-run.
 * Writes: analysis/corpus_full.csv  (every message, ordered, with transcript)
 *
 * Usage: node tests/extract_voice_corpus.js
 */
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from "fs";
import { execSync } from "child_process";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { homedir } from "os";

const __dirname = dirname(fileURLToPath(import.meta.url));
const sa = JSON.parse(readFileSync(join(__dirname, "../serviceAccountKey.json"), "utf8"));
initializeApp({ credential: cert(sa) });
const db = getFirestore();
const HOLYCOW = "holycow_system_user";

const OUT = join(__dirname, "../analysis");
const CACHE = join(OUT, "voice_cache");           // raw downloads
const TX = join(OUT, "transcripts");              // {messageId}.txt + .lang
for (const d of [OUT, CACHE, TX]) if (!existsSync(d)) mkdirSync(d, { recursive: true });

const MODEL = join(homedir(), "Downloads", "ggml-base-q5_1.bin");

const csvCell = (v) => {
  if (v === null || v === undefined) return "";
  const s = String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
const toMs = (ts) => ts?.toMillis ? ts.toMillis() : (ts?._seconds ? ts._seconds * 1000 : null);

async function download(url, dest) {
  if (existsSync(dest)) return true;
  try {
    execSync(`curl -sS -L --max-time 60 -o "${dest}" "${url}"`, { stdio: "ignore" });
    return existsSync(dest);
  } catch { return false; }
}

function transcribe(rawPath, messageId) {
  const txtPath = join(TX, `${messageId}.txt`);
  const langPath = join(TX, `${messageId}.lang`);
  if (existsSync(txtPath)) {
    return {
      text: readFileSync(txtPath, "utf8").trim(),
      lang: existsSync(langPath) ? readFileSync(langPath, "utf8").trim() : "",
    };
  }
  const wav = join(CACHE, `${messageId}_16k.wav`);
  try {
    execSync(`ffmpeg -y -i "${rawPath}" -ar 16000 -ac 1 -c:a pcm_s16le "${wav}" 2>/dev/null`, { stdio: "ignore" });
  } catch { return { text: "", lang: "ERR_FFMPEG" }; }
  let out = "";
  try {
    // -l auto = detect language; -nt = no timestamps; -oj writes json beside file
    out = execSync(
      `whisper-cli -m "${MODEL}" -f "${wav}" -l auto -nt 2>/tmp/whisper_stderr.txt`,
      { encoding: "utf8", maxBuffer: 1024 * 1024 * 8 }
    );
  } catch { return { text: "", lang: "ERR_WHISPER" }; }
  // language printed on stderr like: "whisper_full_with_state: auto-detected language: en (p = ...)"
  let lang = "";
  try {
    const err = readFileSync("/tmp/whisper_stderr.txt", "utf8");
    const m = err.match(/auto-detected language:\s*([a-z]{2})/i);
    if (m) lang = m[1];
  } catch {}
  const text = out.replace(/\s+/g, " ").trim();
  writeFileSync(txtPath, text, "utf8");
  writeFileSync(langPath, lang, "utf8");
  try { execSync(`rm -f "${wav}"`); } catch {}  // keep cache small; keep raw only
  return { text, lang };
}

async function main() {
  console.log("Loading AI conversations...");
  const dms = await db.collection("dmConversations").get();
  const aiIds = dms.docs.filter((d) => {
    const x = d.data();
    return x.isAiConversation === true ||
      (Array.isArray(x.participants) && x.participants.includes(HOLYCOW));
  }).map((d) => d.id);
  console.log(`${aiIds.length} AI conversations`);

  const rows = [];
  let voiceSeen = 0, voiceDone = 0, voiceFail = 0, ci = 0;
  for (const cid of aiIds) {
    const msgs = await db.collection("dmConversations").doc(cid)
      .collection("messages").get();
    const ordered = msgs.docs
      .map((m) => ({ id: m.id, ...m.data() }))
      .sort((a, b) => (toMs(a.timestamp) || 0) - (toMs(b.timestamp) || 0));
    let turn = 0;
    for (const m of ordered) {
      const isUser = m.senderId !== HOLYCOW;
      let content = (m.content || "").toString();
      let lang = "", source = isUser ? "text" : "ai";
      if (isUser && m.isVoiceMessage) {
        source = "voice";
        voiceSeen++;
        const url = m.audioUrl;
        if (url && url.startsWith("http")) {
          const raw = join(CACHE, `${m.id}.audio`);
          const ok = await download(url, raw);
          if (ok) {
            const r = transcribe(raw, m.id);
            if (r.text && !r.text.startsWith("ERR")) { content = r.text; lang = r.lang; voiceDone++; }
            else { content = "[voice: transcription failed]"; voiceFail++; }
          } else { content = "[voice: download failed]"; voiceFail++; }
        } else { content = "[voice: no url]"; voiceFail++; }
      }
      rows.push([
        cid, m.id, isUser ? (m.senderId || "") : HOLYCOW,
        source, ++turn, toMs(m.timestamp) ? new Date(toMs(m.timestamp)).toISOString() : "",
        lang, content.length, content,
      ]);
    }
    if (++ci % 25 === 0) console.log(`  ${ci}/${aiIds.length} convos | voice ${voiceDone}/${voiceSeen} ok, ${voiceFail} fail`);
  }

  const header = ["convo_id", "msg_id", "sender", "source", "turn", "timestamp", "lang", "char_len", "content"];
  const csv = [header.join(",")];
  for (const r of rows) csv.push(r.map(csvCell).join(","));
  writeFileSync(join(OUT, "corpus_full.csv"), csv.join("\n"), "utf8");
  console.log(`\n✓ corpus_full.csv (${rows.length} messages)`);
  console.log(`  voice: ${voiceSeen} seen, ${voiceDone} transcribed, ${voiceFail} failed`);
}

main().then(() => process.exit(0)).catch((e) => { console.error("ERR", e); process.exit(1); });
