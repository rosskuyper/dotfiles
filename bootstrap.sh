#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin main;

CLAUDE_SETTINGS="$HOME/.claude/settings.json";
REPO_CLAUDE_SETTINGS=".claude/settings.json";

# Deep-merge the repo's Claude settings baseline into the home settings file.
# Existing home values always win: objects recurse key by key, arrays are
# unioned (home order first, then baseline entries not already present), and
# anything the home file is missing is filled in from the baseline. Prints the
# merged document on stdout; returns non-zero if there is nothing to merge.
function mergeClaudeSettings() {
	local home='{}';

	[ -f "$REPO_CLAUDE_SETTINGS" ] || return 1;

	if ! command -v jq >/dev/null 2>&1; then
		echo "jq not found; skipping the ~/.claude/settings.json merge." >&2;
		return 1;
	fi

	if [ -f "$CLAUDE_SETTINGS" ]; then
		home=$(cat "$CLAUDE_SETTINGS");
		if ! jq -e . >/dev/null 2>&1 <<< "$home"; then
			echo "~/.claude/settings.json is not valid JSON; skipping the merge." >&2;
			return 1;
		fi
	fi

	jq -n --argjson home "$home" --slurpfile repo "$REPO_CLAUDE_SETTINGS" '
		def deepmerge($a; $b):
			if ($a | type) == "object" and ($b | type) == "object" then
				reduce ($b | keys_unsorted[]) as $k ($a;
					if has($k) then .[$k] = deepmerge(.[$k]; $b[$k])
					else .[$k] = $b[$k]
					end)
			elif ($a | type) == "array" and ($b | type) == "array" then
				$a + ($b - $a)
			elif $a == null then $b
			else $a
			end;
		deepmerge($home; $repo[0])
	';
}

# Returns 0 when the merge would actually change the home settings file.
function claudeSettingsPending() {
	local merged;

	merged=$(mergeClaudeSettings) || return 1;

	[ -f "$CLAUDE_SETTINGS" ] || return 0;

	# `command` sidesteps the diff() helper that .functions installs.
	command diff -q <(jq -S . "$CLAUDE_SETTINGS") <(jq -S . <<< "$merged") \
		>/dev/null 2>&1 && return 1;

	return 0;
}

function applyClaudeSettings() {
	local merged;

	merged=$(mergeClaudeSettings) || return 1;

	mkdir -p "$(dirname "$CLAUDE_SETTINGS")";
	printf '%s\n' "$merged" > "${CLAUDE_SETTINGS}.tmp" \
		&& mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS";
}

function showDiff() {
	local files settingsPending=0

	files=$(rsync --exclude ".git/" \
		--exclude ".DS_Store" \
		--exclude ".vscode" \
		--exclude ".osx" \
		--include ".claude/statusline-command.sh" \
		--exclude ".claude/*" \
		--exclude "bootstrap.sh" \
		--exclude "README.md" \
		--exclude "LICENSE-MIT.txt" \
		-avh --dry-run --itemize-changes --no-perms . ~ 2>/dev/null \
		| grep '^>f' \
		| awk '{print $2}')

	claudeSettingsPending && settingsPending=1;

	if [ -z "$files" ] && [ "$settingsPending" -eq 0 ]; then
		echo "All files are up to date. No changes needed.";
		return 1;
	fi

	# ~/.claude/settings.json is deep-merged rather than copied, and the merge
	# never overwrites a value that is already there, so it is applied directly
	# instead of going through the review below.
	if [ "$settingsPending" -eq 1 ]; then
		echo "~/.claude/settings.json will be merged from ${REPO_CLAUDE_SETTINGS} (existing values kept).";
		echo "";
	fi

	if [ -z "$files" ]; then
		return 0;
	fi

	if command -v fzf >/dev/null 2>&1; then
		local preview_cmd='f={}; if [ -f "$HOME/$f" ]; then git --no-pager diff --color=always --no-index -- "$HOME/$f" "$f"; else printf "\033[32m+++ ~/%s (new file)\033[0m\n\n" "$f"; cat "$f"; fi'

		echo "$files" | fzf \
			--ansi \
			--preview "$preview_cmd" \
			--preview-window=right:70%:wrap \
			--header=$'↑/↓ files · shift-↑/↓ scroll · pgup/pgdn page\nEnter apply · ESC abort' \
			--bind 'esc:abort,q:abort' \
			--bind 'shift-up:preview-up,shift-down:preview-down' \
			--bind 'pgup:preview-page-up,pgdn:preview-page-down' \
			--bind 'ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down' \
			> /dev/null
		return $?
	fi

	echo "The following files would change in your home directory:";
	echo "";
	while IFS= read -r file; do
		if [ -f "$HOME/$file" ]; then
			git --no-pager diff --color=auto --no-index -- "$HOME/$file" "$file";
			echo "";
		else
			echo "+++ ~/$file (new file)";
			echo "";
		fi
	done <<< "$files"

	read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
	echo "";
	[[ $REPLY =~ ^[Yy]$ ]]
}

function doIt() {
	rsync --exclude ".git/" \
		--exclude ".DS_Store" \
		--exclude ".vscode" \
		--exclude ".osx" \
		--include ".claude/statusline-command.sh" \
		--exclude ".claude/*" \
		--exclude "bootstrap.sh" \
		--exclude "README.md" \
		--exclude "LICENSE-MIT.txt" \
		-avh --no-perms . ~;

	# rsync runs with --no-perms, so the executable bit does not survive the
	# copy. Restore it on the scripts that need to be runnable in place.
	[ -f ~/.claude/statusline-command.sh ] && chmod +x ~/.claude/statusline-command.sh;

	if applyClaudeSettings; then
		echo "Merged ${REPO_CLAUDE_SETTINGS} into ~/.claude/settings.json";
	fi

  curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o ~/.git-completion.bash

	source ~/.bash_profile;
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	doIt;
elif showDiff; then
	doIt;
fi;
unset doIt;
unset showDiff;
unset mergeClaudeSettings;
unset claudeSettingsPending;
unset applyClaudeSettings;
