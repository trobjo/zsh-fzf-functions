# Paste the selected command(s) from history into the command line
fzf-history-widget() {
    local IFS=$'\n'
    local NEWLINE=$'\n'
    local out myQuery line REPLACE separator_var=";"
    setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null

    if [[ ${LBUFFER: -3} != "&& " ]] && [[ ${LBUFFER: -2} != "; " ]] && [[ ${LBUFFER: -2} != "&&" ]] && [[ ${LBUFFER: -1} != ";" ]]; then
        REPLACE=true
        myQuery="\'${(qqq)LBUFFER}"
    fi

    local out=( $(fc -rnli 1 | sed -r "s/^(................)/`printf '\033[4m'`\1`printf '\033[0m'`/" |
                 FZF_DEFAULT_OPTS=" $FZF_DEFAULT_OPTS --no-sort --prompt=\"$(print -Pn ${PROMPT_PWD:-$PWD}) \" --expect=ctrl-/,ctrl-p,enter --delimiter='  ' --nth=2.. --preview-window=bottom,30% --preview 'bat --style=plain  --color always --language bash <<< {2..}' --no-hscroll --tiebreak=index --bind \"alt-w:execute-silent(wl-copy -- {2..})+abort\" --query=${myQuery}" fzf) )

    if [[ -n "$out" ]]; then
        if [[ ${LBUFFER: -2} == "&&" ]] || [[ ${LBUFFER: -1} == ";" ]]; then
            LBUFFER+=' '
        fi

        key="${out[@]:0:1}"
        if [[ "$key" == "ctrl-p" ]]; then
            separator_var=" &&"
        fi
        [[ $REPLACE ]] && LBUFFER="${${${out[@]:1:1}#*:[0-9][0-9]  }//\\n/$NEWLINE}" || LBUFFER+="${${${out[@]:1:1}#*:[0-9][0-9]  }//\\n/$NEWLINE}"
        for hist in "${out[@]:2}"; do
            hist=${hist//\\n/$NEWLINE}
            LBUFFER+="$separator_var ${hist#*:[0-9][0-9]  }"
        done
    fi
    zle reset-prompt
}
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} \
--bind \"alt-t:page-down,\
alt-c:page-up,\
ctrl-e:replace-query,\
ctrl-b:toggle-all,\
change:top,\
ctrl-/:execute-silent(rm -rf {+})+abort,\
ctrl-r:toggle-sort,\
ctrl-q:unix-line-discard\" \
--multi \
--preview-window=right:50%:sharp:wrap \
--preview 'if [[ -d {} ]]
    then
        ls --color=always -l {}
    elif [[ {} =~ \"\.(jpeg|JPEG|jpg|JPG|png|webp|WEBP|PNG|gif|GIF|bmp|BMP|tif|TIF|tiff|TIFF)$\" ]]
    then
        identify -ping -format \"%f\\n%m\\n%w x %h pixels\\n%b\\n\\n%l\\n%c\\n\" {}
    elif [[ {} =~ \"\.(svg|SVG)$\" ]]
    then tiv -h \$FZF_PREVIEW_LINES -w \$FZF_PREVIEW_COLUMNS {}
    elif [[ {} =~ \"\.(pdf|PDF)$\" ]]
    then pdfinfo {}
    elif [[ {} =~ \"\.(zip|ZIP|sublime-package)$\" ]]
    then zip -sf {}
    elif [[ {} =~ \"(json|JSON)$\" ]]
    then jq --indent 4 --color-output < {}
else bat \
    --style=header,numbers \
    --terminal-width=\$((\$FZF_PREVIEW_COLUMNS - 6)) \
    --force-colorization \
    --italic-text=always \
    --line-range :70 {} 2>/dev/null; fi'"

if type fd > /dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND="/usr/bin/fd --color always --exclude node_modules"
fi


if type rg > /dev/null 2>&1; then
alias fif='noglob _fif'
_fif() {
    [[ "$#" -eq 0 ]] && print "Need a string to search for!" && return 1
    local IFS=$'\n'
    setopt localoptions pipefail no_aliases 2> /dev/null
    local myQuery="$@"
    local out=($(rg --files-with-matches --no-messages "$myQuery" | fzf --expect=ctrl-p --prompt="$(print -Pn "${PROMPT_PWD:-$PWD} \e[3m$myQuery\e[0m") " --preview "rg $RIPGREP_OPTS --pretty --context 10 '$myQuery' {}"))
    if [[ -z "$out" ]]; then
        return 0
    fi

   local key="$(head -1 <<< "${out[@]}")"
   case "$key" in
       (ctrl-p)
       swaymsg -q -- "exec /opt/sublime_text/sublime_text --command close_all"
       swaymsg -q -- "[app_id=^PopUp$] move scratchpad; [app_id=^sublime_text$ title=.] focus; exec /opt/sublime_text/sublime_text ${(q)${out[@]:1:A}}"
       ;;
       (*)
       swaymsg -q -- "[app_id=^PopUp$] move scratchpad; [app_id=^sublime_text$ title=.] focus; exec /opt/sublime_text/sublime_text ${(q)out[@]:A}"
       ;;
   esac
   return 0
}
fi


# Ensure precmds are run after cd
fzf-redraw-prompt() {
    local precmd
    for precmd in $precmd_functions; do
        $precmd
    done
}
zle -N fzf-redraw-prompt

alias myfzf="eval 'myp=\$(print -Pn \${PROMPT})'
    fd --color always --exclude node_modules | \
    fzf \
        --prompt=\"\$myp\" \
        --bind 'ctrl-h:change-preview-window(right,75%|hidden|right,50%)' \
        --preview-window=right,50%,border-left"



fzf-widget() {
    eval 'myp=$(print -Pn "${PROMPT}")'
    fd --color always --exclude node_modules | \
    fzf \
        --prompt="$myp" \
        --bind 'ctrl-h:change-preview-window(right,75%|hidden|right,50%)' \
        --preview-window='right,50%,border-left' | open
    zle fzf-redraw-prompt
    zle reset-prompt
}
zle     -N    fzf-widget
bindkey '^P' fzf-widget

() {
    # we locale the download directory
    case $OSTYPE in
         (darwin*)
            DL_DIR="$HOME/Downloads"
            ;;
        (linux-gnu)
            while read line
            do
                if [[ $line == XDG_DOWNLOAD_DIR* ]]; then
                    DL_DIR=${(P)line##*=}
                    break
                fi
            done < "${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
            ;;
         (*)
            print "Your platform is not supported. Please open an issue"
            return 1
            ;;
    esac
    [[ ! -z $DL_DIR ]] || return
    fzf-downloads-widget() {
            ls --color=always -ctd1 ${(q)DL_DIR}/* | fzf --tiebreak=index --delimiter=/ --with-nth=5.. --no-sort | open
            zle fzf-redraw-prompt
            zle reset-prompt
    }
    zle -N fzf-downloads-widget
    bindkey '^O' fzf-downloads-widget
}


if type pass > /dev/null 2>&1; then
fzf-password() {
    /usr/bin/fd . --extension gpg --base-directory $HOME/.password-store |\
     sed -e 's/.gpg$//' |\
     sort |\
     fzf --no-multi --preview-window=hidden --bind 'alt-w:abort+execute-silent@touch /tmp/clipman_ignore ; wl-copy -n -- $(pass {})@,enter:execute-silent@ if [[ $PopUp ]]; then swaymsg "[app_id=^PopUp$] scratchpad show"; fi; touch /tmp/clipman_ignore; wl-copy -n -- $(pass {})@+abort'
}
zle -N fzf-password
fi

alias glo="eval 'myp=\$(print -Pn \${_PROMPT})'
    git log \
        --date=format-local:'%Y-%m-%d %H:%M' \
        --pretty=format:'%C(red)%h %C(green)%cd%C(reset) %C(cyan)●%C(reset) %C(yellow)%an%C(reset) %C(cyan)●%C(reset) %s' \
        --abbrev-commit \
        --color=always | \
    fzf \
        --header=\"\$myp\" \
        --header-first \
        --delimiter=' ' \
        --no-sort \
        --no-extended \
        --with-nth=2.. \
        --bind 'enter:become(print -l -- {+1})' \
        --bind 'alt-w:execute-silent(wl-copy -n -- {+1})+abort' \
        --bind 'ctrl-h:change-preview-window(down,75%|down,99%|hidden|down,50%)' \
        --bind 'ctrl-b:put( ● )' \
        --preview='
        typeset -a args=(--hyperlinks --width=\$(( \$FZF_PREVIEW_COLUMNS - 2)));
        [[ \$FZF_PREVIEW_COLUMNS -lt 160 ]] || args+=--side-by-side
        git show --color=always {1} | delta \$args' \
        --preview-window=bottom,50%,border-top"

load='_gitstatus=$(git -c color.status=always status --short --untracked-files=all $PWD)
    {
       rg "^\x1b\[32m.\x1b\[m" <<< $_gitstatus
    rg -v "^\x1b\[32m.\x1b\[m" <<< $_gitstatus &!
    }'

resetterm=$'\033[2J\033[3J\033[H'
cyan=$'\e[1;36;m'
magenta=$'\e[0;35;m'
white=$'\e[0;37;m'
reset=$'\e[0;m'
quote='\\\"'

alias gs="\
    eval 'myp=\$(print -Pn \${_PROMPT})'
    $load | fzf \
        --header=\"\$myp\" \
        --header-first \
        --delimiter='' \
        --exit-0 \
        --nth='4..' \
        --no-sort \
        --no-extended \
        --bind 'enter:become(print -l {+4..} | sed -e 's/^${quote}//' -e 's/${quote}$//')' \
        --bind 'ctrl-p:execute-silent(open {+4..})+become(print -l {+4..} | sed -e 's/^${quote}//' -e 's/${quote}$//')' \
        --bind 'ctrl-a:execute-silent(git add {+4..})+reload($load)' \
        --bind 'ctrl-c:execute-silent(git checkout {+4..})+reload($load)' \
        --bind 'ctrl-r:execute-silent(git restore --staged {+4..})+reload($load)' \
        --bind 'ctrl-n:execute(git add -p {+4..}; printf \"$resetterm\")+reload($load)' \
        --bind 'ctrl-h:change-preview-window(down,75%|down,99%|hidden|down,50%)' \
        --preview '
        typeset -a args=(--hyperlinks --width=\$(( \$FZF_PREVIEW_COLUMNS - 2)));
        [[ \$FZF_PREVIEW_COLUMNS -lt 160 ]] || args+=--side-by-side
        if [[ {} == \"?*\" ]]; then
                          git diff --no-index /dev/null {4..} | delta \$args;
                      else
                          git diff HEAD -- {4..} | delta \$args;
                      fi;' \
        --preview-window=bottom,50%,border-top"
