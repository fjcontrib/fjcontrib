#!/bin/bash
#
# Usage:
#  register-new-contrib.sh <ContribName>
#
# uploads a new contrib to the svn. Note that only the svn directory
# structure will be created and the files in the contrib's directory
# will be simply moved locally but not added to the svn repository.
#
# At the end of the procedure, the Contrib's directory will point to
# the trunk

# make sure we have an argument
contrib=$1
if [ -z $contrib ]; then
    echo "Usage:"
    echo "  register-new-contrib.sh <ContribName>"
    echo "A contrib name has to be specified"
    exit 1
fi

echo "Starting uploading contrib $contrib"
echo ""

# check that the contrib name exist locally
echo "  performing sanity checks"
if [ ! -d $contrib ]; then
    echo "  $contrib does not exist locally"
    exit 1
fi

# load common setup
. `dirname $0`/internal/common.sh

# check that the current contrib does not exist
if [ ! -z "`svn ls $svn_read/contribs | grep '^'$contrib'/$'`" ]; then
    echo "  $contrib is the name of an already-existing contrib. Aborting..."
    exit 1
fi

#TODO check that the directory contains "expected" files

# create the svn structure for that contrib
echo "  Creating the svn folder structure (a password may be requested)"
svn mkdir -m "Creating the basic svn structure for contrib $contrib" \
    $svn_write/contribs/$contrib \
    $svn_write/contribs/$contrib/trunk \
    $svn_write/contribs/$contrib/tags \
    $svn_write/contribs/$contrib/branches \
 || { echo "Failed to create the svn directory structure. Aborting."; exit 1;}

# now we need to have "contrib" point to that svn location.
#  - move the existing one out of the way
echo "  Creating a backup ${contrib}.bak"
mv $contrib ${contrib}.bak

#  - make a checkout
echo "  Checking out the svn trunk (a password may be requested)"
svn co ${svn_write}/contribs/$contrib/trunk $contrib

# and finally, add all the contrib files to the svn
default_dotglob_status="-u"
if [ -z "`shopt dotglob | grep "off"`" ]; then
    default_dotglob_status="-s"
fi
shopt -s dotglob
mv ${contrib}.bak/* ${contrib}
shopt $default_dotglob_status dotglob

echo "${contrib}.bak should now be empty and all files moved in $contrib which is under svn"
echo "Please proceed with the development"
