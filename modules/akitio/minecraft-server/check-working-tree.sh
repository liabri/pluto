#!/bin/sh

# note: ensure "world/" is ignored in .gitignore

set -eu

# paths
REPO_PATH="/home/liam/pods/eligius/git/akitio-server.git"
WORKING_TREE="/home/liam/pods/akitio/minecraft-server/working-tree"

# check if repo exists
if [ ! -d "$REPO_PATH" ]; then
	echo "Error: Repository does not exist at $REPO_PATH" >&2
	exit 1
fi

# clone or update repo
if [ -d "$WORKING_TREE/.git" ]; then
	echo "Checking if local working tree is up to date and integral"
	
	git fetch origin >/dev/null 2>&1

	# check for differences in working tree vs master	
	DIFF_STATUS=$(git -C "$WORKING_TREE" status --porcelain | grep -E '^[ MD][MD]')	

	# check for git object corruption
	git fsck --full >/dev/null 2>&1 || FSCK_STATUS=$?

	if [ -n "$DIFF_STATUS" ] || [ "$FSCK_STATUS" ]; then
		echo "Fixing tracked files and Git objects..."
		git -C $WORKING_TREE checkout HEAD -- .	
		
		# re-run fsck to confirm 
		git fsck --full >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Repository was fixed and working tree is up to date"
		else 
			echo "Warning: Repository still has corrupt files after fix!"
			echo "Aborting..."
			exit 1
		fi
	else 
		echo "Working tree matches bare repo and Git objects are OK."
	fi
else
	echo "Working tree not found..."
	echo "Cloning repository..."
	git clone "$REPO_PATH" "$WORKING_TREE"
fi

echo "Repository setup complete"
