#!/bin/bash
#
# make a full release of the current main branch
# Then produce a tarball

# include common Git utilities, etc.
. "$(dirname "$0")/common.sh"

# Uncomment to upload files to LPTHE rather than to HepForge
# In this case, make sure to make the appropriate modifications
# in generate-html-contents.pl (lpthe) and common.sh (fastjet_web_dir)
web_repo_name="LPTHE"
web_server="tycho.lpthe.jussieu.fr"
fastjet_web_dir="~salam/www/fastjet3/"

web_repo_name="Local"
web_server="localhost"
fastjet_web_dir="/tmp/fastjet3/"

# web_repo_name="HepForge"
# web_server="login.hepforge.org"
# fastjet_web_dir=/hepforge/projects/fastjet/public_html
###############################################

dry_run=0
allow_non_main=0
#only_upload=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        # --only-upload)
        #     only_upload=1
        #     echo "--------------------------------------------------"
        #     echo "      ONLY DOING UPLOAD OF EXISTING TARBALL       "
        #     echo "--------------------------------------------------"
        #     ;;
        --dry-run)
            dry_run=1
            echo "--------------------------------------------------"
            echo "                   DRY RUN                        "
            echo "--------------------------------------------------"
            ;;
        --allow-non-main)
            if get_yesno_answer "Allow this release from a non-main branch?"; then
                echo "Non-main release override not confirmed. Aborting"
                exit 1
            fi
            allow_non_main=1
            echo "WARNING: allowing a release from a non-main branch"
            ;;
        *)
            echo "Error in $0: unknown option $1"
            exit 1
            ;;
    esac
    shift
done

#========================================================================
# System sanity checks
#========================================================================
# sets the $tar variable and ensures that we have a GNU version. This avoids
# the default mac (BSD) tar, which includes info that Linux systems have
# a hard time handling.
find_gnu_tar 

#========================================================================
# Git sanity checks
#========================================================================

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "The top-level directory is not a Git checkout. Aborting"
    exit 1
fi

current_branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
if [[ -z "$current_branch" ]]; then
    echo "The top-level checkout is in detached HEAD state. Aborting"
    exit 1
fi
release_branch="main"
if [[ "$current_branch" != "main" && "$allow_non_main" -eq 0 ]]; then
    echo "The top-level checkout must be on the main branch. Aborting"
    echo "To override this check, rerun with --allow-non-main"
    exit 1
fi
if [[ "$current_branch" != "main" ]]; then
    release_branch="$current_branch"
    echo "WARNING: using $release_branch as the release source"
fi

top_repo_url=$(git remote get-url origin 2>/dev/null || true)
if [[ -z "$top_repo_url" ]]; then
    echo "The top-level checkout has no origin remote. Aborting"
    exit 1
fi

# Untracked contrib directories are expected during development; only tracked
# top-level changes prevent a release.
echo
echo "Checking for pending modifications or updates (this may take a few seconds...)"
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo
    echo "WARNING: There are pending tracked modifications:"
    echo
    git status --short --untracked-files=no
    echo
    get_yesno_answer "Are you really sure you want to proceed?" &&  exit 1
    echo
else
    echo "All tracked files are committed"
fi

# make sure there is a VERSION and it does not already exist
version=$(head -n1 VERSION)
if [[ -z "$version" ]] || ! git check-ref-format "refs/tags/$version" >/dev/null 2>&1; then
    echo "The top-level VERSION is missing or is not a valid Git tag. Aborting"
    exit 1
fi

if git show-ref --verify --quiet "refs/tags/$version"; then
    echo "Version $version of fjcontrib already exists locally. Aborting"
    exit 1
fi

remote_tag=""
if ! remote_tag=$(git ls-remote --tags origin "refs/tags/$version" 2>/dev/null); then
    echo "Could not query release tags from $top_repo_url. Aborting"
    exit 1
fi
if [[ -n "$remote_tag" ]]; then
    echo "Version $version of fjcontrib already exists remotely. Aborting"
    exit 1
fi

echo
echo "The contribs.svn file points to the following contrib versions"
echo
echo "----------------------------------------------------------------"
grep -v '^#' contribs.svn
echo "----------------------------------------------------------------"
echo

get_yesno_answer "Do you want to proceed with the release of fjcontrib-$version?" &&  exit 1

