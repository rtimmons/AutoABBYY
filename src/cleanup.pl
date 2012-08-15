#!/usr/bin/env perl -w

# Removes originals left behind by scansnap software

use strict;
use warnings;

my $ext = " processed by FineReader.pdf";

print 'cd ';
print `pwd`;

foreach (<*.pdf>) {
    next if /$ext$/;
    s/\.pdf$//;
    
    print "[ -f '$_$ext' ] && rm '$_.pdf'\n" 
        if -f ($_ . $ext);
}

