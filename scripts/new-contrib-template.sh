#!/bin/bash
#
# Usage:
#   new-contrib-template.sh <new_contrib_name>
#
# create the structure of a new contrib

#------------------------------------------------------------------------
# get the contrib name
if [ "x$1" == "x" ]; then
    echo ""
    echo "Usage:"
    echo "  new-contrib-template.sh <new_contrib_name>"
    echo ""
    exit 1
fi

echo "Creating contrib "$1

name=$1
name_lower=`echo ${name} | tr A-Z a-z`
name_upper=`echo ${name} | tr a-z A-Z`
date=`date "+%Y-%m-%d"`
user=`whoami`

#------------------------------------------------------------------------
# make sure the name has not already been used
if [ -e $name ]; then
    echo "This contrib already exists. Please choose a different name"
    exit 1
fi

#------------------------------------------------------------------------
# create the structure
mkdir $name

for fn in `dirname $0`/internal/Template/*; do
    stripped=${fn##*internal/}
    echo "  creating "${stripped//Template/${name}}
    sed "s/Template/${name}/g;\
         s/template/${name_lower}/g;\
         s/TEMPLATE/${name_upper}/g;\
         s/20XX-XX-XX/${date}/g;\
         s/xxxx@localhost/${user}@localhost/g"\
         ${fn} > ${stripped//Template/${name}}
done
echo "----------------------------------------------------------------------"
echo "Template for $name successfully created. Rerun ./configure"
echo "for it to be included in your builds."
echo
echo "Once you are ready to make it public, write to "
echo "fastjet-contrib-librarians@projects.hepforge.org "
echo "to obtain write access to the fastjet-contrib svn repository "
echo
echo "You may then start to upload your contrib by running "
echo
echo "    scripts/register-new-contrib.sh ${name}"
echo
echo "and following the instructions (details are in the README file)"
echo "----------------------------------------------------------------------"
