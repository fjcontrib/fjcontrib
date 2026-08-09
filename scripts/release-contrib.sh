#!/bin/bash
#
# Make a release of a given contrib
#
# Usage:
#   scripts/release-contrib.sh <ContribName>

. "$(dirname "$0")/internal/common.sh"

contrib=${1:-}
contrib=${contrib%/}
if [[ -z "$contrib" ]]; then
    echo "Usage:"
    echo "  release-contrib.sh <ContribName>"
    echo "A contrib name has to be specified"
    exit 1
fi

if [[ ! -d "$contrib" ]]; then
    echo "  $contrib does not exist"
    exit 1
fi

#------------------------------------------------------------------------
# make sure the contribution is a Git checkout on main
if ! git -C "$contrib" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "$contrib is not a Git checkout"
    exit 1
fi

branch=$(git -C "$contrib" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
if [[ "$branch" != "main" ]]; then
    if [[ -z "$branch" ]]; then
        echo "$contrib is not on the main branch (detached HEAD)"
    else
        echo "$contrib is on branch '$branch', not main"
    fi
    exit 1
fi

if ! git -C "$contrib" remote get-url origin >/dev/null 2>&1; then
    echo "$contrib does not have an origin remote"
    exit 1
fi

#------------------------------------------------------------------------
# make sure all the required files are present and tracked
cd "$contrib" || exit 1
mandatory_files="AUTHORS COPYING NEWS README"
if [[ -e VERSION ]]; then
    mandatory_files="$mandatory_files VERSION"
else
    mandatory_files="$mandatory_files FJCONTRIB.cfg"
fi

if [[ -e VERSION && -e FJCONTRIB.cfg ]]; then
    echo "Error: both VERSION and FJCONTRIB.cfg are present in $contrib"
    echo "FJCONTRIB.cfg is the new form and is required if $contrib has dependencies on other contribs"
    cd ..
    exit 1
fi

missing_mandatory=""
missing_mandatory_from_git=""
for fname in $mandatory_files; do
    if [[ ! -e "$fname" ]]; then
        missing_mandatory="$fname $missing_mandatory"
    elif ! git ls-files --error-unmatch -- "$fname" >/dev/null 2>&1; then
        missing_mandatory_from_git="$fname $missing_mandatory_from_git"
    fi
done
if [[ -n "$missing_mandatory" ]]; then
    echo "The following mandatory file(s) are missing: $missing_mandatory"
    cd ..
    exit 1
fi
if [[ -n "$missing_mandatory_from_git" ]]; then
    echo "The following mandatory file(s) are not tracked by Git: $missing_mandatory_from_git"
    cd ..
    exit 1
fi
cd ..

#------------------------------------------------------------------------
# make sure everything is committed
check_pending_modifications "$contrib" || {
    echo "There are some pending modifications that need to be committed before the release"
    exit 1
}

#------------------------------------------------------------------------
# decide the version number from inside the contribution
read_tag "$contrib" version version
if [[ -z "$version" ]]; then
    echo "Could not determine a version for $contrib"
    exit 1
fi
if ! git check-ref-format "refs/tags/$version" >/dev/null 2>&1; then
    echo "Version '$version' is not a valid Git tag name"
    exit 1
fi

repo_url=$(git -C "$contrib" remote get-url origin)

#------------------------------------------------------------------------
# ask confirmation that we can proceed with the release
get_yesno_answer "Releasing version $version of $contrib?" || {
    echo "Checking if there is not an already-existing tag with the same name:"

    if git -C "$contrib" show-ref --verify --quiet "refs/tags/$version"; then
        echo "Failed. Release aborted: local tag $version already exists!"
        exit 1
    fi

    remote_tags_status=0
    remote_tag=$(git -C "$contrib" ls-remote --tags origin "refs/tags/$version" 2>/dev/null) || remote_tags_status=$?
    if [[ "$remote_tags_status" -ne 0 && "$remote_tags_status" -ne 2 ]]; then
        echo "Failed to query tags from $repo_url. Release aborted!"
        exit 1
    fi
    if [[ -n "$remote_tag" ]]; then
        echo "Failed. Release aborted: remote tag $version already exists!"
        exit 1
    fi

    echo "Checking whether main has been pushed to the remote:"
    git -C "$contrib" fetch origin main || {
        echo "Failed to fetch main from $repo_url. Release aborted!"
        exit 1
    }

    remote_main=$(git -C "$contrib" rev-parse --verify refs/remotes/origin/main 2>/dev/null || true)
    local_main=$(git -C "$contrib" rev-parse main)
    if [[ "$local_main" != "$remote_main" ]]; then
        if [[ -n "$remote_main" ]] && ! git -C "$contrib" merge-base --is-ancestor "$remote_main" main; then
            echo "Local main and origin/main have diverged. Release aborted!"
            exit 1
        fi
        echo "Pushing main to $repo_url"
        git -C "$contrib" push -u origin main || {
            echo "Failed to push main. Release aborted!"
            exit 1
        }
    else
        echo "main is already up to date on the remote"
    fi

    echo "Ok... proceeding with the release"
    if ! git -C "$contrib" tag -a "$version" -m "Released version $version of $contrib"; then
        echo "Release failed while creating tag $version"
        exit 1
    fi
    if ! git -C "$contrib" push origin "$version"; then
        echo "Release failed while pushing tag $version"
        exit 1
    fi
    echo "Release done"
}

exit 0
