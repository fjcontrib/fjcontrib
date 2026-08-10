#!/bin/bash
#
# Check if the versions in contribs.svn correspond to the latest Git tags.

if command -v tput >/dev/null 2>&1; then
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
    NORMAL=$(tput sgr0)
else
    GREEN=""
    RED=""
    NORMAL=""
fi
. "$(dirname "$0")/common.sh"

get_latest_git_tag(){
    local contrib=$1
    local repo_url
    local tag_output

    repo_url=$(get_contrib_repo_url "$contrib")
    if ! tag_output=$(git ls-remote --tags "$repo_url" 2>&1); then
        echo "[Error]"
        echo "${contrib}: failed to query tags from ${repo_url}: ${tag_output}" >&2
        return 0
    fi

    printf '%s\n' "$tag_output" |
        awk '
            $2 !~ /\^\{\}$/ {
                tag=$2
                sub("^refs/tags/", "", tag)
                if (tag ~ /^[0-9]+\.[0-9]+\.[0-9]+$/) print tag
            }
        ' |
        sort -t. -k1,1n -k2,2n -k3,3n |
        tail -n1
}

printf "  %-35s %-15s %-15s\n" "contrib" "contribs.svn" "git tag"
printf "  %-35s %-15s %-15s\n" "-------" "------------" "-------"
check_status=0

# contribs.svn is the maintained list of contributions.  Git itself has no
# equivalent of the old central SVN contribs/ directory listing.
while read -r contrib; do
    [[ -n "$contrib" ]] || continue

    get_contrib_version "$contrib" contribs.svn version_included
    version_included=${version_included##*/}
    version_tag=$(get_latest_git_tag "$contrib")

    if [[ "$version_included" == "$version_tag" ]]; then
        col=$GREEN
    elif [[ "$version_included" == "[None]" ]]; then
        if [[ -z "$version_tag" ]]; then
            col=$NORMAL
        else
            col=$RED
            check_status=1
        fi
    elif [[ "$version_included" =~ ^-+ ]]; then
        # A skipped contribution has no required release version.
        col=$NORMAL
    elif [[ "$version_tag" == "[Error]" ]]; then
        col=$RED
        check_status=1
    elif [[ "$version_included" > "$version_tag" ]]; then
        col=$NORMAL
    else
        col=$RED
        check_status=1
    fi
    printf "%s  %-35s %-15s %-15s%s\n" "$col" "$contrib" "$version_included" "$version_tag" "$NORMAL"
done < <(awk '!/^[[:space:]]*#/ && NF {print $1}' contribs.svn)

exit "$check_status"
