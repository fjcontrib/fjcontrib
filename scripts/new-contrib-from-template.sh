#!/bin/bash
#
# Usage:
#   scripts/new-contrib-from-template.sh <new_contrib_name>
#
# create the structure of a new contrib

. $(dirname $0)/internal/common.sh

#------------------------------------------------------------------------
# get the contrib name
if [ "x$1" == "x" ]; then
    echo ""
    echo "Usage:"
    echo "  $0 <new_contrib_name>"
    echo ""
    exit 1
fi

contrib=${1%/}

#------------------------------------------------------------------------
# make sure the name has not already been used
if [ -e $contrib ]; then
    echo "The $contrib contrib already exists. Please choose a different name"
    exit 1
fi

#------------------------------------------------------------------------
# make sure a non-empty remote repository does not already use this name
remote_repo_url="${git_repo_base_url%/}/${contrib}.git"
remote_refs=""
echo "Checking whether the remote repository exists: $remote_repo_url"
echo
if remote_refs=$(git ls-remote "$remote_repo_url" 2>&1); then
    remote_exists=1
elif [[ "$remote_refs" =~ [Rr]epository.*[Nn]ot[[:space:]]found|[Nn]ot[[:space:]]found ]]; then
    # GitHub reports a repository that has not yet been created as an error.
    remote_exists=0
else
    echo "Could not check whether the remote repository exists: $remote_repo_url"
    echo "Aborting to avoid creating a contrib with an unverified repository name"
    exit 1
fi
if [[ "$remote_exists" -eq 1 ]]; then
    if [[ -n "$remote_refs" ]]; then
        echo "The remote repository $remote_repo_url already exists and is not empty."
        echo "In all likelihood the name has been reserved and you should choose a different name for your contrib."
        if get_yesno_answer "Are you REALLY sure you want to create this contrib?"; then
            echo "Aborting"
            exit 1
        fi
    else
        echo "The remote repository $remote_repo_url exists but is empty."   
        echo "You should proceed with creation of $contrib ONLY if the remote was created for you"
        if get_yesno_answer "Do you want to go ahead and create this contrib locally?"; then
            echo "Aborting"
            exit 1
        fi
    fi
fi

echo "Creating contrib "$1

contrib_lower=`echo ${contrib} | tr A-Z a-z`
contrib_upper=`echo ${contrib} | tr a-z A-Z`
date=`date "+%Y-%m-%d"`
user=`whoami`


#------------------------------------------------------------------------
# create the structure
mkdir $contrib
#mkdir $contrib/include
#mkdir $contrib/fastjet
#mkdir $contrib/fastjet/contrib

for fn in $(find $(dirname $0)/internal/Template/ ); do
    if [ -d $fn ]; then
        mkdir -p $contrib/${fn##*internal/Template/}
    else 
        stripped=${fn##*internal/}
        echo "  creating "${stripped//Template/${contrib}}
        sed "s/Template/${contrib}/g;\
             s/template/${contrib_lower}/g;\
             s/TEMPLATE/${contrib_upper}/g;\
             s/20XX-XX-XX/${date}/g;\
             s/xxxx@localhost/${user}@localhost/g"\
             ${fn} > ${stripped//Template/${contrib}}
    fi
#for fn in `dirname $0`/internal/Template/*; do
done

git -C $contrib init
git -C $contrib add .
git -C $contrib commit -m "Initial commit of FastJet contrib '${contrib}' from Template"

echo "----------------------------------------------------------------------"
echo "$contrib successfully created from Template. Rerun ./configure"
echo "for it to be included in your builds."
echo
echo "Once you are ready to make it public, write to "
echo "fastjet@projects.hepforge.org to ask for creation of the "
echo "         ${git_repo_base_url}/${contrib}.git repo "
echo "indicating who should have write access to it."
echo
echo "You may then start to upload your contrib by running "
echo
echo "    scripts/register-new-contrib.sh ${contrib}"
echo
echo "and following the instructions (details are in the README file)"
echo "----------------------------------------------------------------------"
