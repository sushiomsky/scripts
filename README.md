handy-bash-scripts
==================

This is a collection of some of my handy Bash scripts for doing common tasks.

Top recommended scripts:

1\. findref.bash - recursively greps files in a folder looking for the specified regex.  Files can be excluded from the search by regular expression also.  Functions a lot like `git grep` but adds color and is not restricted to a git repo

3\. backup.bash - Ever planned on updating some config files or other system files but wanted to make a backup in case something went wrong?  This script makes it a piece of cake.  No more copying and renaming and then hunting later.  This script will back up the directory or file in ~/.backups/

4\. updateRepos.bash - If you have a lot of git repos cloned, run this script from the root directory.  It will recurse into the git clones below and do a pull and optionally a push.  If you have un-committed changes they will be stashed while your repo is updated, and restored when finished.  you'll also be notified in case you forgot they were there.  I use this one several times a day.

There are lots more scripts, but those are the highlights.
