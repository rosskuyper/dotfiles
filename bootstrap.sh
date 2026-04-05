#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin main;

function showDiff() {
	local files
	files=$(rsync --exclude ".git/" \
		--exclude ".DS_Store" \
		--exclude ".vscode" \
		--exclude ".osx" \
		--exclude "bootstrap.sh" \
		--exclude "README.md" \
		--exclude "LICENSE-MIT.txt" \
		--dry-run --itemize-changes --no-perms . ~ 2>/dev/null \
		| grep '^>f' \
		| awk '{print $2}')

	if [ -z "$files" ]; then
		echo "All files are up to date. No changes needed.";
		return;
	fi

	echo "The following files would change in your home directory:";
	echo "";

	while IFS= read -r file; do
		if [ -f "$HOME/$file" ]; then
			diff -u "$HOME/$file" "$file";
			echo "";
		else
			echo "+++ ~/$file (new file)";
			echo "";
		fi
	done <<< "$files"
}

function doIt() {
	rsync --exclude ".git/" \
		--exclude ".DS_Store" \
		--exclude ".vscode" \
		--exclude ".osx" \
		--exclude "bootstrap.sh" \
		--exclude "README.md" \
		--exclude "LICENSE-MIT.txt" \
		-avh --no-perms . ~;

  curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o ~/.git-completion.bash

	source ~/.bash_profile;
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	doIt;
else
	showDiff;
	read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
	echo "";
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		doIt;
	fi;
fi;
unset doIt;
unset showDiff;
