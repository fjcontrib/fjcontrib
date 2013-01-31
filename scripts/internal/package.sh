
#!/bin/bash

# This script, meant for "internal use", packages all the
# latest version of the contributions into a tar.gz file,
# exploiting the list returned by running "./configure --list"
# in the top directory
#
#  Usage: run ./scripts/internal/package.sh from the top directory
#

version=`cat VERSION`
packagename=fjcontrib-$version
files="AUTHORS COPYING Makefile.in README VERSION NEWS configure data scripts/internal/check.sh scripts/internal/install-sh"
files="$files "$(cat contribs.svn | grep -v "^#" | grep -v "^$" | awk '{printf $1" "}')
#`./configure --list`

echo Creating version $version
echo Including: $files

tar --transform "s,^,$packagename/," -zcf $packagename.tar.gz $files
exit


