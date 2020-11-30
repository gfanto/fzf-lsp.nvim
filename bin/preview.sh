#!/bin/bash

set -eu

FILE=$(echo $1 | awk -F '|' '{print $1}')
CENTER=$(echo $1 | awk -F '|' '{print $2}' | awk '{print $1}')

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

UP=$(($CENTER-$LINES/2))

# Sometimes bat is installed as batcat.
if command -v batcat > /dev/null; then
  BATNAME="batcat"
elif command -v bat > /dev/null; then
  BATNAME="bat"
fi

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

${BATNAME} --style="${BAT_STYLE:-numbers}" --color=always --highlight-line=$CENTER \
  --line-range="$UP:$DOWN" "$FILE"

