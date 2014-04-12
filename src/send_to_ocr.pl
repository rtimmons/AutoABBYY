#!/usr/bin/env perl -w

use strict;
use warnings;

# 
# This script helps to automate the ScanSnap software on a Mac. This is
# the software that shipped with my Fujitu ScanSnap S510M. The software
# won't automatically OCR scanned documents thru the included "ABBYY
# FineReader" app, and it won't let you drop more than one file onto it
# manually at once. It's pretty hateful, really.  This script undoes
# some (some!) of that hate.
# 
# So this just
# 
# 1.  looks for PDFs in some directory,
# 2.  filters out those that were not created by 'ScanSnap Manager',
# 3.  filters out ones that already have a companion OCRed file, and 
# 4.  for what's left, invokes the OCR app, wait until the companion
#     exists, and then continue with the next file. Will timeout any
#     individual file that takes longer than 5 minutes to complete.
# 
# TODOs:
# 
# -   Make this easier to configure (using getopt or something)
# -   Test this with Folder Actions and describe how to set them up
# -   Really could use some automated test coverage, but this is a
#     personal project and I don't care if it breaks
# 


# Look for files with this suffix to determine if they've been 
# OCRed
our $suffix = ' processed by FineReader.pdf';

# Only try to OCR files with this file creator metadata
our $spotlight_creator = 'ScanSnap Manager';

# Look for PDFs in the following dir to send to OCR
our $source_dir = '/Users/rtimmons/Dropbox/Inbox';

# Set to 1 to enable debugging
our $debug = 1;


# ==============================
# = Don't Edit Below This Line =
# ==============================

##
# Point of entry
sub main {
    my ($dir) = @_;
    
    # Look at all PDFs
    my @all = all_pdfs_in($dir);
    
    # Find out who made them
    my %creators = 
        map { $_ => spotlight_creator($_) }
        @all;

    # Grab only those created by $spotlight_creator
    my @todo = 
        grep { $creators{$_} eq $spotlight_creator }
        @all;

    # Log the ones that we won't do
    my @wont_do = 
        grep { $creators{$_} ne $spotlight_creator }
        @all;
    mylog(
        "Won't try to OCR following since weren't created by [$spotlight_creator]:",
        "",
        (map { "    [$_] (created by $creators{$_})" } @wont_do),
        ""
    );
    
    # do nothing unless there's stuff to do
    return unless @todo;
    
    # do things in sorted order
    @todo = sort @todo;
    
    # Run OCR on each file
    map { do_ocr($_, $dir); } @todo;
}


# Stupid logger
sub mylog {
    return unless $debug;
    use Data::Dumper;
    $| ||= 1;
    
    if ( ref($_[0]) ) {
        print Dumper(@_);
    }
    else {
        print join("\n", @_);
    }
    print "\n";
}

##
# Run OCR app on given file if the 
# OCRed version of the file doesn't already
# exist.
sub do_ocr {
    my ($file) = @_;
    my $app = 'Scan to Searchable PDF';
    my $cmd = 
        qq(osascript -e 'tell application "$app" to open "$file"' );
    
    wait_until_with_timeout(
        timeout =>  60 * 5, # 5 minutes
        interval => 10,     # check for OCR companion every 30 secs
        _file    => $file,
        sub      => sub {
            my ($ctx) = @_;
            
            # Useful for debugging how many
            # times the sub has been called
            $ctx->{calls} ||= 0;
            $ctx->{calls}++;
            
            # Only compute needle once
            unless ($ctx->{needle}) {
                my $f = $ctx->{_file};
                $_ = $f;
                
                # Abort if not a PDF file
                m/(.*?)\.pdf/ or last;
                $ctx->{needle} = $1 . $suffix;
            }
            
            # mylog $ctx; # Enable if really really debugging :)
            
            mylog "Looking for file [$ctx->{needle}]", "";
            
            my $xists = -f $ctx->{needle};
            
            # hash the commands we've already run
            # to prevent them from being run twice
            # (i.e. assume the commands are *not*
            # idempotent or that it's expensive
            # to run twice).  This is true since
            # OCRing twice is heavy.
            $ctx->{commands_run} ||= {};

            if ( !$xists ) {
                mylog "    File [$ctx->{needle}] doesn't exist.";
                if ( $ctx->{commands_run}{$cmd} ) {
                    mylog "    Already running OCR.  Waiting.";
                }
                else {
                    my $out = `$cmd`;
                    $ctx->{commands_run}{$cmd} = 1;
                    mylog "    Ran command [$cmd]";
                    chomp($out);
                    mylog "    Command output [$out] ('missing value' is okay)";                    
                }
            }
            else {
                # file does exist
                mylog "    File [$ctx->{needle}] exists.  Done with this scan.";
            }
            
            return $xists;
        },
    );
}


##
# Returns all pdfs in given dir
# Sorts ascibetically.
# 
sub all_pdfs_in {
    my ($dir) = @_;
    return sort(glob("$dir/*.pdf"));
}



## 
# Return the 'kMDItemCreator' metadata attribute
# for a given file (absolute path).
# 
sub spotlight_creator {
    my ($file) = @_;
    my $attr = 'kMDItemCreator';
    my $x = qx{/usr/bin/mdls -name "$attr" -raw -nullMarker None "$file"};
    chomp($x);
    return $x;
}

##
# Run a command at a specified interval until the command
# returns truthy or until the timeout occurs.
# 
# Takes a hash with params
# 
#
#   sub         code-ref of code to execute.
#               The ref should return falsy to
#               indicate that the condition is
#               not yet met and that the sub
#               should be run again. The sub
#               will be passed in the given
#               options as a ref so that it
#               may store context information
#               between iterations.
#
#   interval    integer number of seconds to
#               wait between invocations of
#               sub.
#   
#   timeout     how many seconds max should
#               wait_until_with_timeout take
#               to execute. The given sub will
#               not be executed any more once
#               timeout number of seconds has
#               been exceeded.
# 
# In addition, will set the following params
# in the hash:
# 
#     elapsed   how many seconds have elapsed
#               so far.
# 
sub wait_until_with_timeout {
    my (%opts) = @_;
    
    my $timeout  = $opts{timeout};
    my $interval = $opts{interval};
    my $sub      = $opts{sub};
    
    $opts{elapsed} = 0;
    
    my $done = 0; # not done
    
    do {
        $done = $sub->(\%opts) || $opts{elapsed} > $timeout;
        if ( !$done ) {
            my $slept = sleep $interval;
            $opts{elapsed} += $slept;
        }
    }
    until( $done );
    
    if( $opts{elapsed} > $timeout ) {
        mylog "Timed out after $opts{elapsed} seconds\n";
    }
}

main $source_dir;

