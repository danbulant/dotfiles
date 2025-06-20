#!/usr/bin/env bash

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MATUGEN_DIR="$XDG_CONFIG_HOME/matugen"
terminalscheme="$XDG_CONFIG_HOME/quickshell/scripts/terminal/scheme-base.json"
IMAGE="$1"

matugen image "$IMAGE"
python3 "$SCRIPT_DIR/generate_colors_material.py" --path "$IMAGE" \
        > "$STATE_DIR"/user/generated/material_colors.scss