# Make sure the commit that will be tested is available from the remote.
git fetch origin "$release_branch" || { echo "Failed to fetch origin/$release_branch. Aborting"; exit 1; }
remote_branch=$(git rev-parse --verify "refs/remotes/origin/$release_branch" 2>/dev/null || true)
local_branch=$(git rev-parse "$release_branch")
if [[ -n "$remote_branch" ]] && ! git merge-base --is-ancestor "$remote_branch" "$release_branch"; then
    echo "Local $release_branch and origin/$release_branch have diverged. Aborting"
    exit 1
fi
if [[ "$local_branch" != "$remote_branch" ]]; then
    echo "Pushing $release_branch to $top_repo_url"
    git push -u origin "$release_branch" || { echo "Failed to push $release_branch. Aborting"; exit 1; }
fi


#========================================================================
# check that the tools in contribs.svn behave OK
#========================================================================
# get a clean Git checkout to perform sanity checks
if [[ -e "fjcontrib-$version" ]]; then
    echo "fjcontrib-$version already exists. Aborting"
    exit 1
fi
git clone --branch "$release_branch" "$top_repo_url" "fjcontrib-$version" || { echo "Failed to clone the top-level Git repository"; exit 1; }
cd fjcontrib-$version
echo "------------------------------------------------------------------------"
echo "Getting the contribs"
echo "------------------------------------------------------------------------"
if ./scripts/update-contribs.sh --force; then
    echo "Success."
    echo
else
    echo "Failed."
    echo
    cd ..
    exit 1
fi

echo "------------------------------------------------------------------------"
echo "Configuring"
echo "------------------------------------------------------------------------"

# we need to determine whether to use fastjet-config from the path or
# use the one from the configure invocation in the trunk
is_in_path="yes"
which fastjet-config > /dev/null || is_in_path="no"

trunk_version=""
if [[ -e "../Makefile" ]]; then
    trunk_version=$(head -n3 ../Makefile | tail -n1 | grep "\--fastjet-config=" | sed 's/.*--fastjet-config=//;s/ .*$//' || true)
fi

if [[ -z "$trunk_version" ]]; then
    if [[ "$is_in_path" == "no" ]]; then
	echo "fastjet-config is not in your path and cannot be obtained from the trunk configuration. Aborting."
	cd ..
	exit 1
    else
	echo "Using fastjet-config from your path"
	configure_options=""
    fi
else
    if [[ "$is_in_path" == "no" ]]; then
	echo "using fastjet-config from the trunk configuration"
	configure_options=" --fastjet-config=${trunk_version}"
    else
	echo "fastjet-config can be either taken from your path or from $trunk_version."
	configure_options=""
	get_yesno_answer "Do you want to use the one from your trunk?" || {
	    configure_options=" --fastjet-config=${trunk_version}"
	}
	    
    fi
fi

if ./configure $configure_options; then
    echo "Success."
    echo
else
    echo "Failed."
    echo
    cd ..
    exit 1
fi

echo "------------------------------------------------------------------------"
echo "Running make check"
echo "------------------------------------------------------------------------"
if make -j4 check; then
    echo "Success."
    echo
else
    echo "Failed."
    echo
    cd ..
    exit 1
fi

echo "------------------------------------------------------------------------"
echo "Running make fragile-shared"
echo "------------------------------------------------------------------------"
if make -j4 fragile-shared; then
    echo "Success."
    echo
else
    echo "Failed."
    echo
    cd ..
    exit 1
fi

cd ..
rm -Rf fjcontrib-$version
if [ -d fjcontrib-$version ]; then
    echo "fjcontrib-$version still present. Aborting"
fi

#========================================================================
# tag the release
#=======================================================================
if (( ${dry_run} )); then
    echo "Dry run: skipping the release tag"
else
    echo
    get_yesno_answer "Confirm you want to tag the release and make a tarball?" &&  exit 1
    echo
    
    echo "------------------------------------------------------------------------"
    echo "Making a tag of fjcontrib version $version"
    echo "------------------------------------------------------------------------"
    git tag -a "$version" -m "tagging fjcontrib-$version" || {
        echo "Failed to create tag $version"
        exit 1
    }
    git push origin "$version" || {
        echo "Failed to push tag $version"
        exit 1
    }
