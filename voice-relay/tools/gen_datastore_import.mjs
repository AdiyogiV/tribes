// Build a Discovery Engine inline-import payload from the curated canon, so the
// SAME asset feeds either the local tool OR the native CX data store (one source
// of truth). No network here - just writes /tmp/baba_import.json.
import { readFileSync, writeFileSync } from "node:fs";

const canon = JSON.parse(readFileSync("assets/baba/knowledge.json", "utf8"));
const documents = canon.entries.map((e) => {
  const aliases = (e.aliases || []).join(", ");
  const text =
    `${e.title}\n\n${e.summary}\n\n` +
    `Category: ${e.category}. Also known as: ${aliases}.`;
  return {
    id: e.id,
    // structData = filterable/citable metadata; content = the retrievable text.
    structData: { title: e.title, category: e.category },
    content: {
      mimeType: "text/plain",
      rawBytes: Buffer.from(text, "utf8").toString("base64"),
    },
  };
});

const payload = { inlineSource: { documents }, reconciliationMode: "INCREMENTAL" };
writeFileSync("/tmp/baba_import.json", JSON.stringify(payload));
console.log(`wrote /tmp/baba_import.json with ${documents.length} documents`);
