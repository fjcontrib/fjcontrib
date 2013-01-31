#!/bin/bash
#
# usage:
#   check <program> <datafile>
#
# this script checks if "<program>" exisits, run it using <datafile>
# as an inpu and compares the output with "<program>.ref" (it fails if
# "<program>.ref" does not exist),
#
# Note that <program> is actually run using "./<program> < <datafile>"

echo
echo "Checking the output of '$1' using the input file"
echo "$2 and reference file $1.ref"

# check that all the necessary files are in place
test -e ./$1 || { echo "ERROR: the executable $1 cannot be found."; exit 1;}
test -x ./$1 || { echo "ERROR: $1 is not executable."; exit 1;}
test -e ./$1.ref || { echo "ERROR: the expected output $1.ref cannot be found."; exit 1;}
test -e ./$2 || { echo "ERROR: the datafile $2 cannot be found."; exit 1;}

# make sure that the result file is not empty (after removal of
# comments and empty lines)
[ -z "$(cat ./$1.ref | grep -v '^#' | grep -v '^$')" ] && {
    echo "ERROR: the reference output, $1.ref"
    echo "should contain more than comments and empty lines"
    echo
    exit 1
}

# run the example
./$1 < $2 2>/dev/null | grep -v "^#" > $1.tmp_ref

DIFF=`cat $1.ref | grep -v "^#" | diff $1.tmp_ref -`
if [[ -n $DIFF ]]; then 
    cat $1.ref | grep -v "^#" | diff $1.tmp_ref - > $1.diff
    echo "ERROR: Outputs differ (diff available in $1.diff)"
    echo
    rm $1.tmp_ref
    exit 1
fi

rm $1.tmp_ref
