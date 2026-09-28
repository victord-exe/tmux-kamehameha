# Shell de los demos: prompt del extra de oh-my-posh y sin historial
HISTFILE=/dev/null
export AWS_PROFILE=default
eval "$(oh-my-posh init zsh --config "$KH_REPO/extras/oh-my-posh/kamehameha.omp.json")"
