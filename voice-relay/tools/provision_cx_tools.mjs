/**
 * Provision Baba's CX Function tools + attach them to the Aryabhatt playbook.
 *
 * Idempotent: safe to run repeatedly. Creates any missing tool, updates the
 * schema of existing ones (matched by displayName), then points the playbook's
 * referencedTools at all of them and appends the tool-usage guidelines.
 *
 * Auth: uses the gcloud CLI identity via REST (NOT the runtime SA, which is
 * deliberately least-privilege and can't manage tools). This is a one-time
 * ADMIN action, appropriately run as a project owner/editor.
 *
 * Usage:
 *   cd voice-relay
 *   ACCESS_TOKEN=$(gcloud auth print-access-token) \
 *     CX_AGENT_ID=<id> node tools/provision_cx_tools.mjs
 */

import {
  BABA_TOOL_SPECS,
  BABA_TOOL_GUIDELINES,
  BABA_STEPS,
  BABA_GOAL,
  MANAGED_MARKER,
} from "../src/cx_tools.js";

const PROJECT = process.env.GCP_PROJECT || "ty-dev-516d7";
const LOCATION = process.env.CX_LOCATION || "global";
const AGENT_ID =
  process.env.CX_AGENT_ID || "58d722c1-df7d-41d9-8a92-85d88feeda81";
const PLAYBOOK_NAME = process.env.CX_PLAYBOOK || "Aryabhatt";
const TOKEN = process.env.ACCESS_TOKEN;

if (!TOKEN) {
  console.error(
    "Missing ACCESS_TOKEN. Run:\n" +
      "  ACCESS_TOKEN=$(gcloud auth print-access-token) node tools/provision_cx_tools.mjs",
  );
  process.exit(1);
}

const HOST =
  LOCATION === "global"
    ? "https://dialogflow.googleapis.com"
    : `https://${LOCATION}-dialogflow.googleapis.com`;
const BASE = `${HOST}/v3beta1/projects/${PROJECT}/locations/${LOCATION}/agents/${AGENT_ID}`;
const HEADERS = {
  Authorization: `Bearer ${TOKEN}`,
  "x-goog-user-project": PROJECT,
  "Content-Type": "application/json",
};

async function api(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: HEADERS,
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(
      `${method} ${url.replace(BASE, "")} -> ${res.status}: ${json?.error?.message || JSON.stringify(json)}`,
    );
  }
  return json;
}

async function upsertTool(spec, existing) {
  const match = existing.find((t) => t.displayName === spec.name);
  const body = {
    displayName: spec.name,
    description: spec.description,
    functionSpec: { inputSchema: spec.inputSchema },
  };
  if (match) {
    const updated = await api(
      "PATCH",
      `${HOST}/v3beta1/${match.name}?updateMask=description,functionSpec`,
      body,
    );
    console.log(`  updated  ${spec.name}`);
    return updated.name;
  }
  const created = await api("POST", `${BASE}/tools`, body);
  console.log(`  created  ${spec.name}`);
  return created.name;
}

