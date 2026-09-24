#!/usr/bin/env zsh

TMP_HOME=$(mktemp -d)
PLUGIN_DIR=${0:A:h}

cat <<EOF > "$TMP_HOME/.zshrc"
source "$PLUGIN_DIR/chuchu.plugin.zsh"
alias k=kubectl
PS1="%F{cyan}[CHUCHU TRY]%f %~ %# "
echo "💧 Chuchu sandbox shell. Try 'chuchu preview', 'k exec ...' or 'ssh ...'."
echo "   Type 'exit' or Ctrl+D to finish."
EOF

ZDOTDIR="$TMP_HOME" zsh -i
rm -rf "$TMP_HOME"
