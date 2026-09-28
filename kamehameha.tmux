#!/usr/bin/env bash
# Entry point de TPM: carga el tema y registra los pickers con la ruta real del plugin.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
opt() { local v; v=$(tmux show -gqv "$1"); echo "${v:-$2}"; }

tmux source-file "$DIR/kamehameha.conf"

[ "$(opt @kamehameha-pet on)" = on ] && tmux set -ag status-right " #{E:@kh_pet}"

tmux bind "$(opt @kamehameha-sessions-key f)" display-popup -E -B -w 90% -h 80% "$DIR/scripts/session-picker.sh"
tmux bind "$(opt @kamehameha-search-key g)" display-popup -E -B -w 90% -h 80% "$DIR/scripts/text-search.sh"
