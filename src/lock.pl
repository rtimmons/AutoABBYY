#!/usr/bin/env perl -w

# $Id: lock.pl 748 2012-05-27 18:07:55Z ryan $
# TODO: fix

# This is an aborted attempt to get file-locking working.  Apparently I need to RTFM.

use strict;
use warnings;

use Fcntl qw(:DEFAULT :flock);


sub run_once {
    my ($sub) = @_;
    my $resource = 'SSJ8UU4R1X25Q9XUBES4';
    my $okay = my_lock($resource);
    if ( $okay ) {
        $sub->();
    }
    else {
        print "Already running";
    }
}



sub my_lock {
    my ($resource_name) = @_;
    my $lock = "/Users/rtimmons/$resource_name.lck";
    print "Creating lock [$lock]\n";
    open(LOCK, ">", $lock) or die "Can't sysopen $lock: $!";
    print LOCK "Created lock $lock";
    flock(LOCK, LOCK_EX) or die "Can't lock $lock: $!";
    
    # return $locked;
}


my $s = sub {
    $|++;
    print "Here!";
    sleep 5;
};

run_once $s;
