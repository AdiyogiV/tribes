# AI Chat Logs Consolidated

Generated: 2026-06-18

## Source Files (Raw Command Outputs)

- `/Users/a0v0hxf/.cursor/projects/Users-a0v0hxf-local-AG-tribes/agent-tools/b2a8faf7-aee2-4971-812e-cc79f759a21d.txt` (full `firebase functions:log -n 200 --project ty-dev-516d7`)
- `/Users/a0v0hxf/.cursor/projects/Users-a0v0hxf-local-AG-tribes/agent-tools/5c237382-c418-4fcf-9bd3-2629abe1418f.txt` (trimmed/working extract)

## Log Volume Snapshot (Top Functions)

- `aichat`: 69
- `socialgateway`: 28
- `astrogateway`: 16
- `insightgateway`: 13
- others: low frequency (mostly 2 entries each in sampled range)

## Notable Findings

- `aichat` handled both text and audio successfully in sampled logs.
- Audio flow includes `Audio downloaded` and completes with `Performance: Complete request metrics`.
- Ashtakavarga appeared in runtime logs with canonical total:
  - `📊 Ashtakavarga calculated`
  - `savTotal: 337`, `hasBav: 7`
- App Check warnings repeated in `socialgateway` and `astrogateway`:
  - `Failed to validate AppCheck token...`
  - then `Allowing request with invalid AppCheck token because enforcement is disabled`
- Vertex AI SDK deprecation warning appears in `aichat` logs (migration to `@google/genai` pending).

## AI Chat Performance Extraction

Filter used: `"Performance: Complete request metrics"` from `aichat` entries.

Count: `7`

### Per-request lines

1. `chat-1781722174727 | text | prompt=1573 | cand=130 | total_ms=3301 | ttft_ms=2443 | search=True`
2. `chat-1781722174727 | text | prompt=1709 | cand=131 | total_ms=3114 | ttft_ms=2178 | search=True`
3. `chat-1781722213937 | audio | prompt=1761 | cand=164 | total_ms=6217 | ttft_ms=4950 | search=True`
4. `chat-1781729856193 | audio | prompt=2337 | cand=136 | total_ms=6580 | ttft_ms=5127 | search=True`
5. `chat-1781729983491 | audio | prompt=2262 | cand=140 | total_ms=7084 | ttft_ms=6223 | search=True`
6. `loaded-ai_chat_i6RGCDiUcjb7Gcl8QImnafj0quA3_1781729986029 | audio | prompt=2527 | cand=414 | total_ms=8221 | ttft_ms=5013 | search=True`
7. `loaded-ai_chat_i6RGCDiUcjb7Gcl8QImnafj0quA3_1781729986029 | audio | prompt=2841 | cand=31 | total_ms=4191 | ttft_ms=4162 | search=True`

### Averages

- `promptTokens`: `2144.3`
- `candidatesTokens`: `163.7`
- `total_ms`: `5529.7`
- `ttft_ms`: `4299.4`
- `usedSearch`: `true` for all extracted rows

## Commands Used

```bash
firebase functions:log -n 200 --project ty-dev-516d7
rg "Performance: Complete request metrics" "<raw_output_file>"
python3 <parser for aichat performance metrics>
```
