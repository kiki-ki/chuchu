#!/usr/bin/env zsh
# Drives a real interactive zsh through a pseudo-terminal, so the hooks,
# alias expansion and escape sequences are exercised as a user would see them.
# Run: zsh tests/e2e.test.zsh

zmodload zsh/zpty zsh/zselect

local root=${0:A:h:h} tmp=$(mktemp -d)
trap 'zpty -d shell 2>/dev/null; rm -rf $tmp' EXIT

mkdir $tmp/bin
print '#!/bin/sh\nexit 0' > $tmp/bin/kubectl
chmod +x $tmp/bin/kubectl
cat > $tmp/rc.zsh <<EOF
PATH=$tmp/bin:\$PATH
PS1='READY> '
unset zle_bracketed_paste
alias k=kubectl
source $root/chuchu.plugin.zsh
EOF

typeset -gi failures=0

# Sets REPLY to everything printed until the next prompt. Gives up after 10s
# with what arrived so far, so a shell stuck on some question fails loudly.
wait_prompt() {
  local chunk deadline=$(( SECONDS + 10 ))
  REPLY=
  while (( SECONDS < deadline )); do
    if zpty -rt shell chunk; then
      REPLY+=$chunk
      [[ $REPLY == *'READY> '* ]] && return 0
    else
      zselect -t 5
    fi
  done
  print "FAIL no prompt within 10s: ${(q+)REPLY}"
  exit 1
}

# Runs a line and returns everything printed until the next prompt
run() {
  zpty -w shell "$1"
  wait_prompt
}

# -f skips system-wide startup files, which may ask questions (e.g. compinit on
# Ubuntu) or set their own prompt
zpty shell "zsh -f -i"
run "source $tmp/rc.zsh"

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

local color=$(zsh -f -c "source $root/chuchu.plugin.zsh; chuchu color api-7f9c")

run 'k exec -it api-7f9c -- sh'
expect 'alias is expanded and the pane is tinted' '*'$'\e]11;'$color$'\a''*'
expect 'tint is reset before the next prompt' '*'$'\e]111\a''*READY> *'

run 'kubectl get pods'
expect 'other subcommands are left alone' '*'$'\e]11;''*' not

if (( failures )); then
  print "\n$failures failure(s)"
  exit 1
fi
print "\nall passed"
