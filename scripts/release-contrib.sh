#!/bin/bash
#
# Make a release of a given contrib
#
# Usage:
#   scripts/release-contrib.sh <ContribName>

# get common definitions
. `dirname $0`/internal/common.sh

# make sure we have an argument and it exists
contrib=${1%/}
if [ -z $contrib ]; then
    echo "Usage:"
    echo "  release-contrib.sh <ContribName>"
    echo "A contrib name has to be specified"
    exit 1
fi

if [ ! -d $contrib ]; then
    echo "  $contrib does not exist"
    exit 1
fi


#------------------------------------------------------------------------
# make sure all the required files are present
cd $contrib
mandatory_files="AUTHORS COPYING NEWS README"
# one or other of VERSION or FJCONTRIB.cfg is mandatory
if [ -e VERSION ]; then
    mandatory_files="${mandatory_files} VERSION"
else
    mandatory_files="${mandatory_files} FJCONTRIB.cfg"
fi
# if both VERSION and FJCONTRIB.cfg are present, complain and abort
if [ -e VERSION ] && [ -e FJCONTRIB.cfg ]; then
    echo "Error: both VERSION and FJCONTRIB.cfg are present in $contrib" 
    echo "FJCONTRIB.cfg is the new form and is required if $contrib has dependencies on other contribs"
    cd ..
    exit 1
fi

missing_mandatory=""
missing_mandatory_on_svn=""
for fname in $mandatory_files; do
    if [[ ! -e ${fname} ]]; then
        missing_mandatory="${fname} ${missing_mandatory}"
    fi
    if [[ ! -z "`svn stat ${fname}`" ]]; then
        missing_mandatory_on_svn="${fname} ${missing_mandatory_on_svn}"
    fi
done
if [[ "x${missing_mandatory}" != "x" ]]; then
    echo "The following mandatory file(s) are missing: ${missing_mandatory}"
    cd ..
    exit 1
fi
if [[ "x${missing_mandatory_on_svn}" != "x" ]]; then
    echo "The following mandatory file(s) are not committed: ${missing_mandatory_on_svn}"
    cd ..
    exit 1
fi
cd ..

#------------------------------------------------------------------------
# make sure everything is committed
. `dirname $0`/internal/common.sh

check_pending_modifications $contrib || {
    echo "There are some pending modifications that need to be committed before the release"
    exit 1
}

#------------------------------------------------------------------------
# decide the version number
#version=`head -1 VERSION`
read_tag $contrib version version
cd $contrib

#------------------------------------------------------------------------
# ask confirmation that we can proceed with the release

get_yesno_answer "Releasing version $version of $contrib?" || {
    echo "Checking if there is not an already-existing tag with the same name:"
    if svn ls ${svn_read}/contribs/${contrib}/tags | grep -q "$version/" ; then
	echo "Failed. Release aborted!"
	cd ..
	exit 1
    fi
    echo "Ok... proceeding with the release"
    
    # do the release
    if ! svn copy -m "Released version $version of $contrib" . ${svn_write}/contribs/${contrib}/tags/${version} ; then
	echo "Release failed"
	cd ..
	exit 1
    fi
    echo "Release done"
}

cd ..