async function main() {
  console.log(`Provisioning ${BABA_TOOL_SPECS.length} tools on agent ${AGENT_ID}`);
  const listed = await api("GET", `${BASE}/tools`);
  const existing = listed.tools || [];
  const names = [];
  for (const spec of BABA_TOOL_SPECS) names.push(await upsertTool(spec, existing));

  // Also keep any DATA STORE tools (native CX RAG, e.g. vedicCanon) attached.
  // They aren't function specs, so they're managed outside BABA_TOOL_SPECS -
  // but they MUST stay in referencedTools or the playbook loses grounding.
  const dataStoreTools = existing.filter((t) => t.dataStoreSpec);
  for (const t of dataStoreTools) {
    names.push(t.name);
    console.log(`  keeping  ${t.displayName} (data store)`);
  }

  // Grounding assertion. The playbook now HARD-depends on the vedicCanon data
  // store for every interpretive meaning (see BABA_STEPS reading law). If it
  // isn't attached, Baba silently falls back to memory and hallucinates - so
  // fail loudly here rather than shipping a subtly-ungrounded agent. Set
  // ALLOW_MISSING_CANON=true to override (e.g. first-time bring-up before the
  // datastore is provisioned via provision_cx_datastore.sh).
  const hasCanon = dataStoreTools.some((t) => /canon/i.test(t.displayName || ""));
  if (!hasCanon) {
    const msg =
      "vedicCanon data store tool is NOT attached to this agent. The playbook " +
      "requires it for interpretive meanings; without it Baba hallucinates. " +
      "Provision it (provision_cx_datastore.sh) or set ALLOW_MISSING_CANON=true.";
    if (process.env.ALLOW_MISSING_CANON === "true") {
      console.warn(`  WARNING: ${msg}`);
    } else {
      throw new Error(msg);
    }
  }

  console.log(`Attaching to playbook "${PLAYBOOK_NAME}"...`);
  const pbList = await api("GET", `${BASE}/playbooks`);
  const pb = (pbList.playbooks || []).find((p) => p.displayName === PLAYBOOK_NAME);
  if (!pb) throw new Error(`Playbook "${PLAYBOOK_NAME}" not found`);

  // We fully own instruction.guidelines now, so REPLACE it wholesale with our
  // managed string (which begins with MANAGED_MARKER). This is the fix for the
  // doubling bug: the old code appended BABA_TOOL_GUIDELINES onto whatever was
  // already there via a marker ("## Language") that no longer existed in the
  // guidelines, so every run tacked on another full copy until the guidelines
  // hit ~28k chars and the playbook blew CX's 8192-token limit (2026-07-18).
  //
  // Self-healing: if any stray console text somehow precedes our marker, keep
  // only what's before it (there is none in practice) and drop everything from
  // the marker onward, then re-append our fresh copy - so re-runs stay 1x.
  const currentGuidelines = pb.instruction?.guidelines || "";
  const markerIdx = currentGuidelines.indexOf(MANAGED_MARKER);
  const preamble =
    markerIdx > 0 ? currentGuidelines.slice(0, markerIdx).trimEnd() + "\n" : "";
  const guidelines = preamble + BABA_TOOL_GUIDELINES;
  // We now ALSO own the STEPS (persona + top-priority laws) - they are the
  // model-primary instruction, so keeping them in code is the only way to stop
  // the console copy drifting and contradicting the guidelines (which is how
  // Baba ended up with 'always give a reading / confident answer without birth
  // details' fighting the truth rules and fabricating charts, 2026-07-18).
  const steps = BABA_STEPS.map((text) => ({ text }));

  const updated = await api(
    "PATCH",
    // Use PRECISE sub-field masks. NEVER mask the bare `instruction` parent: a
    // parent mask makes proto3 APPEND the repeated `instruction.steps` on every
    // run (merge semantics), duplicating the persona until CX's 8192-token
    // playbook limit blows and every call dies with {type:error} (bit us twice,
    // 2026-07-13/14). Masking `instruction.steps` DIRECTLY (a leaf repeated
    // field) REPLACES it wholesale - which is exactly what we want. `goal` is a
    // scalar, so masking it just overwrites - we own it here now that the old
    // set_playbook.mjs (which carried a stale steps copy) is gone (2026-07-18).
    `${HOST}/v3beta1/${pb.name}?updateMask=goal,referencedTools,instruction.guidelines,instruction.steps`,
    {
      goal: BABA_GOAL,
      referencedTools: names,
      instruction: { guidelines, steps },
    },
  );
  console.log(
    `  playbook now references ${updated.referencedTools?.length || 0} tools`,
  );
  console.log("Done. CX can now call Baba's tools.");
}

main().catch((err) => {
  console.error("Provisioning failed:", err?.message || err);
  process.exit(1);
});
