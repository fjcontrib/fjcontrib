#!/bin/bash
#
# Usage:
#  update-contribs.sh
#
# update the list of all contribs.
# 
# This does the following
#  - run svn up to get the updates of all the scripts and latest contrib list
#  - updates the local list of contribs:
#    . For the first checkout, the list of contribs will be copied in
#      a contribs.local
#    . for future checkouts, checks all potential updates and ask you
#      what to do in case of doubt
#  - for all the contribs that have to be updated, check that there is
#    no modification in their svn
#  - update all the contribs that need to be updated

if [[ $# -ge 1 && x"$1" == x'-h' ]]; then
    echo
    echo "Usage: "
    echo "       $0 [ContribName [version]] "
    echo 
    echo "- without any arguments, all contribs are updated (or downloaded if missing)"
    echo "- with the ContribName argument, just that contrib is updated"
    echo "- with additionally the version argument, the contrib is updated"
    echo "  (or switched) to the requested version. E.g. 'trunk' or 'tags/1.0' "
    echo
    exit 0
fi

. `dirname $0`/internal/common.sh

internal_directories="_,scripts,Template,data,_"

#----------------------------------------------------------------------
# update svn

# get the revision of this file
script_current_version=$(svn info $0 | grep "^Revision: " | sed 's/Revision: //')

# perform the svn update
svn up || { echo "Failed to update svn. Aborting"; exit 1; }

# check if this script has been updated
script_new_version=$(svn info $0 | grep "^Last Changed Rev: " | sed 's/Last Changed Rev: //')
if [[ "$script_new_version" -gt "$script_current_version" ]]; then
    echo "update-contribs.sh has been updated. Re-running the new version."
    $0 || { exit 1;}
    exit 0
fi

#----------------------------------------------------------------------
# if there are two arguments, just call switch-to-version

if [[ $# -gt 1 ]]; then

    # just call switch-to-version
    `dirname $0`/internal/switch-to-version.sh $*
    exit 0
fi

#----------------------------------------------------------------------
# update all the contribs in the contribs.svn file or only the one
# specified through the command line
if [[ $# -gt 0 ]]; then
    svn_contrib_list=$1
else
    svn_contrib_list=$(cat contribs.svn | grep -v '^#' | grep -v '^$' | awk '{print $1}')
fi

echo "Checking for updates"
echo
for contrib in $svn_contrib_list; do
    # get the version numbers in both contrib files
    get_contrib_version ${contrib} contribs.svn   version_svn
    get_contrib_version ${contrib} contribs.local version_local

    echo -n "${contrib}: "

    # check which situation we are in
    if [[ "${version_svn}" == "${version_local}" ]]; then
        # match: nothing to do
	if [[ "$version" != "["*"]" ]]; then
	    echo "you have the current version (${version_svn}). Running svn up"
	    cd $contrib
	    svn up
	    cd ..
	else 
	    echo "you have the current version (${version_svn})"
	fi	
    else
	# mismatch: show the versions and decide what to do
	# according to the type of mismatch
	echo ""
	echo "    svn   version: "${version_svn}
	echo "    local version: "${version_local}
	if [[ "${version_local}" == "[None]" ]]; then
	    # the local version does not exist! Ask if we want to install it
	    get_yesno_answer "  Do you want to install the svn version?" || {
		`dirname $0`/internal/switch-to-version.sh $contrib $version_svn
	    }
	elif [[ "${version_local}" == "[NoSVN]" ]]; then
	    echo "You have an unversionned copy of $contrib in the way. It will not be updated."
	else
	    # the local version exists! Ask if we want to update it
	    get_yesno_answer "  Do you want to update your local version to the svn one?" || {
		`dirname $0`/internal/switch-to-version.sh $contrib $version_svn
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

for contrib in $(ls -d */ || sed 's/\/*//g'); do
    # discard the fjcontrib dirs
    if [[ "$internal_directories" == *",${contrib},"* ]]; then
	continue
    fi

    get_svn_info $contrib mode version

    if [[ "$version" == "tags/"* ]]; then
	echo "${contrib}: your local copy ($version) does not appear in the default svn-suppoerted list."
	get_yesno_answer "  Do you want to remove the local version?" || {
	    rm -Rf $contrib
	}
	echo
    fi
done
echo
