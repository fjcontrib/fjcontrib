#!/bin/bash
#
# make a full release of the current trunk
# Then produce a tarball

#========================================================================
# svn sanity checks
#========================================================================

# make sure that everything is committed
if [[ ! -z "`svn status --show-updates | grep -v "^?" | grep -v "^Status"`" ]]; then
    echo "There are pending modifications or updates. Aborting"
    exit 1
fi
. `dirname $0`/common.sh
# make sure there is a VERSION and it does not already exist
version=`head -n1 VERSION`
if [[ ! -z $(svn ls $svn_read/tags || grep "^$version/") ]]; then
    echo "Version $version of fjcontrib already exists. Aborting"
    exit 1
fi

get_yesno_answer "Do you want to proceed with the release of fjcontrib-$version?" &&  exit 1


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

# we need to determine whether to use fastjet-config from the path or
# use the one from the configure invocation in the trunk
is_in_path="yes"
which fastjet-config > /dev/null || is_in_path="no"

trunk_version=""
if [[ -e "../Makefile" ]]; then
    trunk_version=$(head -n3 ../Makefile | tail -n1 | grep "\--fastjet-config=" | sed 's/.*--fastjet-config=//;s/ .*$//')
fi

if [[ -z "$trunk_version" ]]; then
    if [[ "$is_in_path" == "no" ]]; then
	echo "fasjet-config is not in your path and cannot be obtained from the trunk configuration. Aborting."
	cd ..
	exit 1
    else
	echo "Using fasjet-config from your path"
	configure_options=""
    fi
else
    if [[ "$is_in_path" == "no" ]]; then
	echo "using fasjet-config from the trunk configuration"
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
echo "Releasing fjcontrib version $version"
svn copy -m "releasing fjcontrib-$version" $svn_write/trunk $svn_write/tags/$version

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

# get rid of a few things for developers and "svn-users" only
mkdir tmp
for fn in check.sh install-sh; do
    mv scripts/internal/${fn} ./tmp
done
rm -Rf scripts
mkdir scripts
mkdir scripts/internal
for fn in tmp/*; do
    mv $fn scripts/internal/${fn#tmp/}
done
rm DEVEL-GUIDELINES

cd ..
echo "Producing fjcontrib-$version.tar.gz"
tar --exclude=".svn" -czf fjcontrib-$version.tar.gz fjcontrib-$version
rm -Rf fjcontrib-$version
echo
echo "Success."
echo

#========================================================================
# update things on HepForge
#========================================================================
echo "Updating the Hepforge project"

echo "Uploading the tarball"
scp fjcontrib-$version.tar.gz login.hepforge.org:~fastjet/downloads/

mkdir hepforge_tmp
echo "Generating info for the webpage"
echo -n "$version" > hepforge_tmp/fjcversion.php
`dirname $0`/generate-html-contents.pl > hepforge_tmp/contents-$version.html

echo "Uploading info for the webpage"
scp hepforge_tmp/fjcversion.php login.hepforge.org:~fastjet/public_html/contrib/
scp hepforge_tmp/contents-$version.html login.hepforge.org:~fastjet/public_html/contrib/contents/$version.html
rm -Rf hepforge_tmp
echo
echo "Done"
echo


