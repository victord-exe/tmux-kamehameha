#!/usr/bin/env bash
# Entry point de TPM: carga el tema y registra los pickers con la ruta real del plugin.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
opt() { local v; v=$(tmux show -gqv "$1"); echo "${v:-$2}"; }

# Temas: acento y secundario. kamehameha.conf está escrito con los colores del default
theme=$(opt @kamehameha-theme kamehameha)
case "$theme" in
  skyline) accent="#3d85ff" accent2="#c0caf5" ;;   # azul del Skyline de Brian + plateado
  *)       accent="#ff9e64" accent2="#7aa2f7" ;;
esac
tmux set -g @kh_accent "$accent" \; set -g @kh_accent2 "$accent2" \; set-environment -g KAMEHAMEHA_THEME "$theme"
sed -e "s/#ff9e64/$accent/g" -e "s/#7aa2f7/$accent2/g" "$DIR/kamehameha.conf" | tmux source -

[ "$(opt @kamehameha-pet on)" = on ] && tmux set -ag status-right " #{E:@kh_pet}"

tmux bind "$(opt @kamehameha-sessions-key f)" display-popup -E -B -w 90% -h 80% "$DIR/scripts/session-picker.sh"
tmux bind "$(opt @kamehameha-search-key g)" display-popup -E -B -w 90% -h 80% "$DIR/scripts/text-search.sh"
