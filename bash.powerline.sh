#!/usr/bin/env bash

## Uncomment to disable git info
#POWERLINE_GIT=0

__powerline() {
    # Colorscheme
    readonly RESET='\[\e[m\]'
    readonly COLOR_CWD='\[\e[0;34m\]' # blue
    readonly COLOR_GIT='\[\e[0;36m\]' # cyan
    readonly COLOR_SUCCESS='\[\e[0;32m\]' # green
    readonly COLOR_FAILURE='\[\e[0;31m\]' # red

    readonly INFO_SUCCESS='\e[38;5;2m\e[48;5;15m'
    readonly INFO_FAILURE='\e[38;5;1m\e[48;5;15m'
    readonly STATUS_SUCCESS='\[\e[1;42;97m\]'
    readonly STATUS_FAILURE='\[\e[1;41;97m\]'
    readonly BG_INFO='\[\e[100m\]'
    readonly BG_CWD='\[\e[0;44m\]' # blue
    readonly BG_GIT='\[\e[0;46m\]' # cyan

    readonly SYMBOL_GIT_BRANCH=''
    readonly SYMBOL_GIT_MODIFIED='*'
    readonly SYMBOL_GIT_PUSH='↑'
    readonly SYMBOL_GIT_PULL='↓'
    readonly SYMBOL_SEPERATOR=$'\ue0b0'
    readonly SYMBOL_PATH_SEPARATOR=$'\ue0b1'
    readonly SYMBOL_PATH_HOME=$'\uf015'
    readonly SYMBOL_PATH_DEFAULT=$'\uf07b'
    readonly SYMBOL_NETWORK=$'\u1F5A7'

    if [[ -z "$PS_SYMBOL" ]]; then
      case "$(uname)" in
          Darwin)   PS_SYMBOL='';;
          Linux)    PS_SYMBOL='$';;
          *)        PS_SYMBOL='%';;
      esac
    fi

    __git_info() {
        [[ $POWERLINE_GIT = 0 ]] && return # disabled
        hash git 2>/dev/null || return # git not found
        local git_eng="env LANG=C git"   # force git output in English to make our work easier

        # get current branch name
        local ref=$($git_eng symbolic-ref --short HEAD 2>/dev/null)

        if [[ -n "$ref" ]]; then
            # prepend branch symbol
            ref="$SYMBOL_GIT_BRANCH $ref"
        else
            # get tag name or short unique hash
            ref=$($git_eng describe --tags --always 2>/dev/null)
        fi

        [[ -n "$ref" ]] || return  # not a git repo

        local marks

        # scan first two lines of output from `git status`
        while IFS= read -r line; do
            if [[ $line =~ ^## ]]; then # header line
                [[ $line =~ ahead\ ([0-9]+) ]] && marks+=" $SYMBOL_GIT_PUSH${BASH_REMATCH[1]}"
                [[ $line =~ behind\ ([0-9]+) ]] && marks+=" $SYMBOL_GIT_PULL${BASH_REMATCH[1]}"
            else # branch is modified if output contains more lines after the header line
                marks="$SYMBOL_GIT_MODIFIED $marks"
                break
            fi
        done < <($git_eng status --porcelain --branch 2>/dev/null)  # note the space between the two <

        # print the git branch segment without a trailing newline
        printf " $ref$marks"
    }

    __network_info() {
        local ping=$(ping -q -w 1 -c 1 8.8.8.8 2> /dev/null| tail -1| awk '{print $4}' | cut -d '/' -f 2| cut -d '.' -f 1)
        local online=$(ping -q -w 1 -c 1 8.8.8.8 2> /dev/null| grep transmitted |  grep ' 0%')
        local net_symbol=🖧
        if [[ ! -z "$online" ]] ; then
            printf "$INFO_SUCCESS $SYMBOL_NETWORK  ${ping}ms $RESET"
        else
            printf "$INFO_FAILURE $SYMBOL_NETWORK  No network $RESET"
        fi
    }

    __prompt_dir() {
        local current_path=$PWD # WAS: local current_path="$(print -P '%~')"
        current_path=${current_path//$HOME/"~"}

        local icon_path=$SYMBOL_PATH_DEFAULT
        if [[ $current_path == '~'* ]]; then
            icon_path=$SYMBOL_PATH_HOME
        fi

        printf "$icon_path $current_path"
    }

    ps1() {
        # Check the exit code of the previous command and display different
        # colors in the prompt accordingly.
        local retcode=$?
        PS1="\n"

        # Previous command status
        if [ $retcode -eq 0 ]; then
            # local symbol="$COLOR_SUCCESS $PS_SYMBOL $RESET"
            local stats="$STATUS_SUCCESS \342\234\224 $RESET"
            local stats_separator="\e[38;5;2m\e[48;5;15m$SYMBOL_SEPERATOR"
        else
            # local symbol="$COLOR_FAILURE $PS_SYMBOL $RESET"
            local stats="$STATUS_FAILURE \342\234\230 $retcode $RESET"
            local stats_separator="\e[38;5;1m\e[48;5;15m$SYMBOL_SEPERATOR"
        fi
        PS1+="$stats$stats_separator"

        # Network info
        local net_info="$(__network_info)"
        PS1+="$net_info\e[38;5;15m\e[48;5;8m${SYMBOL_SEPERATOR}"

        # General info
	    local user_info=$USER       #user
        local now=$(date +%H:%M)    # local time
        PS1+="$BG_INFO $now $user_info $RESET\[\e[44;90m\]${SYMBOL_SEPERATOR}$RESET"

        # Current directory
        local path_info="$(__prompt_dir)"
        PS1+="$BG_CWD $path_info $RESET"
        # Bash by default expands the content of PS1 unless promptvars is disabled.
        # We must use another layer of reference to prevent expanding any user
        # provided strings, which would cause security issues.
        # POC: https://github.com/njhartwell/pw3nage
        # Related fix in git-bash: https://github.com/git/git/blob/9d77b0405ce6b471cb5ce3a904368fc25e55643d/contrib/completion/git-prompt.sh#L324
        if shopt -q promptvars; then
            __powerline_git_info="$(__git_info)"
            local git_info=${__powerline_git_info}
        else
            # promptvars is disabled. Avoid creating unnecessary env var.
            local git_info="\e[46;34m$SYMBOL_SEPERATOR$RESET$BG_GIT$(__git_info)$RESET"
        fi

        if [ ! -z "$git_info" ]; then
            PS1+="\[\e[46;34m\]${SYMBOL_SEPERATOR}$RESET"
            PS1+="$BG_GIT$git_info$RESET\[\e[36m\]$SYMBOL_SEPERATOR$RESET"
        else
            PS1+="\[\e[34m\]$SYMBOL_SEPERATOR $RESET"
        fi

        # Prompt symbol
        local symbol="\[\e[34m\]$PS_SYMBOL$RESET"
        [[ $UID -eq 0 ]] && symbol="⚡"
        PS1+="\n $symbol "
    }

    PROMPT_COMMAND="ps1${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
}

__powerline
unset __powerline
