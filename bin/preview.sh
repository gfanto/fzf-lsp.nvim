#!/bin/sh
set -eu

FILE="${1%%:*}"
case "${FILE%%/*}" in
    '~'*[!a-zA-Z0-9._-]*) ;; # only expand ~ and ~valid-username
    '~'*) eval "PREFIX=${FILE%%/*}"; FILE="$PREFIX/${FILE#*/}" ;;
esac

if [ ! -r "$FILE" ]; then
  printf "File not found ${FILE}\n" 2> /dev/stderr
  exit 1
fi

CENTER="${1#*:}"
CENTER="${CENTER%%:*}"
case $CENTER in [!0-9]*) exit 1 ;; esac
CENTER="${CENTER%%[!0-9]*}"

LINES=${LINES:-100}
UP=$(($CENTER-$LINES/2))
UP=$(($UP >= 1 ? $UP : 1))
DOWN=$(($CENTER+$LINES/2))
DOWN=$(($DOWN < $LINES ? $LINES : ($UP+$DOWN)))

# Sometimes bat is installed as batcat.
BAT="${BAT:-$(which bat || which batcat || true)}"
if [ -n "$BAT" ]; then
  "$BAT" --style="${BAT_STYLE:-numbers}" --color=always --highlight-line=${CENTER:-0} \
    --line-range="$UP:$DOWN" "$FILE"
else
  HIGHLIGHT="$([ -n "$CENTER" ] && printf "${CENTER}s/.*/${CAT_ANSI_HIGHLIGHT:-\e[7m}\\\\0\e[0m/;" || true)"
  cat ${CAT_STYLE:-"-n"} "$FILE" | sed -n "${HIGHLIGHT} ${UP},${DOWN}p"
fi
