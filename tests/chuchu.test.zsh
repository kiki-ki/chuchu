#!/usr/bin/env zsh
# Run: zsh tests/chuchu.test.zsh

source ${0:A:h:h}/chuchu.plugin.zsh

typeset -gi failures=0

assert_target() {
  local line=$1 expected=$2 REPLY
  .chuchu_target "$line"
  if [[ $REPLY == $expected ]]; then
    print "ok   ${(q-)line} -> ${(q-)REPLY}"
  else
    print "FAIL ${(q-)line}: expected ${(q-)expected}, got ${(q-)REPLY}"
    (( failures++ ))
  fi
}

assert_eq() {
  local name=$1 expected=$2 actual=$3
  if [[ $actual == $expected ]]; then
    print "ok   $name"
  else
    print "FAIL $name: expected ${(q-)expected}, got ${(q-)actual}"
    (( failures++ ))
  fi
}

# kubectl
assert_target 'kubectl exec -it api-7f9c -- sh' api-7f9c
assert_target 'kubectl -n prod exec -it -c app api-7f9c -- sh' api-7f9c
assert_target 'kubectl exec --namespace=prod pod/api-7f9c -- ls' api-7f9c
assert_target 'kubectl exec -itn prod api-7f9c -- sh' api-7f9c
assert_target 'kubectl get pods' ''
assert_target 'kubectl run x --image=busybox -- exec' ''
assert_target 'kubectl exec -f pod.yaml -- sh' ''
assert_target 'kubectl -v 6 --context prod exec api-7f9c -- sh' api-7f9c
assert_target 'kubectl get pod exec' ''
assert_target 'kubectl -n exec get pods' ''

# docker
assert_target 'docker exec -it -u root web-1 bash' web-1
assert_target 'docker container exec -e FOO=bar web-1 bash' web-1
assert_target 'docker compose exec -w /app api sh' api
assert_target 'docker compose -f compose.yml -p app exec api sh' api
assert_target 'docker --context prod exec web-1 sh' web-1
assert_target 'docker run alpine exec foo' ''
assert_target 'docker ps' ''

# ssh
assert_target 'ssh prod-bastion' prod-bastion
assert_target 'ssh -i ~/.ssh/id -p 2222 deploy@prod-bastion' prod-bastion
assert_target 'ssh -vp 2222 prod-bastion uptime' prod-bastion
assert_target 'ssh ssh://deploy@prod-bastion:2222' prod-bastion
assert_target 'ssh -o StrictHostKeyChecking=no prod-bastion' prod-bastion

# command line shapes
assert_target 'FOO=1 command kubectl exec api-7f9c -- sh' api-7f9c
assert_target '/usr/bin/ssh prod-bastion' prod-bastion
assert_target 'kubectl exec api-7f9c -- env | grep FOO' api-7f9c
assert_target 'echo hi && ssh prod-bastion' ''
assert_target 'ls "ssh prod-bastion"' ''
assert_target '' ''

# user-defined parser
.my_parse_mosh() { REPLY=$1 }
CHUCHU_PARSERS[mosh]=.my_parse_mosh
assert_target 'mosh prod-bastion' prod-bastion

# colors
local REPLY a b
.chuchu_color api-7f9c; a=$REPLY
.chuchu_color api-7f9c; b=$REPLY
assert_eq 'same name gives same color' $a $b
assert_eq 'color comes from the palette' 1 $(( ${CHUCHU_COLORS[(Ie)$a]} > 0 ))
# Pinned so a hash change, which would recolor every user's hosts, is deliberate
.chuchu_color abc-0; assert_eq 'abc-0 keeps its color' '#122341' $REPLY
.chuchu_color def-0; assert_eq 'def-0 keeps its color' '#311936' $REPLY
.chuchu_color web-1; assert_eq 'web-1 keeps its color' '#122341' $REPLY
local -A seen
for name in api-{1..100}; do .chuchu_color $name; seen[$REPLY]=1; done
assert_eq 'names spread over the whole palette' ${#CHUCHU_COLORS} ${#seen}

# an empty palette disables tinting instead of failing
local -a saved=($CHUCHU_COLORS)
CHUCHU_COLORS=()
.chuchu_color api-7f9c
assert_eq 'empty palette gives no color' '' "$REPLY"
CHUCHU_COLORS=($saved)

# command
chuchu help >/dev/null; assert_eq 'help succeeds' 0 $?
chuchu nope 2>/dev/null; assert_eq 'unknown command fails' 1 $?
assert_eq 'color prints the mapped color' '#122341' "$(chuchu color abc-0)"

# escape sequences only go to a terminal
assert_eq 'no escape sequence when not a terminal' '' "$(.chuchu_preexec '' '' 'ssh prod-bastion')"

# the plugin must not depend on the user's shell options
# An error aborts the subshell early, so comparing the whole output catches it
local plugin=${0:A:h:h}/chuchu.plugin.zsh
assert_eq 'works under unusual user shell options' 'api-7f9c prod-bastion #122341' "$(
  setopt KSH_ARRAYS SH_WORD_SPLIT NO_UNSET EXTENDED_GLOB GLOB_SUBST WARN_CREATE_GLOBAL
  source $plugin
  typeset REPLY=
  .chuchu_target 'kubectl -n prod exec -it api-7f9c -- sh | grep x'; print -rn -- "$REPLY "
  .chuchu_target 'ssh -p 2222 deploy@prod-bastion'; print -rn -- "$REPLY "
  .chuchu_color abc-0; print -rn -- "$REPLY"
)"

# unload
chuchu_plugin_unload
assert_eq 'unload removes preexec hook' 0 ${${preexec_functions[(Ie).chuchu_preexec]}:-0}
assert_eq 'unload removes functions' 0 ${+functions[chuchu]}

(( failures )) && { print "\n$failures failure(s)"; exit 1 }
print "\nall passed"
