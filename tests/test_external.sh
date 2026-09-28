#!/usr/bin/env bash
# Optional multi-model mode: external_advisor.sh, tested offline (no keys, no network, no CLIs needed).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
X="$HERE/../plugins/llm-council/skills/llm-council/scripts/external_advisor.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }
# A clean environment: no keys, and a PATH without codex/gemini.
mkdir -p "$T/bin"; for c in bash python3 curl cat sed awk tr mktemp rm printf grep head env dirname cp chmod perl; do p="$(command -v $c)" && ln -sf "$p" "$T/bin/$c"; done
clean() { env -i HOME="$T" PATH="$T/bin" "$@"; }
BRIEF='Decide whether to require 2FA for 12 accounts. Claim (untested): it slows people down.'

out="$(clean bash "$X" detect)"; [ "$out" = "none" ] && ok "detect: nothing configured -> none" || bad "detect: nothing configured -> none (got $out)"
out="$(clean OPENROUTER_API_KEY=sk-test bash "$X" detect)"; [ "$out" = "none" ] && ok "detect: key without models -> none (no guessed model names)" || bad "detect: key without models -> none (got $out)"
out="$(clean OPENROUTER_API_KEY=sk-test LLM_COUNCIL_OPENROUTER_MODELS=vendor/model-a,vendor/model-b bash "$X" detect)"
[ "$out" = $'openrouter:vendor/model-a\nopenrouter:vendor/model-b' ] && ok "detect: one line per configured OpenRouter model" || bad "detect: one line per configured OpenRouter model (got $out)"
printf '#!/bin/sh\n' > "$T/bin/gemini"; chmod +x "$T/bin/gemini"
out="$(clean bash "$X" detect)"; [ "$out" = "gemini" ] && ok "detect: gemini CLI on PATH" || bad "detect: gemini CLI on PATH (got $out)"
rm "$T/bin/gemini"

# Dry run: shows the request, never sends, never prints the key.
out="$(printf '%s' "$BRIEF" | clean OPENROUTER_API_KEY=sk-SECRET LLM_COUNCIL_EXTERNAL_DRY_RUN=1 bash "$X" ask openrouter:vendor/model-a contrarian en)"; rc=$?
[ $rc -eq 0 ] && ok "dry run exits 0" || bad "dry run exits 0 ($rc)"
echo "$out" | grep -q 'sk-SECRET' && bad "dry run hides the API key" || ok "dry run hides the API key"
echo "$out" | grep -q '"model": "vendor/model-a"' && ok "dry run request names the model" || bad "dry run request names the model"
echo "$out" | grep -q 'Angle: contrarian' && echo "$out" | grep -q 'Claim (untested)' && ok "request carries the angle and the brief" || bad "request carries the angle and the brief"
echo "$out" | grep -q 'AGAINST MY POSITION' && ok "request carries the council-advisor instructions" || bad "request carries the council-advisor instructions"

# Mock responses in each provider's raw format come back as a checked advisor answer.
ANS='POSITION: GO — Require it.
CONFIDENCE: 80%
REASONS:
- Cheap.
AGAINST MY POSITION: Friction.
KEY POINT OTHERS WILL MISS: Passkeys.'
python3 -c 'import json,sys;print(json.dumps({"choices":[{"message":{"content":sys.argv[1]}}]}))' "$ANS" > "$T/or.json"
out="$(printf '%s' "$BRIEF" | clean OPENROUTER_API_KEY=k LLM_COUNCIL_EXTERNAL_MOCK="$T/or.json" bash "$X" ask openrouter:vendor/model-a contrarian en)"
echo "$out" | head -1 | grep -qx '### MODEL: openrouter/vendor/model-a' && echo "$out" | grep -q '^POSITION: GO' && ok "openrouter mock -> MODEL line + answer" || bad "openrouter mock -> MODEL line + answer ($out)"
python3 -c 'import json,sys;print(json.dumps({"response":sys.argv[1]}))' "$ANS" > "$T/gem.json"
out="$(printf '%s' "$BRIEF" | clean LLM_COUNCIL_EXTERNAL_MOCK="$T/gem.json" bash "$X" ask gemini outsider en)"
echo "$out" | grep -q '^POSITION: GO' && ok "gemini mock -> answer" || bad "gemini mock -> answer ($out)"
printf '%s\n' "$ANS" > "$T/codex.txt"
out="$(printf '%s' "$BRIEF" | clean LLM_COUNCIL_EXTERNAL_MOCK="$T/codex.txt" bash "$X" ask codex first-principles en)"
echo "$out" | grep -q '^POSITION: GO' && ok "codex mock -> answer" || bad "codex mock -> answer ($out)"

# Bad input fails loudly (so the clerk falls back to the Claude advisor).
printf 'I think you should probably do it.' > "$T/bad.txt"
printf '%s' "$BRIEF" | clean LLM_COUNCIL_EXTERNAL_MOCK="$T/bad.txt" bash "$X" ask codex executor en >/dev/null 2>&1; [ $? -ne 0 ] && ok "answer without POSITION line -> non-zero exit" || bad "answer without POSITION line -> non-zero exit"
printf '%s' "$BRIEF" | clean bash "$X" ask openrouter:vendor/model-a contrarian en >/dev/null 2>&1; [ $? -ne 0 ] && ok "no key -> non-zero exit, nothing sent" || bad "no key -> non-zero exit, nothing sent"
printf '%s' "$BRIEF" | clean OPENROUTER_API_KEY=k LLM_COUNCIL_EXTERNAL_DRY_RUN=1 bash "$X" ask openrouter:m wizard en >/dev/null 2>&1; [ $? -ne 0 ] && ok "unknown angle -> non-zero exit" || bad "unknown angle -> non-zero exit"
printf '' | clean OPENROUTER_API_KEY=k LLM_COUNCIL_EXTERNAL_DRY_RUN=1 bash "$X" ask openrouter:m contrarian en >/dev/null 2>&1; [ $? -ne 0 ] && ok "empty brief -> non-zero exit" || bad "empty brief -> non-zero exit"

SK="$HERE/../plugins/llm-council/skills/llm-council/SKILL.md"
head -8 "$SK" | grep -q 'scripts/external_advisor.sh' && ok "allowed-tools pre-approves external_advisor.sh" || bad "allowed-tools pre-approves external_advisor.sh"
grep -q -- '--multi' "$SK" && ok "SKILL.md documents --multi" || bad "SKILL.md documents --multi"
echo "passed: $PASS  failed: $FAIL"
[ $FAIL -eq 0 ]