fi

#========================================================================
# produce a tarball
#========================================================================
if (( ${dry_run} )); then
    echo "------------------------------------------------------------------------"
    echo "Dry run: checking out $release_branch to build the fjcontrib tarball"
    echo "------------------------------------------------------------------------"
    echo git clone --branch "$release_branch" "$top_repo_url" "fjcontrib-$version"
    git clone --branch "$release_branch" "$top_repo_url" "fjcontrib-$version" || { echo "Failed to clone the top-level release branch"; exit 1; }
else
    echo "------------------------------------------------------------------------"
    echo "Checking out tag $version of fjcontrib"
    echo "------------------------------------------------------------------------"
    echo git clone --branch "$version" "$top_repo_url" "fjcontrib-$version"
    git clone --branch "$version" "$top_repo_url" "fjcontrib-$version" || { echo "Failed to clone the new released version $version"; exit 1; }
fi
cd fjcontrib-$version
echo

echo "------------------------------------------------------------------------"
echo "Getting the contribs"
echo "------------------------------------------------------------------------"
if ./scripts/update-contribs.sh --force; then
    echo "Success."
    echo
else
    echo "Failed."
    echo
    cd ..
    exit 1
fi

# # get rid of a few things for developers and "svn-users" only
# mkdir tmp
# for fn in check.sh install-sh; do
#     mv scripts/internal/${fn} ./tmp
# done
# rm -Rf scripts
# mkdir scripts
# mkdir scripts/internal
# for fn in tmp/*; do
#     mv $fn scripts/internal/${fn#tmp/}
# done
# rm DEVEL-GUIDELINES

cd ..
echo "------------------------------------------------------------------------"
echo "Producing fjcontrib-$version.tar.gz"
echo "------------------------------------------------------------------------"
# NB: $tar was set by find_gnu_tar
$tar --exclude=".git" \
    --exclude=".git/*" \
    --exclude="fjcontrib-$version/contribs.svn" \
  -czf fjcontrib-$version.tar.gz fjcontrib-$version
rm -Rf fjcontrib-$version
echo
echo "Success."
echo

#========================================================================
# update things on HepForge or LPTHE
#========================================================================
if (( ${dry_run} )); then
    echo "Dry run: not updating $web_repo_name"
    echo
    echo "Done"
    echo
    exit 0
fi

echo
get_yesno_answer "Confirm you want to upload to $web_repo_name?" &&  exit 1
echo
echo "------------------------------------------------------------------------"
echo "Uploading to $web_repo_name"
echo "------------------------------------------------------------------------"

echo "Uploading fjcontrib-$version.tar.gz"
scp fjcontrib-$version.tar.gz $web_server:$fastjet_web_dir/contrib/downloads/

mkdir hepforge_tmp
echo "Generating info for the webpage"
echo -n "$version" > hepforge_tmp/fjcversion.php
`dirname $0`/generate-html-contents.pl > hepforge_tmp/contents-$version.html
reldate=`date +"%e %B %Y"`
echo -n $reldate  > hepforge_tmp/fjcreldate.php

echo "Uploading info for the webpage"
scp hepforge_tmp/fjcversion.php hepforge_tmp/fjcreldate.php $web_server:$fastjet_web_dir/contrib/
scp hepforge_tmp/contents-$version.html $web_server:$fastjet_web_dir/contrib/contents/$version.html


echo "Ensuring fastjet group write access for new files on $web_repo_name"
# the following is needed because group sticky bit is erroneously not set
# on the fastjet downloads directory, so group does not get set to fastjet
#ssh login.hepforge.org chgrp fastjet "~fastjet/downloads/fjcontrib-$version.tar.gz"
# now give fastjet group write permission on these files (and read for everyone)
# Owner: rw- = 6 (4+2)
# Group: rw- = 6 (4+2)
# Others: r-- = 4
ssh $web_server chmod 664 "$fastjet_web_dir/contrib/fjcversion.php" "$fastjet_web_dir/contrib/fjcreldate.php" "$fastjet_web_dir/contrib/contents/$version.html" "$fastjet_web_dir/contrib/downloads/fjcontrib-$version.tar.gz"
rm -Rf hepforge_tmp
echo
echo "Done"
echo
