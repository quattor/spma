package SPM::Packager;
#+############################################################################
#
# File: Packager.pm
#

=head1 NAME

SPM::Packager - Virtual base class for abstract SPMA packager.

=head1 SYNOPSIS

    $pkgr = SPM::ConcretePackager->new($cachepath,$reverseproxy);
    ..
    @pkgs = $pkgr->get_installed_list();  # Virtual
    ..
    $status = $pkgr->execute_ops( \@ops ); # Virtual
    ..
    @ops = $pkgr->get_diff_ops( \@srcpkgs, \@tgtpkgs );
    ..
    @ops = $pkgr->get_all_ops( \@srcpkgs, \@tgtpkgs );
    ..
    $status = $pkgr->execute( \@currentList, \@targetList );


=head1 DESCRIPTION

    Base class for abstract software packager. Subclasses of concrete
    packagers inherit from this class. Subclasses MUST implement
    methods 

    get_installed_list
    execute_ops
    _print_packager_filename


=over

=cut

use strict;
use vars qw(@ISA $VERSION);

use LC::Exception qw(SUCCESS throw_error);

use CAF::Object;
use CAF::Reporter;

use SPM::Op qw(OP_INSTALL OP_DELETE OP_REPLACE OP_NOTHING);

$VERSION = 1.00;
@ISA = qw(CAF::Object CAF::Reporter);

#============================================================================#
# new
#----------------------------------------------------------------------------#

=item new( )

    $pkgr = SPM::ConcretePackager->new($cachepath,$reverseproxy);

    Create an instance of a Packager. Should be called by subclass
    constructors only.

=cut

#-----------------------------------------------------------------------------#
sub _initialize {
    my ($self,$cachepath,$proxytype,$proxyhost,$proxyport) = @_;

    $self->{'CACHEPATH'}=$cachepath;

    $self->{'FWDPROXY'}=undef;
    $self->{'FWDPROXYPORT'}=undef;
    $self->{'REVERSEPROXY'}=undef;
    if (defined $proxytype) {
      if ($proxytype eq 'reverse') {
	my $reverseproxy=$proxyhost;
	$reverseproxy.=':'.$proxyport if (defined $proxyport);
	$self->{'REVERSEPROXY'}=$reverseproxy;
      } else {
	$self->{'FWDPROXY'}=$proxyhost;
	$self->{'FWDPROXYPORT'}=$proxyport;
      }
    }

    return SUCCESS;
}

#============================================================================#
# get_installed_list
#----------------------------------------------------------------------------#

=item get_installed_list( ):LIST

    @pkgs = $pkgr->get_installed_list();

    This is a virtual method and MUST be implemented by a
    subclass. The method returns a list of Package objects in the
    current package database. i.e. packages currently installed on the
    machine.

=cut

#-----------------------------------------------------------------------------#
sub get_installed_list {
    my $self = shift;

    throw_error("Missing sub-class method implementation");
    return;
}
#============================================================================#
# get_diff_ops
#----------------------------------------------------------------------------#

=item get_diff_ops( SOURCELISTREF, TARGETLISTREF ):LIST

    @ops = $pkgr->get_diff_ops( \@srcpkgs, \@tgtpkgs );
    @ops = $pkgr->get_diff_ops( undef, \@tgtpkgs );
    @ops = $pkgr->get_diff_ops( \@srcpkgs, undef );

    Return an operations list which, when applied, will change from
    the source to the target state. NOTE: All packages MUST have the
    same name. (see also get_all_ops below). If SOURCELISTREF is
    undefined then this implies that the package(s) are not in the
    target list. Similarly for TARGETLISTREF which implies the targets
    are not currently installed.

=cut

#-----------------------------------------------------------------------------#
sub get_diff_ops {
    my $self = shift;

    my $srcref = shift;
    my $tgtref = shift;

    my @out;

    if (! $srcref) {
	# no source packages - install the target
	push(@out, SPM::Op->new(OP_INSTALL, $tgtref));
    } elsif (! $tgtref) {
	# no target packages - delete the source
	push(@out, SPM::Op->new(OP_DELETE, $srcref));
    } else {	
	# both packages - if versions differ then need to replace
	push(@out, $self->_get_replace_op($srcref, $tgtref));
    }

    return @out;
}
#============================================================================#
# get_all_ops
#----------------------------------------------------------------------------#

=item get_all_ops( SOURCELISTREF, TARGETLISTREF):LIST

    @ops = $pkgr->get_all_ops( \@srcpkgs, \@tgtpkgs );

    Return a list of operations which will transform the machine state
    from the SOURCELIST to the TARGETLIST. 

=cut

#-----------------------------------------------------------------------------#
sub get_all_ops {
    my $self = shift;

    my ($srclst, $tgtlst) = @_;

    my (@out, @ops);

    # First sort both lists into NAME order into a couple of local lists

    my @slst = sort {$a->get_name() cmp $b->get_name()} @$srclst;
    my @tlst = sort {$a->get_name() cmp $b->get_name()} @$tgtlst;

    while (@slst && @tlst) {

	my $sw = $slst[0]->get_name() cmp $tlst[0]->get_name();

	if ($sw < 0) {
	    # Source package does not exist in target list - ?delete?
	    @ops = $self->get_diff_ops([shift(@slst)],undef);
	} elsif ($sw > 0) {
	    # Target package does not exist in source list - ?install?
	    @ops = $self->get_diff_ops(undef,[shift(@tlst)]);
	} else {
	    # Package with same name in both source and target
	    # Here we have to handle the case of the lists holding
	    # several packages with the same name but different 
	    # versions
	    @ops = $self->get_diff_ops(\@slst,\@tlst);
	}
	push(@out,@ops);
    }

    while (@slst) {
	@ops = $self->get_diff_ops([shift(@slst)],undef);
	push(@out,@ops);
    }
    while (@tlst) {
	@ops = $self->get_diff_ops(undef,[shift(@tlst)]);
	push(@out,@ops);
    }

    return @out;
}
#============================================================================#
# execute
#----------------------------------------------------------------------------#

