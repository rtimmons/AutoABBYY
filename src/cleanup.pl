#!/usr/bin/env perl -w

# Removes originals left behind by scansnap software

use strict;
use warnings;

use Getopt::Long;

my $dir = "$ENV{HOME}/Dropbox/Inbox";
GetOptions("dir=s" => \$dir);

my $ext = " processed by FineReader.pdf";


foreach (<$dir/*.pdf>) {
    next if /$ext$/;
    s/\.pdf$//;
    
    if ( -e "$_$ext" ) {
        `rm $_.pdf`
    }
}

