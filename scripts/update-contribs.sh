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

. `dirname $0`/internal/common.sh

internal_directories="_,scripts,Template,data,_"

#----------------------------------------------------------------------
# update svn
svn up || { echo "Failed to update svn. Aborting"; exit 1; }

#----------------------------------------------------------------------
# if there is a single argument or two, jsut call switch-to-version
if [[ $# -gt 0 ]]; then
    # just call switch-to-version
    `dirname $0`/switch-to-version.sh $*
    exit 0
fi

#----------------------------------------------------------------------
# update all the contribs in the contribs.svn file
svn_contrib_list=$(cat contribs.svn | grep -v '^#' | grep -v '^$' | awk '{print $1}')
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
	echo "you have the current version (${version_svn})"
    else
	# mismatch: show the versions and decide what to do
	# according to the type of mismatch
	echo ""
	echo "    svn   version: "${version_svn}
	echo "    local version: "${version_local}
	if [[ "${version_local}" == "[None]" ]]; then
	    # the local version does not exist! Ask if we want to install it
	    get_yesno_answer "  Do you want to install the svn version?" || {
		`dirname $0`/switch-to-version.sh $contrib $version_svn
	    }
	elif [[ "${version_local}" == "[NoSVN]" ]]; then
	    echo "You have an unversionned copy of $contrib in the way. It will not be updated."
	else
	    # the local version exists! Ask if we want to update it
	    get_yesno_answer "  Do you want to update your local version to the svn one?" || {
		`dirname $0`/switch-to-version.sh $contrib $version_svn
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
