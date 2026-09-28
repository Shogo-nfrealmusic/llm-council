#!/usr/bin/env bash
# external_advisor.sh — optional multi-model mode: ask a non-Claude model to answer as one advisor.
#
# Nothing here runs unless the user asked for it (--multi) AND configured a provider.
# It never installs anything. It sends only the neutral decision brief and the advisor instructions.
#
# usage: bash external_advisor.sh detect
#          prints one provider per line, or "none":
#            openrouter:<model>  for each model in LLM_COUNCIL_OPENROUTER_MODELS (needs OPENROUTER_API_KEY)
#            codex               if the `codex` CLI is on PATH (it uses its own login)
#            gemini              if the `gemini` CLI is on PATH (it uses its own login)
#        bash external_advisor.sh ask <provider> <angle> <language>   (decision brief on stdin)
#          prints "### MODEL: <provider>/<model>" and then the advisor answer; exits non-zero if the
#          provider fails or the answer is not in the advisor format (the caller then uses a Claude advisor).
#
# Testing without keys or network:
#   LLM_COUNCIL_EXTERNAL_DRY_RUN=1   print the request that would be sent (key redacted), send nothing
#   LLM_COUNCIL_EXTERNAL_MOCK=<file> use the file as the provider's raw reply instead of calling it
# Timeout per call: LLM_COUNCIL_EXTERNAL_TIMEOUT seconds (default 120).
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
AGENT="$HERE/../../../agents/council-advisor.md"
TIMEOUT="${LLM_COUNCIL_EXTERNAL_TIMEOUT:-120}"

die() { echo "external_advisor: $*" >&2; exit 1; }

detect() {
  found=0
  if [ -n "${OPENROUTER_API_KEY:-}" ] && [ -n "${LLM_COUNCIL_OPENROUTER_MODELS:-}" ]; then
    for m in $(printf '%s' "$LLM_COUNCIL_OPENROUTER_MODELS" | tr ',' ' '); do
      echo "openrouter:$m"; found=1
    done
  fi
  command -v codex >/dev/null 2>&1 && { echo "codex"; found=1; }
  command -v gemini >/dev/null 2>&1 && { echo "gemini"; found=1; }
  [ $found -eq 1 ] || echo "none"
}

# Run a command with a time limit (no GNU timeout on macOS).
with_timeout() { perl -e 'alarm shift; exec @ARGV' "$TIMEOUT" "$@"; }

ask() {
  provider="${1:-}"; angle="${2:-}"; lang="${3:-}"
  case "$angle" in contrarian|first-principles|expansionist|outsider|executor) ;; *) die "unknown angle: $angle" ;; esac
  [ -n "$lang" ] || die "language missing"
  [ -f "$AGENT" ] || die "advisor instructions not found: $AGENT"
  brief="$(cat)"
  [ -n "$(printf '%s' "$brief" | tr -d '[:space:]')" ] || die "empty decision brief on stdin"

  system="$(awk 'BEGIN{n=0} /^---$/{n++; if(n==2){f=1; next}} f' "$AGENT")"
  user="$(printf 'Angle: %s\nLanguage: %s\n\nDecision brief:\n%s\n' "$angle" "$lang" "$brief")"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  printf '%s' "$system" > "$tmp/system.txt"; printf '%s' "$user" > "$tmp/user.txt"

  case "$provider" in
    openrouter:*)
      model="${provider#openrouter:}"; label="openrouter/$model"
      [ -n "$model" ] || die "no model given"
      python3 - "$model" "$tmp" > "$tmp/body.json" <<'PY'
import json, sys
m, d = sys.argv[1], sys.argv[2]
print(json.dumps({"model": m, "messages": [
    {"role": "system", "content": open(d + "/system.txt").read()},
    {"role": "user", "content": open(d + "/user.txt").read()}]}, ensure_ascii=False, indent=1))
