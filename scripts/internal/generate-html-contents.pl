#!/usr/bin/perl -w
#
# Generate an html contents file for the current version
#
# Best run from a directory that is a clean checkout of a tag; behaviour
# may not 


$versions="contribs.svn";
$svn="http://fastjet.hepforge.org/svn/contrib/contribs/";

$topversion=`head -1 VERSION`;
chomp $topversion;

open (VERSIONS, "<$versions") || die "Could not open $versions";
$list='';
while ($line = <VERSIONS>) {
  if ($line =~ /^\s*([a-z][^\s]*)\s+([^\s]*)/i) {
    $contrib = $1;
    $version = $2;
    if ($version =~ /^[0-9]/) {$version = "tags/$version";}
    ($textversion = $version) =~ s/tags\///;
    $list .= "<tr> <td> $contrib </td> <td> </td> <td> $textversion </td> <td>";
    if (-e "$contrib/README") {
      $list .= '<a href="'.$svn.$contrib.'/'.$version.'/README">README</a> ';
    }
    if (-e "$contrib/NEWS") {
      $list .= '<a href="'.$svn.$contrib.'/'.$version.'/NEWS">NEWS</a> ';
    }
    $list .= "</td></tr>\n";
  }
}

$head='
<html>
<head>
</head>
<body>
Version '.$topversion.' of FastJet Contrib is distributed with the following packages<p>

<table>
<tr><td> Package </td><td></td> <td>  Version </td> <td> </td>  </tr> 
<tr></tr>
';

$tail='
</table>


</body>
</html>
';

print $head, $list, $tail;
