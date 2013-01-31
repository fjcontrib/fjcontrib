#!/bin/bash
#
# make a full release of the current trunk
# Then produce a tarball

#========================================================================
# svn sanity checks
#========================================================================

# make sure that everything is committed
if [[ ! -z "`svn status --show-updates | grep -v "^?" | grep -v "^Status"`" ]]; then
    echo "There are pending morifications or updates. Aborting"
    exit 1
fi
. `dirname $0`/common.sh
get_yesno_answer "Do you want to proceed with the release of fjcontrib-$version?" &&  exit 1

# make sure there is a VERSION and it does not already exist
version=`head -n1 VERSION`
if [[ ! -z $(svn ls $svn_read/tags || grep "^$version/") ]]; then
    echo "Version $version of fjcontrib already exists. Aborting"
    exit 1
fi

#========================================================================
# check that the tools in contribs.list behave OK
#========================================================================
# get a clean checkout to perform sanity checks
svn co $svn_read/trunk fjcontrib-$version || { echo "Failed to do the svn checkout"; exit 1; }
cd fjcontrib-$version
echo "------------------------------------------------------------------------"
echo "Getting the contribs"
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
if ./configure; then
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
if make check; then
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
echo "------------------------------------------------------------------------"
echo "Releasing the fjcontrib version $version"
svn copy -m "releasing fjcontrib-$version" $svn_write/trunk $svn_write/tags/$version
#  
#========================================================================
# produce a tarball
#========================================================================
echo "------------------------------------------------------------------------"
echo "Checking out the new fjcontrib"
svn co $svn_read/tags/$version fjcontrib-$version || { echo "Failed to checkout the new released version"; exit 1; }
cd fjcontrib-$version
echo

echo "------------------------------------------------------------------------"
echo "Getting the contribs"
if ./scripts/update-contribs.sh --force; then
    echo "Success."
    echo
else
    echo "Failed."
    echo
    cd ..
    exit 1
fi

cd ..
echo "Producing fjcontrib-$version.tar.gz"
tar --exclude=".svn" -czf fjcontrib-$version.tar.gz fjcontrib-$version
rm -Rf fjcontrib-$version
echo
echo "Success."
echo

