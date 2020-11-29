#!/bin/bash

set -eu

FILENAME=$(echo $1 | awk -F '|' '{print $1}')
LNUM=$(echo $1 | awk -F '|' '{print $2}' | awk '{print $1}')

bat --color=always --style=numbers -r $LNUM: -H $LNUM "$FILENAME" | head -n 1000

