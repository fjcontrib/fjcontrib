# a list of definitions and tools that we'd like to ave an easy access
# to

# svn repositories for read and write access
svn_read=http://fastjet.hepforge.org/svn/contrib
svn_write=svn+ssh://svn.hepforge.org/hepforge/svn/fastjet/contrib

# get the svn URL and fill 
#  - mode : ro if http:// access; rw otherwise
#  - version : the version info
#               [None]  is returned if the directory does not exist
#               [NoSVN] is returned if the directory is not under svn
#
#   get_svn_info  contrib  mode  version
function get_svn_info(){
    local __modevar=$2
    local __versionvar=$3

    # check if the directory exists
    if [[ ! -d $1 ]]; then
	eval $__modevar="[None]"
	eval $__versionvar="[None]"
	return 0
    fi

    cd $1

    # check if this is in svn
    svn info > /dev/null 2>&1 || {
	eval $__modevar="[NoSVN]"
	eval $__versionvar="[NoSVN]"
	cd ..
	return 0
    }
	
    # get the full URL
    svn_url=$(svn info | grep "^URL:" | sed 's/^URL: //')
    eval $__versionvar="${svn_url#*/$1/}"

    if [[ "$svn_url" == "http:"* ]]; then
	eval $__modevar="ro"
    else
	eval $__modevar="rw"
    fi

    cd ..
    return 0    
}

# get an entry from a contrib file
#
#   get_contrib_version  contrib  file  version
function get_contrib_version(){
    local __resultvar=$3

    # nasty hack: if the file is "contribs.local", get it from the svn
    if [[ "$2" == "contribs.local" ]]; then
	get_svn_info $1 mode version
	eval $__resultvar="$version"
	return 0
    fi

    # now deal with it as if it was a 
    entry=$(grep "^$1 " $2)
    if [ -z "$entry" ]; then
	eval $__resultvar="[None]"
    else
	eval $__resultvar="`echo $entry | awk '{print $2}'`"
    fi
}

# get a yes/no answer
# returns 0 for n/N/no
#         1 for y/Y/yes
function get_yesno_answer(){
    while true; do
	echo -ne "$1 [y/n] "
	read answer
	case $answer in
	    y|Y|yes) return 1; break ;;
	    n|N|no)  return 0; break ;; 
	esac
    done
}

# check if the local svn has pending modifications
# check_pending_modifications contrib
function check_pending_modifications(){
    cd $1
    result=$(svn status | grep -v "^?")
    if [[ ! -z "$result" ]]; then
	svn status | grep -v "^?"
	cd ..
	return 1
    fi
    cd ..
    return 0
}
