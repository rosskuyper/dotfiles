#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin main;

function showDiff() {
	local files
	files=$(rsync --exclude ".git/" \
		--exclude ".DS_Store" \
		--exclude ".vscode" \
		--exclude ".osx" \
		--exclude ".claude/" \
		--exclude "bootstrap.sh" \
		--exclude "README.md" \
		--exclude "LICENSE-MIT.txt" \
		-avh --dry-run --itemize-changes --no-perms . ~ 2>/dev/null \
		| grep '^>f' \
		| awk '{print $2}')

	if [ -z "$files" ]; then
		echo "All files are up to date. No changes needed.";
		return 1;
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
		--exclude ".claude/" \
		--exclude "bootstrap.sh" \
		--exclude "README.md" \
		--exclude "LICENSE-MIT.txt" \
		-avh --no-perms . ~;

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
