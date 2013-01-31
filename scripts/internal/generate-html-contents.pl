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
    $list .= "<tr> <td class=\"contribname\"> $contrib </td> <td style=\"{text-align:center;}\"> $textversion </td> <td>";
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
<style type="text/css">
.contriblist table,.contriblist tr,.contriblist td,.contriblist th {
  text-align:center;
  border:1px solid white;
  padding:4px;
  padding-right:26px;
}
td.contribname {
  background-color:#eeeeee;
  text-align:left;
}
th.contriblist {
  text-align:center;
  padding:6px;
  padding-left:16px;
  padding-right:16px;
  background-color:#dddddd;
}
td.spanned {
  text-align:center;
  background-color:#dddddd;
}
</style>
</head>
<body>
Version '.$topversion.' of FastJet Contrib is distributed with the following packages<p>

<table class="contriblist">
<tr><th class="contriblist">Package</th> 
    <th class="contriblist">Version</th>
    <th class="contriblist">Information</th> </tr> 
';

$tail='
</table>


</body>
</html>
';

print $head, $list, $tail;
