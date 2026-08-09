#!/bin/bash
#
# Usage:
#  update-contribs.sh
#
# update the list of all contribs.
# 
# This does the following
#
#  - update the top-level Git checkout to get the latest scripts and list
#
#  - build the list of contribs:
#     . by default, these are read from 'contribs.svn'
#     . local requests can be specified in 'contribs.local'
#       (in which case they take precedence)
#
#  - for all the contribs that have to be updated, check the currently
#    installed version and, if it does not match the one in
#    contribs.svn (or contribs.local), ask if the user wants to update
#    them. If yes, update the installed version.
#
# parse some command line options of the form
#   update-contribs.sh -<option>
#
# supported options at the moment are
#   -h      show a help message
#   --force assume the answer to every question is "yes"
if [[ $# -ge 1 && x"$1" == x'-h' ]]; then
    echo
    echo "Usage: "
    echo "       $0 [--force] [ContribName [version]] "
    echo 
    echo "- without any arguments, all contribs are updated (or downloaded if missing)"
    echo "- with the ContribName argument, just that contrib is updated"
    echo "- with additionally the version argument, the contrib is updated"
    echo "  (or switched) to the requested version. E.g. 'trunk' or 'tags/1.0' "
    echo
    exit 0
fi
default_yesno_answer=""
if [[ $# -ge 1 && x"$1" == x'--force' ]]; then
    echo "Assuming 'yes' as an answer to all questions"
    default_yesno_answer="yes"
    shift
fi
. `dirname $0`/internal/common.sh
    
internal_directories="_,scripts,Template,data,_"

#----------------------------------------------------------------------
# update the top-level Git checkout when it has an upstream branch
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    script_current_version=$(git rev-parse HEAD)

    echo "-----------------------------"
    echo "Updating top-level directory:"
    echo "-----------------------------"
    if git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' > /dev/null 2>&1; then
        git pull --ff-only || { echo "Failed to update the top-level Git checkout. Aborting"; exit 1; }
    else
        echo "No upstream branch is configured; skipping top-level Git update"
    fi

    # check if this script has been updated
    script_new_version=$(git rev-parse HEAD)
    if [[ "$script_new_version" != "$script_current_version" ]]; then
        echo "update-contribs.sh has been updated. Re-running the new version."
        "$0" "$@" || { exit 1;}
        exit 0
    fi
else
    echo "No Git checkout found, skipping update of the top-level repository"
fi

#----------------------------------------------------------------------
# if there are two arguments, just call switch-to-version

if [[ $# -gt 1 ]]; then

    # just call switch-to-version
    "$(dirname "$0")/internal/switch-to-version.sh" "$@" || exit 1
    exit 0
fi

#----------------------------------------------------------------------
# update all the contribs in the contribs.svn file (plus the ones in contribs.local) or only the one
# specified through the command line
if [[ $# -gt 0 ]]; then
    contribs_list=$1
else
    contribs_list=$(cat contribs.svn | grep -v '^#' | grep -v '^$' | awk '{print " "$1" "}')
    # Check if a contribution mentioned in contribs.local was already present in contribs.svn
    # Only add the entry to contribs_list if it wasn't there before (the version number will
    # be dealt with later on)
    if [[ -e contribs.local ]]; then
      for contrib_in_local in `cat contribs.local | grep -v '^#' | grep -v '^$' | awk '{print $1}'`; do
	if [[ " $contribs_list " != *" $contrib_in_local "* ]]; then
	   contribs_list=$contribs_list" $contrib_in_local"
        fi
      done	
    fi		
fi 

echo
echo "--------------------------------------------"
echo "Checking for updates of individual contribs:"
echo "--------------------------------------------"
for contrib in $contribs_list; do
    # get the version numbers in contribs.svn file and also from the locally
    # checked out contributions
    get_contrib_version ${contrib} contribs.svn   version_svn
    get_contrib_version ${contrib} local_git version_local
    get_contrib_version ${contrib} contribs.local version_mine

    echo
    echo -n "${contrib}: "
    
    # if thers is a line in contribs.local, use the version specified there
    # to supersede the one in contribs.svn (which could be implicitly [None],
    # i.e. a particular contribution could be not mentioned there)
    requested_tag="default"
    old_version=""
    if [[ "${version_mine}" != "[None]" ]]; then 
        old_version="  [Overriding $version_svn from contribs.svn]" 
        version_svn="$version_mine"
	requested_tag="requested"
    fi
    
    # check which situation we are in
    if [[ "${version_svn}" == "${version_local}" ]]; then
        # match: nothing to do
	if [[ "$version_svn" != "["*"]" ]]; then
	    echo -e "you already have the $requested_tag version (${version_svn}).\nUpdating it"
	    "$(dirname "$0")/internal/switch-to-version.sh" "$contrib" "$version_svn" || exit 1
	else 
	    echo "you already have the $requested_tag version (${version_svn})"
	fi	
    else
        #skip this particular contribution (flagged by at least a "-" in place of the version number)
        if [[ "${version_svn}" =~ ^-+ ]]; then echo "Skipped"; continue; fi
	    
	# mismatch: show the versions and decide what to do
	# according to the type of mismatch
	echo ""
	echo "    $requested_tag version: "${version_svn}$old_version
	echo "    installed version: "${version_local}
	if [[ "${version_local}" == "[None]" ]]; then
	    # the local version does not exist! Ask if we want to install it
	    #get_yesno_answer "  Do you want to install the $requested_tag version?" "$default_yesno_answer" || {
	    "$(dirname "$0")/internal/switch-to-version.sh" "$contrib" "$version_svn" || exit 1
	    #}
	elif [[ "${version_local}" == "[NoGit]" ]]; then
	    echo "You have an unversioned copy of $contrib in the way. It will not be updated."
	else
	    # the local version exists! Ask if we want to update it
	    get_yesno_answer "  Switch from the installed version to the $requested_tag one?" "$default_yesno_answer" || {
		"$(dirname "$0")/internal/switch-to-version.sh" "$contrib" "$version_svn" || exit 1
	    }
	fi
        echo
    fi
done

#----------------------------------------------------------------------
# now do the opposite: for each local contrib, check if it exists in
# the supported lists
#
# Note that we discard any directory that does not point to a tagged
# version of a contrib

for contrib_path in */; do
    [[ -d "$contrib_path" ]] || continue
    contrib=${contrib_path%/}
    # discard the fjcontrib dirs
    if [[ "$internal_directories" == *",${contrib},"* ]]; then
	continue
    fi

    get_git_info "$contrib" mode version

    get_contrib_version "$contrib" contribs.svn configured_version
    if [[ "$version" == "tags/"* && ( "$configured_version" == "[None]" || "$configured_version" =~ ^-+ ) ]]; then
	echo "${contrib}: your local copy ($version) does not appear in the default Git-supported list."
	get_yesno_answer "  Do you want to remove the local version?" "$default_yesno_answer" || {
	    rm -Rf $contrib
	}
	echo
    fi
done
echo
