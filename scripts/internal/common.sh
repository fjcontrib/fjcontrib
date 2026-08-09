# a list of definitions and tools that we'd like to have an easy access
# to

# Git repositories for the individual contributions.  The same URL is
# used for fetching and pushing for now.
git_repo_base_url=${CONTRIB_REPO_BASE_URL:-https://github.com/fjcontribs-test}

export git_repo_base_url fastjet_web_dir

function get_contrib_repo_url(){
    echo "${git_repo_base_url%/}/$1"
}

# Get information about a local Git checkout and fill:
#  - mode    (kept for callers that display access information; GitHub uses
#            the same URL for read and write access)
#  - version (trunk, tags/<tag>, branches/<branch>, or a bracketed status)
#
#   get_git_info contrib mode version
function get_git_info(){
    local __modevar=$2
    local __versionvar=$3
    local start_dir=$(pwd)

    # check if the directory exists
    if [[ ! -d $1 ]]; then
	eval "$__modevar='[None]'"
	eval "$__versionvar='[None]'"
	return 0
    fi

    cd $1

	# check if this is in Git
	git rev-parse --is-inside-work-tree > /dev/null 2>&1 || {
	eval "$__modevar='[NoGit]'"
	eval "$__versionvar='[NoGit]'"
	cd "$start_dir"
	return 0
    }

	branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
	if [[ "$branch" == "main" ]]; then
	    version="trunk"
	elif [[ -n "$branch" ]]; then
	    version="branches/$branch"
	else
	    tag=$(git describe --tags --exact-match HEAD 2>/dev/null || true)
	    if [[ -n "$tag" ]]; then
	        version="tags/$tag"
	    else
	        version="[Detached]"
	    fi
	fi
	eval "$__modevar='rw'"
	eval "$__versionvar='$version'"

    cd "$start_dir"
    return 0    
}

# get an entry from a contrib file, filling the "version" variable
# with the version number
#
#   get_contrib_version  contrib_name  file  version
function get_contrib_version(){
    local __resultvar=$3

	# Get the version from the local Git checkout of the contribution.
    if [[ "$2" == "local_git" ]]; then
	get_git_info "$1" mode version
	eval "$__resultvar='$version'"
	return 0
    fi

    # now deal with the version number as if it was an entry in "file" $2
    if [[ -e $2 ]]; then # check if the file actually exists
#      entry=$(grep "^[ \t]*$1[ \t]" $2)  # does not seem to work with tabs
      entry=$(grep "^[[:space:]]*$1[[:space:]]" $2)
      if [ -z "$entry" ]; then
	  eval $__resultvar="[None]"
      else
	  eval $__resultvar="`echo $entry | awk '{print $2}'`"
      fi
    else # file does not exist
      eval $__resultvar="[None]"
    fi    
}

# get a yes/no answer
# returns 0 for n/N/no
#         1 for y/Y/yes
function get_yesno_answer(){
    local default_answer=${2:-}
    while true; do
	echo -ne "$1 [y/n] "
	if [[ -z "$default_answer" ]]; then
	    if ! read answer; then
	        echo
	        return 0
	    fi
	else
	    answer="$default_answer"
	    # TODO: add a test that the answer is a valid one
	    echo "$default_answer"
	fi
	case $answer in
	    y|Y|yes) return 1; break ;;
	    n|N|no)  return 0; break ;; 
	esac
    done
}

# check if the local Git checkout has pending modifications
# check_pending_modifications contrib
function check_pending_modifications(){
    local start_dir=$(pwd)
    cd $1
    result=$(git status --porcelain 2>/dev/null)
    if [[ ! -z "$result" ]]; then
	git status --short
	cd "$start_dir"
	return 1
    fi
	cd "$start_dir"
    return 0
}

function find_gnu_tar(){
    # check if tar is gnu tar (needed for clean tarball). set the $tar variable to it;
    # otherwise see if gtar is available and a proper gnu tar. If so, set the $tar variable to it.
    # If not, exit with an error message inviting the user to install gnu-tar on mac
    tar=""
    if [[ -z "$tar" ]]; then
        if [[ -x "`which tar 2>/dev/null`" ]]; then
        tar=`which tar`
        if [[ -z "`$tar --version | grep 'GNU tar'`" ]]; then
            if [[ -x "`which gtar 2>/dev/null`" ]]; then
            tar=`which gtar`
            if [[ -z "`$tar --version | grep 'GNU tar'`" ]]; then
                echo "You have a non-GNU tar installed. Please install GNU tar (e.g. using brew install gnu-tar)"
                exit 1
            fi
            else
            echo "You have a non-GNU tar installed. Please install GNU tar (e.g. using brew install gnu-tar)"
            exit 1
            fi
        fi
        else
        echo "You have no tar installed. Please install GNU tar (e.g. using brew install gnu-tar)"
        exit 1
        fi
    fi
}


