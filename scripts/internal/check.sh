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

echo "Checking the output of '$1' using the input file '$2'"

# check that all the necessary files are in place
test -e ./$1 || { echo "the executable $1 cannot be found."; exit 1;}
test -x ./$1 || { echo "$1 is not executable."; exit 1;}
test -e ./$1.ref || { echo "the expected output $1.ref cannot be found."; exit 1;}
test -e ./$2 || { echo "the datafile $2 cannot be found."; exit 1;}

# make sure that the result file is not empty (after removal of
# comments and empty lines)
[ -z "$(cat ./$1.ref | grep -v '^#' | grep -v '^$')" ] && {
    echo "The expected output should contain more than comments and empty lines"
    exit 1
}

# run the example
./$1 < $2 2>/dev/null | grep -v "^#" > $1.tmp_ref

DIFF=`cat $1.ref | grep -v "^#" | diff $1.tmp_ref -`
if [[ -n $DIFF ]]; then 
    cat $1.ref | grep -v "^#" | diff $1.tmp_ref - > $1.diff
    echo "Outputs differ (diff available in $1.diff)"
    rm $1.tmp_ref
    exit 1
fi

rm $1.tmp_ref
