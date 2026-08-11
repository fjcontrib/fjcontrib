#!/bin/bash
#
# Usage:
#   switch-to-version.sh ContribName [version]
#
# Check out or switch a contribution hosted at GitHub.  The historical
# contribs.svn spelling is retained: trunk means the Git main branch,
# tags/<version> means a Git tag, and branches/<name> means a Git branch.

set -u

. "$(dirname "$0")/common.sh"

force_update=0
if [[ "${1:-}" == "--force" ]]; then
    force_update=1
    shift
fi

contrib=${1:-}
contrib=${contrib%/}
if [[ -z "$contrib" ]]; then
    echo "A contrib name has to be specified"
    exit 1
fi

requested_version=${2:-}
if [[ -z "$requested_version" ]]; then
    get_contrib_version "$contrib" contribs.svn requested_version
    if [[ "$requested_version" == "[None]" ]]; then
        echo "$contrib is not listed in contribs.svn. Specify a version explicitly."
        exit 1
    fi
    echo "  Using version $requested_version"
fi

git_ref=""
ref_kind=""
case "$requested_version" in
    trunk|main)
        git_ref="main"
        ref_kind="branch"
        ;;
    tags/*)
        git_ref="${requested_version#tags/}"
        ref_kind="tag"
        ;;
    branches/*)
        git_ref="${requested_version#branches/}"
        ref_kind="branch"
        ;;
    [0-9]*)
        git_ref="$requested_version"
        ref_kind="tag"
        ;;
    -*|\[*)
        echo "Invalid version '$requested_version' for $contrib"
        exit 1
        ;;
    *)
        echo "Version must be trunk, a tag, or branches/<name>"
        exit 1
        ;;
esac

repo_url=$(get_contrib_repo_url "$contrib")

local_ref_exists(){
    if [[ "$ref_kind" == "branch" ]]; then
        git show-ref --verify --quiet "refs/remotes/origin/$git_ref" || \
            git show-ref --verify --quiet "refs/heads/$git_ref"
    else
        git show-ref --verify --quiet "refs/tags/$git_ref"
    fi
}

checkout_requested_ref(){
    if [[ "$ref_kind" == "branch" ]]; then
        git checkout "$git_ref" 2>/dev/null || \
            git checkout -b "$git_ref" --track "origin/$git_ref" || return 1
        git branch --set-upstream-to="origin/$git_ref" "$git_ref" >/dev/null 2>&1 || true
    else
        git checkout --detach "tags/$git_ref"
    fi
}

get_git_info "$contrib" current_mode current_version
if [[ "$current_version" == "[NoGit]" ]]; then
    echo "You appear to have an unversioned copy of $contrib."
    echo "Please move it out of the way before installing a Git checkout."
    exit 1
fi

if [[ "$current_version" == "[None]" ]]; then
    echo "  Checking out $contrib from $repo_url"
    git clone "$repo_url" "$contrib" || {
        echo "Failed to clone $repo_url"
        exit 1
    }
    cd "$contrib" || exit 1
    git fetch --tags origin || exit 1
    local_ref_exists || {
        echo "Version '$requested_version' of $contrib does not exist in the Git repository."
        exit 1
    }
    checkout_requested_ref || {
        echo "Failed to check out $requested_version of $contrib"
        exit 1
    }
    cd ..
    exit 0
fi

if ! check_pending_modifications "$contrib"; then
    if [[ "$force_update" -eq 1 ]]; then
        echo "Assuming 'yes' and proceeding with local modifications"
    else
        get_yesno_answer "Your local copy has modifications. Do you want to proceed with the update?" && {
            echo "Aborting."
            exit 1
        }
    fi
fi

cd "$contrib" || exit 1
remote_url=$(git remote get-url origin 2>/dev/null || true)
if [[ -n "$remote_url" && "$remote_url" != "$repo_url" ]]; then
    echo "The origin for $contrib is $remote_url, not $repo_url"
    cd ..
    exit 1
fi

echo "  Fetching updates for $contrib"
git fetch --tags origin || {
    echo "Failed to fetch $repo_url"
    cd ..
    exit 1
}

if ! local_ref_exists; then
    echo "Version '$requested_version' of $contrib does not exist in the Git repository."
    cd ..
    exit 1
fi

if [[ "$requested_version" == "$current_version" ]]; then
    if [[ "$ref_kind" == "branch" ]]; then
        git pull --ff-only origin "$git_ref" || {
            echo "Failed to fast-forward $contrib"
            cd ..
            exit 1
        }
    else
        echo "  Already at the requested version."
    fi
    cd ..
    exit 0
fi

checkout_requested_ref || {
    echo "Failed to switch $contrib to $requested_version"
    cd ..
    exit 1
}
cd ..
