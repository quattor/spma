#!/usr/bin/perl
#
# Script to test the regexp used to guess kernel variant in SPM/Policy.pm.
# This script can be used on different machine to check the regexp is
# correct, before modifying int SPM/Policy.pm.
# Note that correctness of this regexp is critical for kernel update
# handling by SPMA (protectkernel option) and that a change in this
# regexp in SPM/Policy.pm should NEVER be committed before running this
# script on a set of test machine using variants smp, largesmp, xen and no
# variant (SL5).
#
# Written by Michel Jouvin - 27/1/10

use strict;
use LC::Sysinfo;

# Borrowed from SPM/policy.pm
my $uname_r = LC::Sysinfo::uname->release();
my $kernel = $uname_r;

if ( $kernel =~ m/^(.*?)((?:large)?smp|xen|xenU|PAE|hugemem)$/ ) {
  print "kernel=$1, variant=$2)\n";
} else {
  print "kernel=$kernel (no variant)\n";
}
