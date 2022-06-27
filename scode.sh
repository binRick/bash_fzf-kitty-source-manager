#!/usr/bin/env bash
set -eou pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
REPO_FILTER="${1-}"
cd ../.

ansi --save-palette
ROWS="$(ansi --report-window-chars | cut -d, -f1)"

FZF_LAUNCH_TYPE=__SOURCE_CODE_LIST___
FZF_LAUNCH_TITLE="Sources"
EDITOR_TITLE="Editor"
EDITOR_ENV="EDITOR"
FZF_TITLE="Source Code List"
if [[ "$REPO_FILTER" != "" ]]; then
	FZF_LAUNCH_TYPE="${FZF_LAUNCH_TYPE}__$REPO_FILTER"
	FZF_LAUNCH_TITLE="${FZF_LAUNCH_TITLE} :: $REPO_FILTER"
	EDITOR_TITLE="${EDITOR_TITLE} :: $REPO_FILTER"
	EDITOR_ENV="${EDITOR_ENV}__$REPO_FILTER"
fi
LAUNCH_ENV=LAUNCH_TYPE=$FZF_LAUNCH_TYPE

TAB_MATCH=
TAB_MATCH="-m=env:LAUNCH_TYPE=$FZF_LAUNCH_TYPE"

path="/usr/local/bin:/usr/local/opt/coreutils/libexec/gnubin:/Users/rick/.cargo/bin:/usr/local/opt/qt/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

vterm-ctrl title "$FZF_LAUNCH_TITLE"
trap 'ansi --restore-palette; vterm-ctrl title ""' EXIT
kfc -s sexy-tangoesque

setup_editor_tab_cmd="kitty @ launch \
		--no-response \
		--type=tab \
		--dont-take-focus \
		--env ${FZF_LAUNCH_TYPE}_tmp=1 \
		--env LAUNCH_TYPE=$FZF_LAUNCH_TYPE \
		--hold \
		--allow-remote-control \
		--tab-title='$EDITOR_TITLE' \
"
ensure_editor_tab_cmd="kitty @ ls --all-env-vars | grep -q ' \"$FZF_LAUNCH_TYPE\"'   || eval \"$setup_editor_tab_cmd\""
ensure_editor_tab() {
	eval "$ensure_editor_tab_cmd"
}

strip() {
	printf "%s" "$@" | tr -s '[[:space:]]' ' '
}

_kitty_launch="kitty @ launch --env 'LAUNCH_TYPE=$FZF_LAUNCH_TYPE' --env 'LAUNCH_ITEM={}' --allow-remote-control --window-title=\"\$(basename {})\""
kitty_launch() {
	local launch_match=
	local launch_type="$1"
	shift
	[[ "$launch_type" == tab ]] && launch_match="$TAB_MATCH" && launch_type=window
	#[[ "$launch_type" == tab ]] && launch_match="$TAB_MATCH"
	printf "%s --type=%s %s %s" "$_kitty_launch" "$launch_type" "$launch_match" "$@"
}
kitty_cmd() {
	local cmd="$@"
	printf 'env PATH="%s" sh -c "%s"' "$path" "$@"
}

kitty_launch_vim_tab_no_focus="$(kitty_launch tab "--dont-take-focus $(kitty_cmd "vim {}")")"
kitty_launch_vim_tab="$(kitty_launch tab "$(kitty_cmd "vim {}")")"
kitty_launch_vim_window_no_focus="$(kitty_launch window "--dont-take-focus $(kitty_cmd "vim {}")")"
kitty_launch_vim_window="$(kitty_launch window "$(kitty_cmd "vim {}")")"
kitty_launch_overlay="kitty @ launch --cwd=current --type=overlay bat --paging=always {}"

REPOS="$(./GET_BINRICK_MESON_REPOS.sh)"
repo() {
	while read -r p; do echo -e "$REPOS" | xargs -I % echo -ne " \
		$(pwd)/%/$1 \
		$(pwd)/%/*/$1 \
		"; done <<<"$@"
}
BINRICK_REPOS="\
	$(repo '*/*.h') \
	$(repo '*/*.c') \
	$(repo '*.h') \
	$(repo '*.c') \
	$(repo 'submodules/*.h') \
	$(repo 'submodules/*.c') \
	$(repo 'submodules/*/*.h') \
	$(repo 'submodules/*/*.c') \
	$(repo 'submodules/*/*/*.h') \
	$(repo 'submodules/*/*/*.c') \
	$(repo 'meson.build') \
	$(repo 'meson_options.txt') \
	$(repo '*.sh') \
	$(repo '*.md' 'README' 'Readme' 'readme' '*.txt') \
	$(repo 'Makefile' 'makefile' 'CMakeLists.txt') \
"
find_paths="\
	$BINRICK_REPOS \
"
find_names="\
	-name '*' \
"
find_cmd="find $find_paths -type f $find_names 2>/dev/null|sort -u"
filter_cmd="cat"
[[ "$REPO_FILTER" != "" ]] && filter_cmd="egrep '/$REPO_FILTER/'"
find_cmd="$(strip "$find_cmd")"