# helpers to read config files
#
# Config files structure:
# - they should be made of lines of the form
#   <tag>: <value>
#   potentially with spaces between <tag> and ":"
#
# - the "dependencies" value should be a comma-separated list of
#   dependencies. An optional minimal version number can be given in
#   parenthesis.
# 
# Currently supported tags are
#   name            the name of the contrib
#   version         the current version of the contrib
#   dependencies    list of required dependencies (with an 
#                   optional minimal version number)
#
# this script provides
#   read_tag <dirname> <tag> <value> sets value to the value of the given tag
#   parse_dependencies  returns [TBD]
#
# Include this file in scripts that need it using
#   . `dirname $0`/config_reader.sh

# Usage:
#   read_tag <dirname> <tag> <value>
# reads the tag <tag> and sets the value in the <value> variable
function read_tag(){
    dirname=$1
    tag=$2
    local __value=$3
    
    # case where the config file is absent
    # only the "version" tag is supported
    if [ ! -f ${dirname}/FJCONTRIB.cfg ]; then
        if [ "$tag" == "version" ]; then
            eval $__value=\"$(head -1 ${dirname}/VERSION)\"
            return 0
        fi
        eval $__value="";
        return 0
    fi

    # find the line in the file
    #dbg: echo "tag is ${tag}"
    #dbg: grep -m1 "${tag}\s*:" FJCONTRIB.cfg
    #dbg: grep -m1 "${tag}\s*:" FJCONTRIB.cfg | sed 's/^.*: *//'
    eval $__value=\"$(grep -m1 "^\s*${tag}\s*:" ${dirname}/FJCONTRIB.cfg | sed 's/^.*: *//')\"
    return 0
}

# Usage:
#
#   get_dependencies <dirname> <dependencies> <min_versions> <min_fastjet_version>
#
# sets "dependencies" and "min_versions" to an array listing the
# dependencies and their associated minimal versions. Also sets
# "min_fastjet_versions" for each contrib, if specified in FJCONTRIB.cfg
#
# Whenever the minimal version is absent, set it to "0.0.0"
#
# The dependencies should be on a line in the FJCONTRIB.cfg file of the form
#    
#  dependencies: dep1,dep2(1.0.0),dep3
#
# where the minimal version, in brackets, is optional, and
#
#  minimal_fastjet_version: x.y.z
#
function get_dependencies(){
    dirname=$1
    local __dependencies=$2
    local __min_versions=$3
    local __min_fastjet_version=$4

    # read the full string
    read_tag $dirname "dependencies" all_dependencies
    read_tag $dirname "minimal_fastjet_version" minfjversion

    # start creating an array
    dependencies="("
    minversions="("

    # loop over all the dependencies
    depver_list=`echo ${all_dependencies} | tr -d ' ' | tr ',' ' '`
    for depver in ${depver_list}; do
        #echo ${depver}
        if [[ $depver == *"("* ]]; then
            dep=`echo -n ${depver} | sed 's/(.*//'`
            ver=`echo -n ${depver} | sed 's/^.*(//;s/).*//'`
        else
            dep=${depver}
            ver="0.0.0"
        fi
        dependencies="${dependencies} ${dep}"
        minversions="${minversions} ${ver}"
    done

    # finalise and build return values for dependencies
    dependencies="${dependencies})"
    minversions="${minversions})"
    eval $__dependencies="${dependencies}"
    eval $__min_versions="${minversions}"
    
    # return minimal fastjet version
    eval $__min_fastjet_version=$minfjversion
    
    #eval $__dependencies=\""("`echo ${all_dependencies} | sed 's/([0-9\.]*)//g;s/,/ /g'`")"\"
    #eval $__min_versions=\""("`echo ${all_dependencies} | sed 's/([0-9\.]*)//g;s/,/ /g'`")"\"
    
}

# Usage:
#  item_is_in_list <item> <list>
function item_is_in_list {
    local x=$1
    local list=$2
    local item

    for item in $list
    do
        if [ "$x" == "$item" ]; then
            return 0
        fi
    done
    return 1
}

# Usage:
#  version_is_at_least <version> <min_version>
#
# Should return true if the version is at least the minimal version
function version_is_at_least() {
    local version=$1
    local min_version=$2

    # split the version into its components
    local version_major=`echo $version | cut -d. -f1`
    local version_minor=`echo $version | cut -d. -f2`
    local version_patch=`echo $version | cut -d. -f3 | cut -d- -f1`
    local min_version_major=`echo $min_version | cut -d. -f1`
    local min_version_minor=`echo $min_version | cut -d. -f2`
    local min_version_patch=`echo $min_version | cut -d. -f3 | cut -d- -f1`

    # compare the components
    if [ $version_major -gt $min_version_major ]; then
        return 0
    elif [ $version_major -lt $min_version_major ]; then
        return 1
    fi
    if [ $version_minor -gt $min_version_minor ]; then
        return 0
    elif [ $version_minor -lt $min_version_minor ]; then
        return 1
    fi
    if [ $version_patch -ge $min_version_patch ]; then
        return 0
    else
        return 1
    fi
}
