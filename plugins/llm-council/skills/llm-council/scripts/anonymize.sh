#!/usr/bin/env bash
# anonymize.sh — shuffle the advisor answers and relabel them A, B, C, ...
#
# usage: bash anonymize.sh [EXPECTED_COUNT] < answers
#   EXPECTED_COUNT: how many answers the caller sent (2-6, default 5).
#                   Quick mode sends 3, standard 5, standard + red team 6.
#
# stdin: blocks, each starting with a line "=== ROLE: <role> ==="
# stdout:
#   ### KEY (private — never show to reviewers)
#   A = <role>
#   ...
#   ### PACKET FILE: <absolute path>
# The packet file holds "=== ANSWER A ===" blocks with persona self-references
# masked. It lives in ./.llm-council-work/run.XXXXXX/ (git-ignored); save_notes.sh
# removes it at the end.
#
# The order comes from bash $RANDOM (Fisher–Yates), not from an LLM's idea of
# "shuffled". Works on the bash 3.2 that ships with macOS.
set -eu

expected="${1:-5}"
case "$expected" in
  2|3|4|5|6) ;;
  *) echo "anonymize.sh: expected count must be 2-6, got '$expected'" >&2; exit 2 ;;
esac

roles=()
bodies=()
idx=-1
cr="$(printf '\r')"
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%"$cr"}"
  case "$line" in
    "=== ROLE: "*" ===")
      idx=$((idx + 1))
      r="${line#=== ROLE: }"
      roles[$idx]="${r% ===}"
      bodies[$idx]=""
      ;;
    *)
      if [ $idx -ge 0 ]; then
        # Answer text must not be able to fake a packet boundary.
        case "$line" in "==="*|"###"*) line="  ${line}" ;; esac
        bodies[$idx]="${bodies[$idx]}${line}
"
      fi
      ;;
  esac
done

n=$((idx + 1))
if [ "$n" -ne "$expected" ]; then
  echo "anonymize.sh: expected $expected answers, got $n" >&2
  exit 1
fi

# Fisher–Yates shuffle of indices 0..n-1
order=()
k=0
while [ $k -lt $n ]; do order[$k]=$k; k=$((k + 1)); done
i=$((n - 1))
while [ $i -gt 0 ]; do
  j=$((RANDOM % (i + 1)))
  t=${order[$i]}; order[$i]=${order[$j]}; order[$j]=$t
  i=$((i - 1))
done

labels=(A B C D E F)

# Mask persona self-references only ("As the Contrarian, ...", "Executor here:",
# "逆張り役として"), so ordinary words like "the executor of the estate" survive.
mask() {
  perl -CSD -Mutf8 -pe '
    my $P = qr/(?:contrarian|first[- ]principles?|expansionist|outsider|executor|red[- ]team(?:er)?)/i;
    s/\b(as\s+(?:(?:the|a|an|your|my|our)\s+)?)$P\b/${1}[advisor]/gi;
    s/\b$P(?=\s+(?:here|speaking|view|lens|angle|perspective|take|hat|seat|mode|role)\b)/[advisor]/gi;
    s/\b((?:the|my)\s+)$P(?=\s+in\s+me\b)/${1}[advisor]/gi;
    s/^(\s*(?:[-*]\s*)?)$P(?=\s*[:：])/${1}[advisor]/gi;
    s/\b[Tt]he\s+(?:Contrarian|First[- ]Principles?|Expansionist|Outsider|Executor|Red[- ]Team(?:er)?)\b/the [advisor]/g;
    s/(?:逆張り役|逆張り派|第一原理派|拡張派|部外者|実行役|レッドチーム|コントラリアン|エクスパンショニスト|アウトサイダー|エグゼキューター)(?=として|の立場|の視点|の目線|から見ると|から見て|から言えば|の私|です|だ[。、])/[advisor]/g;
  '
}

# The packet goes to ./.llm-council-work/<id>/packet.md, inside the project, so
# reviewer and chairman subagents can read it without a permission prompt and the
# clerk does not have to copy it into every prompt. Nothing else goes in that
# folder: the key stays on stdout only.
umask 077
mkdir -p .llm-council-work
[ -f .llm-council-work/.gitignore ] || printf '*\n' > .llm-council-work/.gitignore
wdir="$(mktemp -d "$PWD/.llm-council-work/run.XXXXXX")"
pfile="$wdir/packet.md"
k=0
while [ $k -lt $n ]; do
  echo "=== ANSWER ${labels[$k]} ==="
  printf '%s' "${bodies[${order[$k]}]}" | mask
  echo
  k=$((k + 1))
done > "$pfile"

echo "### KEY (private — never show to reviewers)"
k=0
while [ $k -lt $n ]; do
  echo "${labels[$k]} = ${roles[${order[$k]}]}"
  k=$((k + 1))
done
echo "### PACKET FILE: $pfile"
