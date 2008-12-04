#!/usr/bin/perl -w -I /usr/lib/perl

use strict;

use SPM::Package;
use SPM::Packager;
use SPM::RPMPkgr;
use SPM::Op qw(OP_DELETE OP_INSTALL OP_REPLACE OP_NOTHING);
use SPM::LocalList;
use SPM::Policy;

use LC::Exception;
use LC::File    qw(file_contents);

my $fails = 0;
my $report;

use vars qw (@ISA $EC);

$EC = LC::Exception::Context->new->will_store_all;

sub t0001() {
    print ("Package construction");

    my $pkg = SPM::Package->new( );
    
    if ($pkg) {
	nok("Package creation with no arguments should have failed.");
    }
    report(0);
    $EC->ignore_error();

    my %flags = ( "islocal" => 0, "ismandatory" => 1 );

    $pkg = SPM::Package->new(undef, qw(Xaw3d-devel 1.5 10 i386), \%flags );
 
    if ($pkg) {
	if ($pkg->get_name() ne "Xaw3d-devel") {
	    nok("Package name does not match constructor argument");
	    return;
	}
	if ($pkg->get_version() ne "1.5") {
	    nok("Package version does not match constructor argument");
	    return;
	}
	if ($pkg->get_release() ne "10") {
	    nok("Package release does not match constructor argument");
	    return;
	}
	if ($pkg->get_arch() ne "i386") {
	    nok("Package architecture does not match constructor argument");
	    return;
	}
	if ($pkg->get_attrib()->{ISMANDATORY} != 1 ) {
	    nok("Package isMandatory attribute was not set by construction");
	    return;
	}
	if ($pkg->get_attrib()->{ISLOCAL} != 0 ) { 
	    nok("Package isLocal attribute was not set by construction");
	    return;
	}
	report();
     } else {
	 nok("Failed to create package instance - ".$EC->error->text());
	 $EC->ignore_error();
	 return;
     }
    
    # Check comparison operations

    # Check names equal

    my $pkg2 = SPM::Package->new(undef, qw(Xaw3d-devel 1.5 10 i386), \%flags );

    if ($pkg2) {
	unless ($pkg->compare_name($pkg2) == 0) {
	    nok("Failed to compare names as equal");
	    return;
	}
	unless ($pkg->is_equal($pkg2)) {
	    nok("Failed to compare release/version as equal");
	    return;
	}
	report();
     } else {
	 nok("Failed to create duplicate package instance - ".$EC->error->text());
	 $EC->ignore_error();
	 return;
     }

    # Check names unequal

    $pkg2 = SPM::Package->new(undef, qw(NotEqualName 1.5 10 i386), \%flags );

    if ($pkg2) {
	if ($pkg->compare_name($pkg2) == 0) {
	    nok("Failed to compare names as unequal");
	    return;
	}
	report();
     } else {
	 nok("Failed to create named package instance - ".$EC->error->text());
	 $EC->ignore_error();
	 return;
     }

    # Release wildcard should fail because no unwanted UNWANTED

    $pkg2 = SPM::Package->new(undef, qw(Xaw3d-devel 1.5 * i386), 
			      { "islocal" => 0, "ismandatory" => 1 } );

    if ($pkg2) {

	 nok("Failed to trap invalid wildcard release instance - ".$EC->error->text());
	 $EC->ignore_error();
	 return;
     }

    report();

    # Release wildcard

    $pkg2 = SPM::Package->new(undef, qw(Xaw3d-devel 1.5 * i386),
			      { "isunwanted" => 1, "ismandatory" => 1 } );

    if ($pkg2) {
	unless ($pkg->is_equal($pkg2)) {
	    nok("Failed to compare release wildcard as equal");
	    return;
	}
    } else {
	 nok("Failed to create wildcard release instance - ".$EC->error->text());
	 $EC->ignore_error();
	 return;
     }

    report();

    # Release/version wildcard

    $pkg2 = SPM::Package->new(undef, qw(Xaw3d-devel *  * i386),
			      { "isunwanted" => 1, "ismandatory" => 1 } );

    if ($pkg2) {
	unless ($pkg->is_equal($pkg2)) {
	    nok("Failed to compare release wildcard as equal");
	    return;
	}
    } else {
	 nok("Failed to create wildcard version instance - ".$EC->error->text());
	 $EC->ignore_error();
	 return;
     }

    report();

    # Wildcard errors

    $pkg2 = SPM::Package->new(undef, qw(Xaw3d-devel * 1.1 i386),
			      { "isunwanted" => 1, "ismandatory" => 1 } );

    if ($pkg2) {
	 nok("Failed to trap bad wildcard version  - ".$EC->error->text());
	 $EC->ignore_error();
	 return;
     }

    report();

    ok();
}
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub t0002() {
    print "Package list construction";

    my %flags = ( "islocal" => 1, "ismandatory" => 1 );

    my @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    my @p2 = ( qw(url dump 0.4b25 1.72.0 i386) );
    my @p3 = ( qw(url rhmask 1.0 10 i386) );
    my @p4 = ( qw(url gdbm-devel 1.8.0 11 i386) );
    my @p5 = ( qw(url gdbm 1.8.0 9 i386) );

    my @lst = ();

    if (push(@lst,SPM::Package->new(@p1, \%flags) ) &&
	push(@lst,SPM::Package->new(@p2, \%flags) ) &&
	push(@lst,SPM::Package->new(@p3, \%flags) ) &&
	push(@lst,SPM::Package->new(@p4, \%flags) ) &&
	push(@lst,SPM::Package->new(@p5, \%flags) ) &&
	scalar(@lst == 5)) {

	my @ordered = sort { $a->get_name() cmp $b->get_name() } @lst;

	if ($ordered[0]->get_name() eq "dump") {
	    report(0);
	    ok();
	} else {
	    nok("Failed to sort packages correctly");
	    return;
	}
    } else {
	nok();
	return;
    }
}
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub t0003() {
    print "LocalList construction";

    my $umlPath = "./userManagedList.txt";
    my $cplPath = "./currentPackageList.txt";

# !!! BEWARE of changes. change_control test relies on the order of $list1 !!!
    my $list1 = <<'EOD'; 
-  package-2 0.17 10 i386
-  package-1 2.4 10 i386

-  package-3 2.25.1 20 i386 # text we dont want
#-  Some text we don't want.
-  package-4 1.1.1 1 i386
-  package-6 1.0.2 1 i386
-  package-5 2.0.21 1 i386
#
-  package-7 2.2.2 1 i386
EOD

    my $list2 = <<'EOD'; 
-  package-9 2.2.2 1 i386
-  package-10 1.14 1 i386
-  package-8 2.2.2 1 i386
EOD


    system("rm $umlPath")  if -e $umlPath;
    # write
    unless ( file_contents($cplPath,$list1) ) {
	nok("Failed to write the current package list");
	return;
    }
    report(0);
    # create an empty (we've just deleted the file) uml
    my $uml = SPM::LocalList->new($umlPath);

    unless (@{$uml->get_list()} == 0) {
	nok("Failed to load an empty package list");
	return;
    }
    report();
    # create another uml to check loading
    my $cpl = SPM::LocalList->new($cplPath);

    unless (@{$cpl->get_list()} == 7) {
	nok("Failed to load correct number of packages ".@{$cpl->get_list()});
	return;
    }
    report();

    $uml->merge_before($cpl->get_list());

    unless (@{$uml->get_list()} == 7) {
	nok("Failed to update empty uml to correct number of packages ".@{$uml->get_list()});
	return;
    }
    report();
    ############################
    # check adding some packages
    ############################
    # update the file contents for current list
    unless ( file_contents($cplPath,$list2.$list1) ) {
	nok("Failed to write the updated current package list");
	return;
    }

    $cpl = SPM::LocalList->new($cplPath);

    unless (@{$cpl->get_list()} == 10) {
	nok("Failed to load correct number of packages ".@{$cpl->get_list()});
	return;
    }

    $uml->merge_after($cpl->get_list());

    unless (@{$uml->get_list()} == 10) {
	nok("Failed to update  uml to correct number of packages ".@{$uml->get_list()});
	return;
    }
    report();

    ##############################
    # check deleting some packages
    ##############################
    # update the file contents for current list
    unless ( file_contents($umlPath,$list1.$list2) ) {
	nok("Failed to write the updated managed package list");
	return;
    }
    
    $uml = SPM::LocalList->new($umlPath);

    unless (@{$uml->get_list()} == 10) {
	nok("Failed to load correct number of packages ".@{$uml->get_list()});
	return;
    }

    # update the file contents for current list
    unless ( file_contents($cplPath,$list1) ) {
	nok("Failed to write the updated managed package list");
	return;
    }
    
    $cpl = SPM::LocalList->new($cplPath);

    unless (@{$cpl->get_list()} == 7) {
	nok("Failed to load correct number of packages ".@{$uml->get_list()});
	return;
    }
    report();
    
    ###############################
    # Merge_before
    ###############################

    $uml->merge_before($cpl->get_list());

    my $lst = $uml->get_list();

    unless (@$lst == 10) {
	nok("Failed to update uml to correct number of packages after delete".@$lst);
	return;
    }
    my @unwanteds = grep { $_->get_attrib()->{ISUNWANTED} } @$lst;

    unless (@unwanteds == 3) {
	nok("Failed to uml to unwanted after delete".@unwanteds);
    }
    report();

    ###########################
    # check version change
    ###########################

    $list1 =~ s/-  package-4 1.1.1 1 i386/-  package-4 1.1.2 1 i386/;

    # update the file contents for current list
    unless ( file_contents($cplPath,$list1) ) {
	nok("Failed to write the updated current package list");
	return;
    }
    report();
    
    $cpl = SPM::LocalList->new($cplPath);

    unless (@{$cpl->get_list()} == 7) {
	nok("Failed to load correct number of packages ".@{$cpl->get_list()});
	return;
    }
    report();
    
    $uml->merge_after($cpl->get_list());

    unless (@{$uml->get_list()} == 10) {
	nok("Failed to update uml to correct number of packages ".@{$uml->get_list()});
	return;
    }
    report();

    my @p4 = grep { $_->get_name() eq "package-4" } @{$uml->get_list()};

    unless (@p4 == 1) {
	nok("Failed to find updated package in list");
	return;
    }
    if ($p4[0]->get_version() ne "1.1.2") { 
	nok("Wrong updated version ".$p4[0]->get_version());
	return;
	unless ($p4[0]->get_attrib()->{ISLOCAL}) {
	    nok("Failed to set ISLOCAL attribute on added package");
	    return;
	}
    }

    report();

    #########################
    # Change_control
    #########################

    # Create a list where they are all locally managed
    # (We've done this before so I've skipped error checking - sorry !)

    system("rm $umlPath")  if -e $umlPath;

    file_contents($cplPath,$list1);

    $uml = SPM::LocalList->new($umlPath);
    $cpl = SPM::LocalList->new($cplPath);

    $uml->merge_before( $cpl->get_list() );

    my @matches = grep { $_->get_attrib()->{ISLOCAL} == 1 } @{$uml->get_list()};

    unless (@matches == 7) {
	nok("Failed to prepare for control checking");
	return;
    }

    # Put some of the same packages in a new target list and stir...
    my @tmp1 = split(/\n/,$list1);
    my @tmp2 = split(/\n/,$list2);
    
    file_contents($cplPath, join( "\n", $tmp2[1], $tmp1[1],
				        $tmp2[0], $tmp1[5] ));
    $cpl = SPM::LocalList->new($cplPath);
    
    $uml->change_control( $cpl->get_list() );

    unless (@{$uml->get_list()} == 7) {
	nok("Failed to prepare target list for control checking.");
	return;
    }

    @matches = grep { $_->get_attrib()->{ISLOCAL} == 1 } @{$uml->get_list()};

    unless (@matches == 5) {
	nok("Failed control checking. ".@matches);
	return;
    }
   
    report();  

    system("rm $cplPath")  if -e $cplPath;
    system("rm $umlPath")  if -e $umlPath;
    
    ok();
}
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub t0004 {
    print "Op operation";

    my @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    my @p2 = ( qw(url dump 0.4b25 1.72.0 i386) );

    my %flags;

    my $op = SPM::Op->new( 99 , [SPM::Package->new(@p1, \%flags)]);

    if ($op) {
	nok("Operation constructor should have failed.");
	return;
    }

    $EC->ignore_error();
    report(0);

    $op = SPM::Op->new(OP_DELETE, [SPM::Package->new(@p1, \%flags)]);

    unless ($op) {
	nok("Failed to construct operation instance.");
    }

    unless ($op->get_operation() eq OP_DELETE) {
	nok("Failed to return correct operation.");
	return;
    }
    report();

    my @pkgs =  $op->get_packages();
  
    unless (@pkgs == 1) {
	nok("Failed to return correct sized array ".scalar(@pkgs));
	return;
    }

    unless ($pkgs[0]->get_name() eq "pine") {
	nok("Failed to return correct package array");
    }
    report();

    # Check REPLACE operation - requires from-to packages.

    $op = SPM::Op->new(OP_REPLACE, [SPM::Package->new(@p1, \%flags)],
		       [SPM::Package->new(@p2, \%flags)]);

    unless ($op) {
	nok("Failed to construct operation instance.");
    }

    unless ($op->get_operation() eq OP_REPLACE) {
	nok("Failed to return correct operation.");
	return;
    }

    @pkgs =  $op->get_packages();
  
    unless (@pkgs == 2) {
	nok("Failed to return correct sized array ".scalar(@pkgs));
	return;
    }

    unless ($pkgs[1]->get_name() eq "dump") {
	nok("Failed to return correct package array");
    }

    report();
    ok();
	
}
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub t0005 {
    print "RPM Packager";

    my $pkgr = SPM::RPMPkgr->new();

    unless ($pkgr) {
	nok("Failed to construct RPM packager");
    }

    my @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    my @p2 = ( qw(url dump 0.4b25 1.72.0 i386) );

    my %flags;

    my $pkg1 = SPM::Package->new(@p1, \%flags);
    my $pkg2 = SPM::Package->new(@p2, \%flags);

    my @ops = $pkgr->get_diff_ops([$pkg1], [$pkg2]);

    if (@ops) {
	nok("diff_ops on packages with different names should have failed.");
	return;
    } else {
	$EC->ignore_error();
    }
    report(0);

    @ops = $pkgr->get_diff_ops(undef, [$pkg2]);

    unless (@ops) {
	nok("Failed to return operation list");
	return;
    }
    unless ($ops[0]->get_operation() eq OP_INSTALL) {
	nok("Failed to compute INSTALL operation correctly - ".
	    $ops[0]->get_operation());
	return;
    }
    report();

    my @pkgs = $ops[0]->get_packages();
    
    unless ($pkgs[0]->get_name() eq "dump") {
        nok("Failed to correctly store package");
	return;
    }

    @ops = $pkgr->get_diff_ops([$pkg1], undef);

    unless (@ops) {
	nok("Failed to return operatin list");
	return;
    }
    unless ($ops[0]->get_operation() eq OP_DELETE) {
	nok("Failed to compute DELETE operation correctly -".
	    $ops[0]->get_operation());
	return;
    }

    @pkgs = $ops[0]->get_packages();
    
    unless ($pkgs[0]->get_name() eq "pine") {
        nok("Failed to correctly store package");
        return;
    }
    report();

    @p2 = ( qw(url pine 4.44 1.72.1 i386) );
    $pkg2 = SPM::Package->new(@p2, \%flags);

    @ops = $pkgr->get_diff_ops([$pkg1], [$pkg2]);

    unless (@ops) {
	nok("Failed to return operation list");
	return;
    }
    unless ($ops[0]->get_operation() eq OP_REPLACE) {
	nok("Failed to compute REPLACE operation correctly.");
	return;
    }

    @pkgs = $ops[0]->get_packages();
    
    unless ($pkgs[0]->get_release() eq "1.72.0") {
	nok("Failed to correctly store source package for REPLACE");
	return;
    }

    unless ($pkgs[1]->get_release() eq "1.72.1") {
	nok("Failed to correctly store target package for REPLACE");
	return;
    }
    report();

    # Get adjusted source and target lists

    my (@install, @delete, @replace);

    my $installed = $pkgr->get_installed_list();

    my $count = scalar(@$installed);
    unless ($count > 2) {
	nok($EC->error->text());
	$EC->ignore_error();
    }
    report();

    my $target = $pkgr->get_installed_list();

    for (my $i = 0; $i < 2; $i++) {
	my $pkg = shift(@$installed);   # save some for replacing
	shift(@$target);
	my $txt = $pkg->print();
	my @txt = split(/ +/,$txt);
	$txt[2] = "1.0";
	my $newpkg = SPM::Package->new( @txt, {} );
	push(@replace,$newpkg);
	$txt[2] = "2.0";
	$newpkg = SPM::Package->new( @txt, {} );
	push(@replace,$newpkg);
    } 

    my $founddel = 0;
    my $foundinst = 0;
    my $foundrep = 0;

    for (my $i = 0; $i < 2; $i++) {
	push(@install,shift(@$installed));
    } 

    for (my $i = 0; $i < 2; $i++) {
	push(@delete,pop(@$target));
    } 

    while (@replace) {       # Put replacement packages back in the lists
	push(@$target,shift(@replace));
	unshift(@$installed,shift(@replace));
    }

    # Get all difference operations

    @ops = $pkgr->get_all_ops($installed, $target);

    for my $op (@ops) {

	@pkgs = $op->get_packages();
	my $name = $pkgs[0]->get_name();

	if ($op->get_operation() eq OP_DELETE) {
	    foreach my $p (@delete) {
		if ($p->get_name() eq $name) {
		    $founddel++;
		    last;
		}
	    }
	} elsif ($op->get_operation() eq OP_INSTALL) {
	    foreach my $p (@install) {
		if ($p->get_name() eq $name) {
		    $foundinst++;
		    last;
		}
	    }
	} elsif ($op->get_operation() eq OP_REPLACE) {
	    $foundrep++;
	} elsif ($op->get_operation() ne OP_NOTHING) {
	    nok("Unexpected operation returned.");
	    return;
	}
    }
	  
    unless ($foundrep == 2) {
	nok("Failed to get correct REPLACE ops for get_all_diff ($foundrep)");
	return;
    }
    unless ($founddel == 2) {
	nok("Failed to get correct DELETE ops for get_all_diff ($founddel)");
	return;
    }
    unless ($foundinst == 2) {
	nok("Failed to get correct INSTALL ops for get_all_diff ($foundinst)");
	return;
    }
    report();

    ok("Counted ".@$installed." installed packages. ".@ops." operations.");
}
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub t0006 {
    print "Policy ";

    ###########################
    # Initialise from file

    my $policyFile = './policyconfig';

    my $policy = "allowuserpackages prioritytouserpackages";

    file_contents($policyFile, $policy);

    my $pol = SPM::Policy->new( $policyFile );

    unless ($pol) {
	nok("Failed to open policy config. file.");
    }
    report(0);
    ###########################
    # Policy consistency check

    $pol = SPM::Policy->new( {"allowuserpackages" => 0, 
				 "prioritytouserpackages" => 1}  );

    if ($pol) {
	nok("Policy consistency check should have failed.");
	return;
    }
    $EC->ignore_error();
    report();
    $pol = SPM::Policy->new( {} );

    unless ($pol) {
	nok("Failed to create default policy");
	return;
    }

    my @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    my @p2 = ( qw(url dump 0.4b25 1.72.0 i386) );

    ###########################
    # Delete operations
    
    my $op = SPM::Op->new(OP_DELETE , [SPM::Package->new(@p1, {})]);

    my $ops = $pol->apply([$op]);

    unless (@$ops == 1) {
	nok("Failed to keep DELETE operation when ALLOWUSERPACKAGES is disabled.");
	return;
    }
    report();
    $pol = SPM::Policy->new( { 'allowuserpackages' => 1 } );

    unless ($pol) {
	nok("Failed to create policy allowuserpackage enabled");
	return;
    }

    $ops = $pol->apply([$op]);

    unless (@$ops == 1) {
	nok("Failed to pass DELETE operation when ALLOWUSERPACKAGES is enabled but not local package.");
    }
    report();
    $op = SPM::Op->new(OP_DELETE , [SPM::Package->new(@p1, {
                                           'islocal' => 1 })]);
    
    $ops = $pol->apply([$op]);

     unless (@$ops == 0) {
	nok("Failed to cull DELETE operation when ALLOWUSERPACKAGES is enabled with a local package.");
	return;
    }
    report();

    ###########################
    # Install operations
    
    $op = SPM::Op->new(OP_INSTALL , [SPM::Package->new(@p1, { })]);

    $ops = $pol->apply([$op]);

    unless (@$ops == 1) {
	nok("Failed to keep basic INSTALL operation.");
	return;
    }
    report();
    $op = SPM::Op->new(OP_INSTALL , [SPM::Package->new(@p1, {
                                         'isunwanted' => 1 })]);

    $ops = $pol->apply([$op]);

    unless (@$ops == 0) {
	nok("Failed to cull unwanted install operation.");
	return;
    }
    report();
    ######################################
    # Nothing operations - identical lists

    @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    @p2 = ( qw(url pine 4.44 1.72.0 i386) );

    $op = SPM::Op->new(OP_NOTHING , [SPM::Package->new(@p1, {})],
			                  [SPM::Package->new(@p2, {})]);

    $pol = SPM::Policy->new( { } );

    unless ($pol) {
	nok("Failed to create default policy for NOTHING test");
	return;
    }

    $ops = $pol->apply([$op]);

    unless (@$ops == 0) {
	nok("Failed to cull simple nothing operation.");
	return;
    }
    report();
    ######################################
    # Nothing operations - target unwanted

    @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    @p2 = ( qw(url pine 4.44 1.72.0 i386) );

    $op = SPM::Op->new(OP_NOTHING , 
		       [SPM::Package->new(@p1, {})],
		       [SPM::Package->new(@p2, {'isunwanted' => 1})]);

    $pol = SPM::Policy->new( { } );

    unless ($pol) {
	nok("Failed to create default policy for NOTHING test");
	return;
    }

    $ops = $pol->apply([$op]);

    unless (@$ops == 1 && $$ops[0]->get_operation() eq OP_DELETE) {
	nok("Failed to transform target UNWANTED to DELETE operation.");
	return;
    }
    report();
    #####################################################
    # Nothing operations - target mandatory already there

    @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    @p2 = ( qw(url pine 4.44 1.72.0 i386) );

    $op = SPM::Op->new(OP_NOTHING , 
		       [SPM::Package->new(@p1, {})],
		       [SPM::Package->new(@p2, {'ismandatory' => 1})]);

    $pol = SPM::Policy->new( { } );

    unless ($pol) {
	nok("Failed to create default policy for NOTHING test");
	return;
    }

    $ops = $pol->apply([$op]);

    unless (@$ops == 0) {
	nok("Failed to cull simple mandatory operation.");
	return;
    }
    report();
    #################################################
    # Nothing operations - target mandatory not there

    @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    @p2 = ( qw(url pine 4.44 1.72.0 i386) );

    $op = SPM::Op->new(OP_NOTHING , 
		       [SPM::Package->new(@p1, {'isunwanted'  => 1})],
		       [SPM::Package->new(@p2, {'ismandatory' => 1})]);

    $pol = SPM::Policy->new( { } );

    unless ($pol) {
	nok("Failed to create default policy for NOTHING test");
	return;
    }

    $ops = $pol->apply([$op]);

    unless (@$ops == 1 && $$ops[0]->get_operation() eq OP_INSTALL) {
	nok("Failed to transform target MANDATORY to INSTALL operation.");
	return;
    }


    #################################################
    # Nothing operations - mixed lists

    @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    @p2 = ( qw(url pine 4.45 1.72.0 i386) );
    my @p3 = ( qw(url pine 4.44 1.72.0 i386) );
    my @p4 = ( qw(url pine 4.45 1.72.0 i386) );

    $op = SPM::Op->new(OP_NOTHING , 
		       [SPM::Package->new(@p1, { }), 
		        SPM::Package->new(@p2, { })],
		       [SPM::Package->new(@p3, {'isunwanted'  => 1}), 
		        SPM::Package->new(@p4, { })]);

    $pol = SPM::Policy->new( { } );

    unless ($pol) {
	nok("Failed to create default policy for NOTHING test");
	return;
    }

    $ops = $pol->apply([$op]);

    unless (@$ops == 1 && $$ops[0]->get_operation() eq OP_DELETE) {
	nok("Failed to handle combined delete and leave.");
	return;
    }
    #################################################
    # Nothing operations - inconsistent lists

    @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    @p2 = ( qw(url pine 4.45 1.72.0 i386) );
    @p3 = ( qw(url pine 4.44 1.72.0 i386) );
    @p4 = ( qw(url pine 4.46 1.72.0 i386) );

    $op = SPM::Op->new(OP_NOTHING , 
		       [SPM::Package->new(@p1, { }), 
		        SPM::Package->new(@p2, { })],
		       [SPM::Package->new(@p3, {'isunwanted' => 1 }), 
		        SPM::Package->new(@p4, { })]);

    $pol = SPM::Policy->new( { } );

    unless ($pol) {
	nok("Failed to create default policy for NOTHING test");
	return;
    }

    $ops = $pol->apply([$op]);

    unless ($EC->error()) {
	nok("Failed to trap inconsistent null update lists.");
	return;
    }

    $EC->ignore_error();

    #################################################
    # REPLACE operations - simple one package replaces one

    @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    @p2 = ( qw(url pine 4.45 1.72.0 i386) );
    @p3 = ( qw(url pine 4.46 1.72.0 i386) );
    @p4 = ( qw(url pine 4.47 1.72.0 i386) );

    $op = SPM::Op->new(OP_REPLACE , 
		       [SPM::Package->new(@p1, { })],
		       [SPM::Package->new(@p3, { })]);

    $pol = SPM::Policy->new( { } );

    unless ($pol) {
	nok("Failed to create default policy for REPLACE test");
	return;
    }

    $ops = $pol->apply([$op]);

    unless (@$ops = 1 && $$ops[0]->get_operation() eq OP_REPLACE) {
	nok("Failed to handle simple replace.");
	return;
    }

    report();
    ##########################################################################
    # REPLACE operations - keep one + one package replace

    $op = SPM::Op->new(OP_REPLACE , 
		       [SPM::Package->new(@p1, { }),
			SPM::Package->new(@p2, { })],
		       [SPM::Package->new(@p3, { }),
			SPM::Package->new(@p1, { })]);

    $pol = SPM::Policy->new( { } );

    unless ($pol) {
	nok("Failed to create default policy for REPLACE test");
	return;
    }

    $ops = $pol->apply([$op]);

    unless (@$ops == 2 && $$ops[0]->get_operation() eq OP_DELETE &&
	                 ($$ops[0]->get_packages())[0]->get_version() 
	                                                   eq "4.45" && 
	                 $$ops[1]->get_operation() eq OP_INSTALL &&
	                 ($$ops[1]->get_packages())[0]->get_version() 
	                                                   eq "4.46") {
	nok("Failed to handle multiple replace.");
	return;
    }

    report();
    ##########################################################################
    # REPLACE operations - Two replace one

    $op = SPM::Op->new(OP_REPLACE , 
		       [SPM::Package->new(@p1, { })],
		       [SPM::Package->new(@p2, { }),
			SPM::Package->new(@p3, { })]);

    $pol = SPM::Policy->new( { 'ALLOWUSERPACKAGES'      => 1 ,
			       'PRIORITYTOUSERPACKAGES' => 1 } );

    $ops = $pol->apply([$op]);

    unless (@$ops == 3 && $$ops[0]->get_operation() eq OP_DELETE &&
	                 ($$ops[0]->get_packages())[0]->get_version() 
	                                                   eq "4.44" && 
	                 $$ops[1]->get_operation() eq OP_INSTALL &&
	                 ($$ops[1]->get_packages())[0]->get_version() 
	                                                   eq "4.45") {
	nok("Failed to handle multiple replace.");
	return;
    }

    report();
    ##########################################################################
    # REPLACE operations - Local priority

    $op = SPM::Op->new(OP_REPLACE , 
		       [SPM::Package->new(@p1, { 'ISLOCAL'    => 1, 
			                         'ISUNWANTED' => 1 })],
		       [SPM::Package->new(@p3, { }),
			SPM::Package->new(@p1, { })]);

    $pol = SPM::Policy->new( { 'ALLOWUSERPACKAGES'      => 1 ,
			       'PRIORITYTOUSERPACKAGES' => 1 } );

    unless ($pol) {
	nok("Failed to create default policy for REPLACE test");
	return;
    }

    $ops = $pol->apply([$op]);

    unless (@$ops == 0) {
	nok("Failed to handle local priority non-replace.");
	return;
    }

    report();
    ##########################################################################
    # REPLACE operations - with wildcards

    @p1 = ( qw(url pine 4.44 1.72.0 i386) );
    @p2 = ( qw(url pine 4.45 1.72.0 i386) );
    @p3 = ( qw(url pine * * i386) );

    $op = SPM::Op->new(OP_REPLACE ,
		       [SPM::Package->new(@p1, { }) ,	       
		        SPM::Package->new(@p2, { 'islocal' => 1 } )],	       
		       [SPM::Package->new(@p3, { 'isunwanted' => 1 }) ]);

    $pol = SPM::Policy->new( { 'ALLOWUSERPACKAGES'      => 1 ,
			       'PRIORITYTOUSERPACKAGES' => 1 } );
 
    $ops = $pol->apply([$op]);

    unless (@$ops == 2 && $$ops[0]->get_operation() eq OP_DELETE &&
	    $$ops[1]->get_operation() eq OP_DELETE) {
	nok("Failed to do a forced wildcard delete");
    }
    
    ok();
}
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub report {
    $report = shift if @_;
    print ++$report."+";
}
sub ok {
    if (@_) {
	printf " (%s)...OK\n",$_[0]; 
    } else {
	print "...OK\n";
    }
    return 1;
}
sub nok {
    if (@_) {
	printf " (%s)...FAILED\n",$_[0]; 
    } else {
	print "...FAILED\n";
    }
    $fails = $fails + 1;
    return 0;
}
sub nologging {
    return 1;
}
sub logging {
    print (join(' ',@_));
    return 1;
}

 
#t0001();
#t0002();
#t0003();
#t0004();
#t0005();
#t0006();