=item execute( SOURCELISTREF, TARGETLISTREF [, POLICY]):SCALAR

    $status = $pkgr->execute( \@currentList, \@targetList );
    ..
    $status = $pkgr->execute( \@currentList, \@targetList, $policy )

    Transform the machine state from SOURCELIST packages to TARGETLIST
    packages.

=cut

#-----------------------------------------------------------------------------#
sub execute {
    my $self = shift;
    
    my ($srclst, $tgtlst, $policy) = @_;
    my $ops_to_apply;

    my @ops = $self->get_all_ops($srclst, $tgtlst);
    
    $self->debug(1,scalar(@ops)." operations before applying policy..");

    if ($policy) {
	$ops_to_apply = $policy->apply( \@ops );
    } else {
	$ops_to_apply = \@ops;
    }

    if (@$ops_to_apply) {
      $self->info("The following package operations are required:");
      foreach my $op (@$ops_to_apply) {
	$self->report('       '.$op->print());
      }
      $self->info("Please be patient... ".scalar(@$ops_to_apply).
		  " operation(s) to verify/execute.");
      return $self->execute_ops ($ops_to_apply);
    } else { 
      $self->info("Packages are up-to-date - no operations to perform.");
      return 0;
    }
}
#============================================================================#
# execute_ops
#----------------------------------------------------------------------------#

=item execute_ops( OPSLIST ):SCALAR

    $status = $pkgr->execute_ops(\@ops);

    This is a virtual method and MUST be implemented by a
    subclass. The subclass uses the appropriate package transaction
    application to apply the operation set and returns the application
    exit status.

=cut

#-----------------------------------------------------------------------------#
sub execute_ops {
    my $self = shift;

    throw_error("Missing sub-class method implementation");
    return;
}
#============================================================================#
# _shift_to_temp(LISTREF):LIST
#----------------------------------------------------------------------------#
sub _shift_to_temp {
    # Return array of packages with the same name taken from the 
    # front of the input array
    my $self = shift;
    my $inref = shift;

    my @out;

    if (@$inref == 1) {

        push(@out,shift(@$inref));

    } elsif (@$inref > 1) {

        push(@out,shift(@$inref));
        my $name = $out[0]->get_name();

        while (@$inref && ($name eq $$inref[0]->get_name())) {
            push(@out,shift(@$inref));
        }
    }
    return @out;
}

#============================================================================#
# _get_replace_ops - private
#----------------------------------------------------------------------------#
sub _get_replace_op {

    my $self = shift;
    my $srcref = shift;
    my $tgtref = shift;

    my $op;

    # First copy source and targets with same name to a couple of arrays

    my @tmpsrc = $self->_shift_to_temp($srcref);
    my @tmptgt = $self->_shift_to_temp($tgtref);

    unless ($tmpsrc[0]->get_name() eq $tmptgt[0]->get_name()) {
        throw_error("Package names must be equal ".
                    $tmpsrc[0]->get_name()."<>".$tmptgt[0]->get_name());
        return;
    }

    # Now check each source package to see if it matches a target

    if (@tmpsrc == @tmptgt) {
        foreach my $ps (@tmpsrc) {
            my $found = 0;
            foreach my $pt (@tmptgt) {
                if ($ps->is_equal($pt)) {
                    # most times only one so don't optimize
                    $found = 1;
                }
            }
            unless ($found) {
                # Didn't find a match - only need one negative
                return (SPM::Op->new(OP_REPLACE,\@tmpsrc,\@tmptgt));
            }
        }
        # All packages match
        return (SPM::Op->new(OP_NOTHING,\@tmpsrc,\@tmptgt));
    }

    # List lengths were different

    return (SPM::Op->new(OP_REPLACE,\@tmpsrc,\@tmptgt));

}


#============================================================================#
# _print_package_cache_path - private
#----------------------------------------------------------------------------#
sub _print_package_cache_path {
  my $self = shift;
  my $pkg = shift;

  my $return=undef;

  my $revprox=$self->{'REVERSEPROXY'};
  if (defined $revprox) {
    my $transform_url=$pkg->get_URL;
    $transform_url=~ s%^(http://|ftp://)?[^/]+(.*)%$1$revprox$2%;
    $return=$transform_url."/".$self->_print_package_filename($pkg);
  } else {
    $return=$self->_print_package_repository_path($pkg);
  }
  if (defined $self->{'CACHEPATH'} &&
      -r $self->{'CACHEPATH'}."/".$self->_print_package_filename($pkg)) {
    # package is in the cache. Take it from there
    $self->report('       taking from cache: '.$pkg->print());
    $return=$self->{'CACHEPATH'}."/".$self->_print_package_filename($pkg);
  }
  return $return;
}

#============================================================================#
# _print_package_repository_path - private
#----------------------------------------------------------------------------#
sub _print_package_repository_path {
    my $self = shift;
    my $pkg = shift;

    return $pkg->get_URL."/".$self->_print_package_filename($pkg);
}




#+#############################################################################
1;

=back

=head1 AUTHORS

Original Author: Ian Neilson, changes by: German Cancio

=head1 VERSION

$Id: Packager.pm.cin,v 1.5 2005/09/21 11:48:22 gcancio Exp $

=cut
