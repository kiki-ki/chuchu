#!/usr/bin/env zsh
# Drives a real interactive zsh through a pseudo-terminal, so the hooks,
# alias expansion and escape sequences are exercised as a user would see them.
# Run: zsh tests/e2e.test.zsh

zmodload zsh/zpty

local root=${0:A:h:h} tmp=$(mktemp -d)
trap 'zpty -d shell 2>/dev/null; rm -rf $tmp' EXIT

mkdir $tmp/bin
print '#!/bin/sh\nexit 0' > $tmp/bin/kubectl
chmod +x $tmp/bin/kubectl
cat > $tmp/.zshrc <<EOF
PATH=$tmp/bin:\$PATH
PS1='READY> '
alias k=kubectl
source $root/chuchu.plugin.zsh
EOF

zpty shell "ZDOTDIR=$tmp zsh -i"

typeset -gi failures=0

# Runs a line and returns everything printed until the next prompt
run() {
  local out
  zpty -w shell "$1"
  zpty -r -m shell out '*READY> '
  REPLY=$out
}

# A third argument of "not" inverts the match
expect() {
  local name=$1 pattern=$2 want=1 matched=0
  [[ $3 == not ]] && want=0
  [[ $REPLY == $~pattern ]] && matched=1
  if (( matched == want )); then
    print "ok   $name"
  else
    print "FAIL $name: ${(q+)REPLY}"
    (( failures++ ))
  fi
}

zpty -r -m shell REPLY '*READY> '

local color=$(ZDOTDIR=$tmp zsh -c "source $root/chuchu.plugin.zsh; chuchu color api-7f9c")

run 'k exec -it api-7f9c -- sh'
expect 'alias is expanded and the pane is tinted' '*'$'\e]11;'$color$'\a''*'
expect 'tint is reset before the next prompt' '*'$'\e]111\a''*READY> '

run 'kubectl get pods'
expect 'other subcommands are left alone' '*'$'\e]11;''*' not

if (( failures )); then
  print "\n$failures failure(s)"
  exit 1
fi
print "\nall passed"