preview_theme="Monokai Extended Bright"
preview_cmd="bat \
	--theme=\"$preview_theme\" \
	--style=numbers \
	--color=always \
	--line-range :5000 {} \
"
preview_cmd="$(strip "$preview_cmd")"

gen_focused_tab_cmd() {
	printf "$kitty_launch_vim_tab && { kitty @ close-window -m=env:${FZF_LAUNCH_TYPE}_tmp=1 2>/dev/null||true; } && sleep .2 && kitty @ focus-tab -m=env:LAUNCH_TYPE=$FZF_LAUNCH_TYPE"

}

BIND__KITTY_LAUNCH_VIM_TAB="$(gen_focused_tab_cmd)"
BIND__KITTY_LAUNCH_VIM_TAB_NO_FOCUS="$kitty_launch_vim_tab_no_focus"

FZF_HEADER1="left-click:select-item\ right-click:unfocused-tab\ double-click:focused-tab"
FZF_HEADER2="ctrl+i:preview\ ctrl+n:copy-file\ ctrl+t:open-in-tab\ ctrl+y:open-in-unfocused-tab\ ctrl+o:open-in-focused-window\ ctrl+p:open-in-unfocused-window"
FZF_HEADER1="$(strip "$FZF_HEADER1")"
FZF_HEADER2="$(strip "$FZF_HEADER2")"
HEADER_LINES=2

#	--bind 'right-click:execute-silent($BIND__KITTY_LAUNCH_VIM_TAB_NO_FOCUS)' \
fzf_binds="\
	--bind 'tab:down,btab:up' \
	--bind 'ctrl-n:execute-silent(echo -n {} | cut -f2 pbcopy)' \
	--bind 'ctrl-t:execute-silent($BIND__KITTY_LAUNCH_VIM_TAB)' \
	--bind 'double-click:execute-silent($BIND__KITTY_LAUNCH_VIM_TAB)' \
	--bind 'ctrl-y:execute-silent($kitty_launch_vim_tab_no_focus)' \
	--bind 'ctrl-o:execute-silent($kitty_launch_vim_window)' \
	--bind 'ctrl-p:execute-silent($kitty_launch_vim_window_no_focus)' \
	--bind 'ctrl-i:execute-silent($kitty_launch_overlay)' \
"
fzf_binds="$(strip "$fzf_binds")"
FZF_HEIGHT="100%"
fzf_cmd="fzf \
	--header-lines=$HEADER_LINES \
	--header-first \
	--height '$FZF_HEIGHT' \
	--ansi \
	--preview-window 'bottom:border-top,75%' \
	--border \
	--reverse \
	--info 'inline' \
	--color 'fg:-1,bg:-1,hl:230,fg+:3,bg+:233,hl+:229' \
	--color 'info:150,prompt:110,spinner:150,pointer:167,marker:174' \
	--preview '$preview_cmd' \
	$fzf_binds \
"
fzf_cmd="$(strip "$fzf_cmd")"

cmd="{ printf '%s\n%s\n' "$FZF_HEADER1" "$FZF_HEADER2" && { env FZF_OPTIONS= $find_cmd | $filter_cmd; }; } | $fzf_cmd"
_cmd() {
	printf "[%s]\n\t%%s" "$(ansi --red -n "$1")"
}
cmd() {
	echo -e "$(_cmd $@)"
}
c() {
	cmd $@
}
printf "$(c fzf_binds)\n$(c find_cmd)\n$(c preview_cmd)\n$(c fzf_cmd)\n$(c cmd)\n" \
	"$fzf_binds" \
	"$find_cmd" \
	"$preview_cmd" \
	"$fzf_cmd" \
	"$cmd" \
	>.cmd.sh

ensure_editor_tab
exec env sh -c "$cmd"
