#!/bin/bash

set -eu

FILE=$(echo $1 | awk -F ':' '{print $1}')
CENTER=$(echo $1 | awk -F ':' '{print $2}')

if [[ -n "$CENTER" && ! "$CENTER" =~ ^[0-9] ]]; then
  exit 1
fi
CENTER=${CENTER/[^0-9]*/}

FILE="${FILE/#\~\//$HOME/}"
if [ ! -r "$FILE" ]; then
  echo "File not found ${FILE}"
  exit 1
fi

if [ -z "$CENTER" ]; then
  CENTER=0
fi

LINES=${LINES:-100}
UP=$(($CENTER-$LINES/2))
DOWN=$(($CENTER+$LINES/2))

if [ $UP -lt 0 ]; then
  if [ $DOWN -lt $LINES ]; then
    DOWN=$LINES
  else
    DOWN=$(($UP+$DOWN))
  fi
  UP=0
fi

# Sometimes bat is installed as batcat.
if command -v batcat > /dev/null; then
  batcat --style="${BAT_STYLE:-numbers}" --color=always --highlight-line=$CENTER \
    --line-range="$UP:$DOWN" "$FILE"
elif command -v bat > /dev/null; then
  bat --style="${BAT_STYLE:-numbers}" --color=always --highlight-line=$CENTER \
    --line-range="$UP:$DOWN" "$FILE"
else
  cat ${CAT_STYLE:-"--number"} "$FILE" | head --lines=$DOWN | tail --lines=$(($DOWN-$UP))
fi
