#!/usr/bin/env bash
set -euo pipefail

AGENT_KEY="my-research-assistant"
BASE_URL="https://my.orq.ai/v2/agents/${AGENT_KEY}/responses"

if [ -z "${ORQ_API_KEY:-}" ]; then
  echo "ERROR: ORQ_API_KEY is not set"
  echo '  export ORQ_API_KEY="your-api-key"'
  exit 1
fi

QUESTIONS=(
  "What is Anthropic's latest funding round? Include amount raised, valuation, lead investors, and date."
  "Compare Claude Sonnet 4.5 vs GPT-5 vs Gemini 2.5 Pro on pricing, context window, and benchmarks."
  "What are the 3 most significant AI regulation developments in the EU and US in the past 30 days?"
  "What is the current world record for speedrunning Celeste any%? Include exact time, runner, date, and platform."
  "1) What is CRISPR-Cas9? 2) Who won the Nobel Prize for it? 3) What are the most recent FDA-approved CRISPR therapies?"
  "What is NVIDIA's current market cap, trailing P/E ratio, and YTD stock performance in 2026?"
  "What were the key findings from the most recent IPCC climate report? Include report name and publication date."
  "What is the current status of the Russia-Ukraine conflict? Include recent ceasefire proposals and positions of US, EU, China."
  "What are the top 3 highest-grossing films worldwide so far in 2026? Include title, gross, director, release date."
  "What are the 3 most well-funded nuclear fusion startups as of 2026? Include funding, reactor design, and timeline."
)

LABELS=(
  "Single company"
  "Comparison"
  "Current events"
  "Edge case (niche)"
  "Multi-part"
  "Financial/market"
  "Scientific/technical"
  "Geopolitical"
  "Pop culture"
  "Startup/emerging tech"
)

TOTAL=${#QUESTIONS[@]}
echo "Agent:     ${AGENT_KEY}"
echo "Endpoint:  ${BASE_URL}"
echo "Questions: ${TOTAL}"
echo "========================================"

for i in "${!QUESTIONS[@]}"; do
  NUM=$((i + 1))
  QUESTION="${QUESTIONS[$i]}"
  LABEL="${LABELS[$i]}"

  echo ""
  echo "[${NUM}/${TOTAL}] ${LABEL}"
  echo "Q: ${QUESTION:0:120}"
  echo "----------------------------------------"

  START=$(date +%s)

  RESPONSE=$(curl -s --request POST \
    --url "${BASE_URL}" \
    --header "Authorization: Bearer ${ORQ_API_KEY}" \
    --header "Content-Type: application/json" \
    --data "$(cat <<EOF
{
  "message": {
    "role": "user",
    "parts": [{"kind": "text", "text": "${QUESTION}"}]
  }
}
EOF
)")

  END=$(date +%s)
  ELAPSED=$((END - START))

  # Extract text from response
  TEXT=$(echo "${RESPONSE}" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    output = data.get('output', [])
    if isinstance(output, list):
        for msg in output:
            for part in msg.get('parts', []):
                if part.get('kind') == 'text':
                    print(part['text'][:300])
                    break
            break
    elif isinstance(output, dict):
        for part in output.get('parts', []):
            if part.get('kind') == 'text':
                print(part['text'][:300])
                break
except:
    print('[parse error]')
" 2>/dev/null || echo "[parse error]")

  # Extract usage
  USAGE=$(echo "${RESPONSE}" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    u = data.get('usage', {})
    inp = u.get('prompt_tokens', u.get('input_tokens', '?'))
    out = u.get('completion_tokens', u.get('output_tokens', '?'))
    print(f'in={inp} out={out}')
except:
    print('n/a')
" 2>/dev/null || echo "n/a")

  echo "Time:   ${ELAPSED}s"
  echo "Tokens: ${USAGE}"
  echo "Answer: ${TEXT:0:300}"
done

echo ""
echo "========================================"
echo "Done."
