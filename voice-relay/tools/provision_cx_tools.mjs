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

import { BABA_TOOL_SPECS, BABA_TOOL_GUIDELINES } from "../src/cx_tools.js";

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

  console.log(`Attaching to playbook "${PLAYBOOK_NAME}"...`);
  const pbList = await api("GET", `${BASE}/playbooks`);
  const pb = (pbList.playbooks || []).find((p) => p.displayName === PLAYBOOK_NAME);
  if (!pb) throw new Error(`Playbook "${PLAYBOOK_NAME}" not found`);

  const currentGuidelines = pb.instruction?.guidelines || "";
  const marker = "## Acting on the app (tools)";
  const guidelines = currentGuidelines.includes(marker)
    ? currentGuidelines
    : currentGuidelines + "\n" + BABA_TOOL_GUIDELINES;

  const updated = await api(
    "PATCH",
    `${HOST}/v3beta1/${pb.name}?updateMask=referencedTools,instruction`,
    {
      referencedTools: names,
      instruction: { ...(pb.instruction || {}), guidelines },
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
