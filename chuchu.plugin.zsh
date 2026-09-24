#!/usr/bin/env zsh
# 💧 Chuchu - tint the terminal background by where you are.

typeset -g CHUCHU_VERSION="0.1.0"

# OKLCH L=0.26 C=0.06, hues 30° apart: equal lightness keeps text equally readable
(( ${+CHUCHU_COLORS} )) || typeset -ga CHUCHU_COLORS=(
  '#3c1618' '#3a1a05' '#312101' '#262601' '#132b0d' '#012c20'
  '#002a2c' '#012838' '#122341' '#241e3f' '#311936' '#391628'
)

typeset -gA CHUCHU_PARSERS
: ${CHUCHU_PARSERS[kubectl]:=.chuchu_parse_kubectl}
: ${CHUCHU_PARSERS[docker]:=.chuchu_parse_docker}
: ${CHUCHU_PARSERS[ssh]:=.chuchu_parse_ssh}

typeset -g _chuchu_tinted=0

# $1: subcommand (empty for none), $2: words allowed before it, $3: flags taking a value
.chuchu_operand() {
  emulate -L zsh
  local sub=$1 lead=$2 value_flags=$3 arg skip=0
  shift 3
  REPLY=
  for arg in "$@"; do
    if (( skip )); then
      skip=0
      continue
    fi
    case $arg in
      --) return ;;
      -*)
        # A short-flag cluster like `-vp 22` takes a value when its last letter does
        [[ $arg == ${~value_flags} || ( $arg == -[^-]* && -${arg[-1]} == ${~value_flags} ) ]] && skip=1
        ;;
      *)
        if [[ -z $sub ]]; then
          REPLY=$arg
          return
        elif [[ $arg == $sub ]]; then
          sub=
        elif [[ -z $lead || $arg != ${~lead} ]]; then
          return
        fi
        ;;
    esac
  done
}

.chuchu_parse_kubectl() {
  .chuchu_operand exec '' '(-[cfnsv]|--namespace|--context|--cluster|--user|--kubeconfig|--server|--token|--as|--as-group|--as-uid|--cache-dir|--certificate-authority|--client-certificate|--client-key|--tls-server-name|--request-timeout|--container|--filename|--pod-running-timeout)' "$@"
  REPLY=${REPLY#pod/}
}

.chuchu_parse_docker() {
  .chuchu_operand exec '(container|compose)' '(-[cefHlpuw]|--host|--context|--config|--log-level|--file|--project-name|--project-directory|--profile|--env-file|--ansi|--parallel|--env|--user|--workdir|--detach-keys|--index)' "$@"
}

.chuchu_parse_ssh() {
  .chuchu_operand '' '' '-[BbcDEeFIiJLlmOoPpQRSWw]' "$@"
  REPLY=${${${REPLY#ssh://}#*@}%:*}
}

.chuchu_color() {
  emulate -L zsh
  REPLY=
  (( ${#CHUCHU_COLORS} )) || return
  local c h=2166136261
  for c in ${(s::)1}; do
    (( h = ((h ^ #c) * 16777619) & 0xffffffff ))
  done
  # FNV's low bits mix poorly
  (( h ^= h >> 16 ))
  REPLY=${CHUCHU_COLORS[h % ${#CHUCHU_COLORS} + 1]}
}

.chuchu_target() {
  emulate -L zsh
  local -a words=(${(z)1})
  local end=${words[(i)(\;|\||\|\||&&|&|\|&)]}
  words=("${(@Q)words[1,end-1]}")
  while [[ ${words[1]} == ([A-Za-z_]*=*|command|builtin|noglob|nocorrect|time) ]]; do
    shift words
  done

  REPLY=
  local parser=${CHUCHU_PARSERS[${words[1]:t}]}
  [[ -n $parser ]] && $parser "${(@)words[2,-1]}"
}

.chuchu_preexec() {
  emulate -L zsh
  [[ -t 1 ]] || return
  local REPLY
  # $3 has aliases expanded
  .chuchu_target "$3"
  [[ -n $REPLY ]] || return
  .chuchu_color "$REPLY"
  [[ -n $REPLY ]] || return
  printf '\e]11;%s\a' "$REPLY"
  _chuchu_tinted=1
}

.chuchu_precmd() {
  (( _chuchu_tinted )) || return
  printf '\e]111\a'
  _chuchu_tinted=0
}

chuchu() {
  emulate -L zsh
  case $1 in
    preview)
      local -a labels colors
      local i=1 key REPLY name
      if (( $# > 1 )); then
        for name in "${@[2,-1]}"; do
          .chuchu_color "$name"
          labels+=("$name ($REPLY)")
          colors+=($REPLY)
        done
      else
        labels=($CHUCHU_COLORS)
        colors=($CHUCHU_COLORS)
      fi
      [[ -n ${colors[1]} ]] || { print -u2 "chuchu: CHUCHU_COLORS is empty"; return 1 }
      {
        while true; do
          printf '\e]11;%s\a' ${colors[i]}
          print -P "%B[$i/${#colors}] ${labels[i]//\%/%%}%b  %F{red}red%f %F{green}green%f %F{yellow}yellow%f %F{blue}blue%f %F{magenta}magenta%f %F{cyan}cyan%f"
          read -rs -k1 key
          [[ $key == q ]] && break
          (( i = i % ${#colors} + 1 ))
        done
      } always {
        printf '\e]111\a'
      }
      ;;
    color)
      [[ -n $2 ]] || { print -u2 "Usage: chuchu color <name>"; return 1 }
      local REPLY
      .chuchu_color "$2"
      print $REPLY
      ;;
    version) print $CHUCHU_VERSION ;;
    ''|help|-h|--help)
      print "Usage: chuchu <command>"
      print "  preview [name...]  Show each color, or each name's color, as the background (any key: next, q: quit)"
      print "  color <name>       Print the color a name maps to"
      print "  version            Show version"
      ;;
    *)
      print -u2 "chuchu: unknown command: $1 (see 'chuchu help')"
      return 1
      ;;
  esac
}

chuchu_plugin_unload() {
  emulate -L zsh
  .chuchu_precmd
  add-zsh-hook -d preexec .chuchu_preexec
  add-zsh-hook -d precmd .chuchu_precmd
  unfunction .chuchu_operand .chuchu_target .chuchu_parse_kubectl .chuchu_parse_docker .chuchu_parse_ssh \
    .chuchu_color .chuchu_preexec .chuchu_precmd chuchu chuchu_plugin_unload
  unset CHUCHU_VERSION CHUCHU_COLORS CHUCHU_PARSERS _chuchu_tinted
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec .chuchu_preexec
add-zsh-hook precmd .chuchu_precmd