PY
      if [ -n "${LLM_COUNCIL_EXTERNAL_DRY_RUN:-}" ]; then
        echo "DRY RUN — would POST https://openrouter.ai/api/v1/chat/completions"
        echo "Authorization: Bearer <OPENROUTER_API_KEY, redacted>"
        cat "$tmp/body.json"; return 0
      fi
      if [ -n "${LLM_COUNCIL_EXTERNAL_MOCK:-}" ]; then cp "$LLM_COUNCIL_EXTERNAL_MOCK" "$tmp/raw"
      else
        [ -n "${OPENROUTER_API_KEY:-}" ] || die "OPENROUTER_API_KEY is not set; nothing sent"
        # Key goes in a header file, not on the command line (so it does not show in ps).
        printf 'Authorization: Bearer %s\n' "$OPENROUTER_API_KEY" > "$tmp/h"; chmod 600 "$tmp/h"
        curl -sS --max-time "$TIMEOUT" https://openrouter.ai/api/v1/chat/completions \
          -H @"$tmp/h" -H 'Content-Type: application/json' --data-binary @"$tmp/body.json" > "$tmp/raw" \
          || die "request to OpenRouter failed"
      fi
      answer="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["choices"][0]["message"]["content"])' "$tmp/raw" 2>/dev/null)" \
        || die "unexpected reply from OpenRouter: $(head -c 300 "$tmp/raw")"
      ;;
    codex)
      label="codex"
      prompt="$(printf '%s\n\n---\n\n%s' "$system" "$user")"
      if [ -n "${LLM_COUNCIL_EXTERNAL_DRY_RUN:-}" ]; then
        echo "DRY RUN — would run: codex exec --sandbox read-only --skip-git-repo-check --ephemeral -o <file> -   (prompt on stdin)"
        printf '%s\n' "$prompt"; return 0
      fi
      if [ -n "${LLM_COUNCIL_EXTERNAL_MOCK:-}" ]; then cp "$LLM_COUNCIL_EXTERNAL_MOCK" "$tmp/raw"
      else
        command -v codex >/dev/null 2>&1 || die "codex CLI not found"
        printf '%s' "$prompt" | (cd "$tmp" && with_timeout codex exec --sandbox read-only --skip-git-repo-check --ephemeral -o "$tmp/raw" - >/dev/null 2>"$tmp/err") \
          || die "codex failed: $(head -c 300 "$tmp/err")"
      fi
      answer="$(cat "$tmp/raw")"
      ;;
    gemini)
      label="gemini"
      prompt="$(printf '%s\n\n---\n\n%s' "$system" "$user")"
      if [ -n "${LLM_COUNCIL_EXTERNAL_DRY_RUN:-}" ]; then
        echo "DRY RUN — would run: gemini --output-format json -p 'Answer as instructed above.'   (prompt on stdin)"
        printf '%s\n' "$prompt"; return 0
      fi
      if [ -n "${LLM_COUNCIL_EXTERNAL_MOCK:-}" ]; then cp "$LLM_COUNCIL_EXTERNAL_MOCK" "$tmp/raw"
      else
        command -v gemini >/dev/null 2>&1 || die "gemini CLI not found"
        printf '%s' "$prompt" | (cd "$tmp" && with_timeout gemini --output-format json -p 'Answer as instructed above.' > "$tmp/raw" 2>"$tmp/err") \
          || die "gemini failed: $(head -c 300 "$tmp/err")"
      fi
      answer="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["response"])' "$tmp/raw" 2>/dev/null)" \
        || die "unexpected reply from gemini: $(head -c 300 "$tmp/raw")"
      ;;
    *) die "unknown provider: $provider (run: external_advisor.sh detect)" ;;
  esac

  # Only a well-formed advisor answer is passed on.
  printf '%s\n' "$answer" | grep -Eq '^\**POSITION:\**[[:space:]]*\**[[:space:]]*(GO|NO-GO|CHANGE)\b' \
    || die "answer from $label has no POSITION line; use the Claude advisor for this angle"
  echo "### MODEL: $label"
  printf '%s\n' "$answer" | grep -v '^=== ROLE:'
}

case "${1:-}" in
  detect) detect ;;
  ask) shift; ask "$@" ;;
  *) die "usage: external_advisor.sh detect | ask <provider> <angle> <language> < brief" ;;
esac
