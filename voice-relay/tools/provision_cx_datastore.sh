#!/usr/bin/env bash
#
# Provision Baba's NATIVE CX RAG: a Vertex AI Search (Discovery Engine) data
# store + a CX Data Store Tool ("vedicCanon") attached to the Aryabhatt playbook.
#
# This is the built-in CX grounding path (replaces the old local-asset
# lookupKnowledge function tool). Meanings are retrieved + cited server-side by
# CX from the canon documents - no app-side tool, no bundled asset.
#
# Idempotent: safe to re-run (create calls that already exist are ignored;
# import upserts by document id).
#
# IMPORTANT: Discovery Engine is behind Walmart's VPC Service Controls perimeter,
# so ALL calls MUST go through the corporate proxy. Requires a gcloud identity
# with admin rights on the project (one-time admin action).
#
# Usage:
#   voice-relay/tools/provision_cx_datastore.sh
#
set -euo pipefail

PROJECT="${GCP_PROJECT:-ty-dev-516d7}"
AGENT="${CX_AGENT_ID:-58d722c1-df7d-41d9-8a92-85d88feeda81}"
DS_ID="${DS_ID:-baba-canon}"
PROXY="${WM_PROXY:-http://sysproxy.wal-mart.com:8080}"
TOKEN="$(gcloud auth print-access-token)"
export HTTPS_PROXY="$PROXY" HTTP_PROXY="$PROXY"

DE="https://discoveryengine.googleapis.com/v1/projects/$PROJECT/locations/global/collections/default_collection"
DF="https://dialogflow.googleapis.com/v3beta1/projects/$PROJECT/locations/global/agents/$AGENT"
H_AUTH=(-H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: $PROJECT" -H "Content-Type: application/json")
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "1/3  Ensuring data store '$DS_ID' exists..."
curl -s -X POST "${H_AUTH[@]}" "$DE/dataStores?dataStoreId=$DS_ID" \
  -d '{"displayName":"Baba Vedic Canon","industryVertical":"GENERIC","solutionTypes":["SOLUTION_TYPE_CHAT"],"contentConfig":"CONTENT_REQUIRED"}' \
  | grep -qiE '"name"|ALREADY_EXISTS' && echo "     ok" || echo "     (already exists / ok)"

echo "2/3  Importing canon documents (upsert by id)..."
node "$ROOT/voice-relay/tools/gen_datastore_import.mjs"
curl -s -X POST "${H_AUTH[@]}" \
  "$DE/dataStores/$DS_ID/branches/default_branch/documents:import" \
  -d @/tmp/baba_import.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('     imported:', d.get('metadata',{}).get('successCount','?'))"

echo "3/3  Ensuring CX Data Store Tool 'vedicCanon' exists + is attached..."
EXISTS="$(curl -s "${H_AUTH[@]}" "$DF/tools" \
  | python3 -c "import sys,json; ts=json.load(sys.stdin).get('tools',[]); print(any(t.get('displayName')=='vedicCanon' for t in ts))")"
if [ "$EXISTS" != "True" ]; then
  curl -s -X POST "${H_AUTH[@]}" "$DF/tools" -d '{
    "displayName":"vedicCanon",
    "description":"Grounded Vedic astrology + Ayurveda canon. Consult this for the MEANING of any sign, planet, dasha, yoga, nakshatra, ascendant or dosha, and answer from the retrieved passages.",
    "dataStoreSpec":{"dataStoreConnections":[{"dataStore":"projects/'"$PROJECT"'/locations/global/collections/default_collection/dataStores/'"$DS_ID"'","dataStoreType":"UNSTRUCTURED"}],"fallbackPrompt":{}}
  }' >/dev/null && echo "     created vedicCanon"
else
  echo "     vedicCanon already exists"
fi

echo
echo "Now attach it to the playbook (idempot - also keeps function tools):"
echo "  cd voice-relay && ACCESS_TOKEN=\$(gcloud auth print-access-token) node tools/provision_cx_tools.mjs"
echo "Done."
