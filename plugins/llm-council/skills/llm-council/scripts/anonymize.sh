#!/usr/bin/env bash
# anonymize.sh — shuffle the five advisor answers and relabel them A–E.
#
# stdin: five blocks, each starting with a line "=== ROLE: <role> ==="
# stdout:
#   ### KEY (private — never show to reviewers)
#   A = <role>
#   ...
#   ### PACKET (send to reviewers verbatim)
#   === ANSWER A ===
#   <text with persona names masked>
#   ...
#
# Uses bash $RANDOM (Fisher–Yates), so the order is actually random rather
# than an LLM's idea of "shuffled". Works on the bash 3.2 that ships with macOS.
set -eu

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
        case "$line" in "==="*) line="  ${line}" ;; esac
        bodies[$idx]="${bodies[$idx]}${line}
"
      fi
      ;;
  esac
done

n=$((idx + 1))
if [ "$n" -ne 5 ]; then
  echo "anonymize.sh: expected 5 answers, got $n" >&2
  exit 1
fi

# Fisher–Yates shuffle of indices 0..4
order=(0 1 2 3 4)
i=4
while [ $i -gt 0 ]; do
  j=$((RANDOM % (i + 1)))
  t=${order[$i]}; order[$i]=${order[$j]}; order[$j]=$t
  i=$((i - 1))
done

labels=(A B C D E)

echo "### KEY (private — never show to reviewers)"
for k in 0 1 2 3 4; do
  echo "${labels[$k]} = ${roles[${order[$k]}]}"
done
echo
echo "### PACKET (send to reviewers verbatim)"
for k in 0 1 2 3 4; do
  echo "=== ANSWER ${labels[$k]} ==="
  # Mask persona self-references so style labels don't leak identity.
  printf '%s' "${bodies[${order[$k]}]}" | sed -E \
    -e 's/[Cc][Oo][Nn][Tt][Rr][Aa][Rr][Ii][Aa][Nn][Ss]?/[advisor]/g' \
    -e 's/[Ff][Ii][Rr][Ss][Tt][- ][Pp][Rr][Ii][Nn][Cc][Ii][Pp][Ll][Ee][Ss]?/[advisor]/g' \
    -e 's/[Ee][Xx][Pp][Aa][Nn][Ss][Ii][Oo][Nn][Ii][Ss][Tt][Ss]?/[advisor]/g' \
    -e 's/[Oo][Uu][Tt][Ss][Ii][Dd][Ee][Rr][Ss]?/[advisor]/g' \
    -e 's/[Ee][Xx][Ee][Cc][Uu][Tt][Oo][Rr][Ss]?/[advisor]/g'
  echo
done
