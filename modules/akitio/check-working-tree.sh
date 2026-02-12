#!/bin/sh

# note: ensure "world/" is ignored in .gitignore

C="$1"

err() { printf '\033]31m[ERROR]]\033[0m[check-working-tree.sh][%s] %s\n' "$C" "$*"; }
inf() { printf '[INFO][check-working-tree.sh][%s] %s\n' "$C" "$*"; }
war() { printf '\033[33m[WARN]\033[0m[check-working-tree.sh][%s] %s\n' "$C" "$*"; }
ok() { printf '\033[32m[ OK ]\033[0m[check-working-tree.sh][%s] %s\n' "$C" "$*"; }
 

# set -eu

# paths
REPO_PATH="$HOME/storage/git/akitio-server.git"
WORKING_TREE="$1"

# check if repo exists
if [ ! -d "$REPO_PATH" ]; then
	err "Repository does not exist at $REPO_PATH."
	exit 1
fi

# clone or update repo
if [ -d "$WORKING_TREE/.git" ]; then
	inf "Checking integrity of $C git working tree."
	
	git fetch origin >/dev/null 2>&1

	# check for differences in working tree vs master	
	DIFF_STATUS=$(git -C "$WORKING_TREE" status --porcelain | grep -E '^(M|D|.M|.D)')	
	
	# check for git object corruption
	git fsck --full >/dev/null 2>&1 || FSCK_STATUS=$?

	if [ -n "$DIFF_STATUS" ] || [ "$FSCK_STATUS" ]; then
		inf "The working tree is either outdated or corrupt. Fixing tracked files and Git objects..."
		git -C $WORKING_TREE checkout HEAD -- .	
		
		# re-run fsck to confirm 
		git fsck --full >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			inf "Repository was fixed and working tree is up to date."
		else 
			war "Repository still has corrupt files after fix!"
			war "Aborting..."
			exit 1
		fi
	fi
else
	inf "Working tree not found..."
	inf "Cloning repository..."
	git clone "$REPO_PATH" "$WORKING_TREE"
fi

ok "Repository of volume $C safe."
