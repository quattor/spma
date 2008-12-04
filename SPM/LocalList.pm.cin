package SPM::LocalList;
#+############################################################################
#
# File: LocalList.pm
#

=head1 NAME

SPM::LocalList - Persistent list of locally managed packages.

=head1 SYNOPSIS

    use SPM::LocalList

    # Constructor

    my $lcl = LocalList->new ( $path,$testing,$uselist);

    # Update list 

    $lcl->merge_before ( $currentList ); # Before SPMA updates
    ..
    ..
    $lcl->merge_after  ( $currentList ); # After SPMA updates

    # Adjust "ownership" of package

    $lcl->change_control ( $targetList ); 

=head1 DESCRIPTION

    Provides services to the SPMA  related to maintaining the list
    of 'user managed' packages on the local machine.

    Each package in the list can be in one of three states which are signalled
    by the appropriate package flags -

    "System managed"  : installed by the Software Package Manager Agent (SPMA)
                        - ISLOCAL flag false.
    "Locally managed" : installed by the user.
                        - ISLOCAL flag true

    Two primary messages are processed, both of which receive a list of all
    packages installed on the local machine when the message is sent.

    'merge_before' is assumed to be sent prior to package installation
    by the SPMA.
    'merge_after' is assumed to be called after package installation
    by the SPMA.

    For each method the installed package list is compared to the 'managed
    list' maintained by the LocalList instance. 'update-before' determines
    all changes made by the user since the last time the SPMA was invoked
    and updates the list according to the states above. Similarly 
    'update-after' determines all changes actually committed by the SPMA
    in the current invocation.

    The list is assumed to be stored in the file path given as a constructor 
    argument. If the file does not exist one will be created when the object 
    is sent an 'update-before' message. At which time all packages in the 
    'update' list will be imported to the local list as "locally managed".

    A third 'change_control' message is implemented to allow packages
    which were originally installed "locally" to be reclaimed by the
    SPMA.

=over

=cut

use strict;

use vars qw(@ISA $VERSION);

use LC::Exception qw(SUCCESS throw_error);
use SPM::PackageListFile ();
use CAF::Object;
use CAF::Reporter;

$VERSION = 1.00;
@ISA = qw(CAF::Object CAF::Reporter);


#============================================================================#
# new
#----------------------------------------------------------------------------#

=item new( PATH )

    my $lcl = LocalList->new( $path, $testing, $uselist);

    Class method for constructing LocalList object. The PATH argument
    contains the filesystem location where the persistent package data is
    stored.

=cut

#-----------------------------------------------------------------------------#
sub _initialize {

    my ($self,$path,$testing,$uselist) = @_;

    my $uml  = [];

    # Load current userManagedList

    my $file = SPM::PackageListFile->new( $path );

    return unless $file;

    $self->_set_testing($testing);

    if ( $file->exists()) {
      if ($uselist) {
	# If the file doesn't exist - see the update method
	return unless $uml = $file->read();
      } else {
	unlink($path) unless ($self->_get_testing());
      }
    }

    $self->{_PKGFILE} = $file;
    $self->{_UML} = $uml;
    $self->{_USELIST}=$uselist;

    return SUCCESS;
}

#============================================================================#
# merge_before
#----------------------------------------------------------------------------#

=item merge_before( LIST ):BOOL

    $lcl->merge_before( $currentList );

    Update locally managed list prior to SPMA action. See DESCRIPTION above.

=cut

#-----------------------------------------------------------------------------#
sub merge_before {
    # 
    # Given a current package list (i.e. those on the machine now) - cpl,
    # update the user-managed list - uml.
    # The assumption is that any differences between the uml and the
    # cpl are due to the user/administrators activity
    #
    my $self = shift;
    my $cplin = shift;

    unless (ref($cplin)) {
	throw_error("Expecting reference to Package array as argument");
	return;
    }
    my @cplin  = @$cplin;           # The current package list

    my @umlin  = @{$self->{_UML}};  # The user managed list

    my @out = ();                

    my @cpl = sort { $a->get_name() cmp $b->get_name()} @cplin;
    my @uml = sort { $a->get_name() cmp $b->get_name()} @umlin;

    while ( @cpl && @uml ) {

	my $sw = $cpl[0]->compare_name($uml[0]);

	if ($sw < 0) {
	    # something has been removed

	    $self->_merge_before_pkg_missing(\@uml, \@out);

	} elsif ($sw == 0) {
	    # on both lists (but version etc may change)

	    $self->_merge_before_pkg_exists(\@cpl, \@uml, \@out);

	} else {
	    # something has been added

	    $self->_merge_before_pkg_arrived(\@cpl, \@out);
	}
    }
    #
    while (@cpl) {
	# remainders have been added
	$self->_merge_before_pkg_arrived(\@cpl, \@out);
    }
    #
    while (@uml) {
	# remainders have been removed
	$self->_merge_before_pkg_missing(\@uml, \@out);
    } 

    # Save internally

    $self->{_UML} = \@out;

    # And externally in the file (Not strictly necessary but helps
    #                             program debugging)

    if (!$self->_get_testing() && $self->{'_USELIST'} ) {
	if ($self->{_PKGFILE}->write(\@out)) {
	    return SUCCESS;
	} else {
	    return;
	}
    }
    return SUCCESS;
}


#============================================================================#
# merge_after
#----------------------------------------------------------------------------#

=item merge_after( LIST ):BOOL

    $lcl->merge_after( $currentList );

    Update locally managed list after SPMA action. See DESCRIPTION above.

=cut

#-----------------------------------------------------------------------------#
sub merge_after {

    # Given a current package list (i.e. those on the machine now) - cpl,
    # update the user-managed list - uml.
    # The assumption is that any differences between the uml and the
    # cpl are due to SPMA/Packager activity.

    my $self = shift;
    my $cplin = shift;

    unless (ref($cplin)) {
	throw_error("Expecting reference to Package array as argument");
	return;
    }
    my @cplin  = @$cplin;           # The current package list

    my @umlin  = @{$self->{_UML}};  # The user managed list

    my @out = ();                

    my @cpl = sort { $a->get_name() cmp $b->get_name()} @cplin;
    my @uml = sort { $a->get_name() cmp $b->get_name()} @umlin;

    while ( @cpl && @uml ) {

	my $sw = $uml[0]->get_name() cmp $cpl[0]->get_name();

	if ($sw < 0) {
	    # something has been removed

	    $self->_merge_after_pkg_missing(\@uml, \@out) || return;

	} elsif ($sw == 0) {
	    # on both lists (but version etc may change)

	    $self->_merge_after_pkg_exists(\@cpl, \@uml, \@out) || return;

	} else {
	    # something has been added

	    $self->_merge_after_pkg_arrived(\@cpl, \@out) || return;
	}
    }
    #
    while (@cpl) {
	# remainders have been added
	$self->_merge_after_pkg_arrived(\@cpl, \@out);
    }
    #
    while (@uml) {
	# remainders have been removed
	$self->_merge_after_pkg_missing(\@uml, \@out);
    }

    # Save internally

    $self->{_UML} = \@out;

    # And externally in the file


    if (!$self->_get_testing() && $self->{'_USELIST'} ) {
	if ($self->{_PKGFILE}->write(\@out)) {
	    return SUCCESS;
	} else {
	    return;
	}
    }
    return SUCCESS;
}
#============================================================================#
# change_control
#----------------------------------------------------------------------------#

=item change_control (LIST):BOOL

    $lcl->change_control( $targetList );

    Remove I<ISLOCAL> attribute from any package that appears in the
    input list. This method ensures that all packages managed by the
    current object instance which also appear in the given
    I<targetList> have the I<ISLOCAL> attribute reset (off). This
    procedure allows management of packages, originally installed by
    the local administration to be fully managed by the central site
    administrator if they subsequently appear in the central desired
    list of packages.

=cut

sub change_control {
    my ($self, $tgtref) = @_;

    unless (ref($tgtref) eq 'ARRAY') {
	throw_error("Program error. Expecting package list reference as argument.");
	return;
    }

    my @umlin  = @{$self->{_UML}};  # The user managed list

    my @out = ();                

    my @tgt = sort { $a->get_name() cmp $b->get_name()} @$tgtref;
    my @uml = sort { $a->get_name() cmp $b->get_name()} @umlin;

    while ( @tgt && @uml ) {

	my $sw = $uml[0]->get_name() cmp $tgt[0]->get_name();

	if ($sw < 0) {
	    # Package not in the target => no change.

	    push(@out, shift(@uml));

	} elsif ($sw == 0) {
	    # Package names equal

	    $self->_change_control_exists( \@tgt, \@uml, \@out);

	} else {
	    # Target package not in current list

	    shift(@tgt);
	}
    }

    if (@uml) {
	# Copy any remaining packages across
	push(@out, @uml);
    }

    # Save internally

    $self->{_UML} = \@out;

    # And externally in the file

    if (!$self->_get_testing() && $self->{'_USELIST'} ) {
	if ($self->{_PKGFILE}->write(\@out)) {
	    return SUCCESS;
	} else {
	    return;
	}
    }
    return SUCCESS;


}
#============================================================================#
# _change_control_exists
#----------------------------------------------------------------------------#
sub _change_control_exists {

    # When one or more package versions have already been installed by the
    # local admin we make sure that, if they appear in the target list as
    # well, the target list takes "ownership". i.e set to NOT LOCAL

    my ($self, $tgtref, $umlref, $outref) = @_;

    my @tgts = $self->_shift_to_temp($tgtref);
    my @umls = $self->_shift_to_temp($umlref);

    foreach my $pkg (@umls) {

	# If it's unwanted we don't need to bother - defer to policy later.
        # (unwanted/mandatory targets will be dealt with by force later anyway)

	unless ( $pkg->get_attrib()->{ISUNWANTED} ) {

	    my @matches = grep { $pkg->is_equal($_) } @tgts;

	    if (@matches) {
		$pkg->get_attrib()->{ISLOCAL} = 0;
	    }    
	}

	push(@$outref,$pkg);

    }

    return SUCCESS;
}
#============================================================================#
# _merge_before_pkg_missing - private
#----------------------------------------------------------------------------#
sub _merge_before_pkg_missing {
    my ($self, $umlref, $outref) = @_;

    # User has deleted something (or it was already unwanted and is
    # still not installed)

    my @umls = $self->_shift_to_temp($umlref);

    foreach my $pkg (@umls) {

#	$pkg->get_attrib()->{ISLOCAL} = 1;      # Just for reference really
#	$pkg->get_attrib()->{ISUNWANTED} = 1;
#	push(@$outref,$pkg);

# Policy change G.C 6/02/03: do not allow users to mark SPMA packages
# as UNWANTED. It makes the code more complex and error recovery is
# much more difficult. Thus, these packages will be marked as 'non
# existing' and will be reinstalled by the SPMA if they are on the
# target configuration.

    }

    return SUCCESS
}
#============================================================================#
# _merge_before_pkg_exists - private
#----------------------------------------------------------------------------#
sub _merge_before_pkg_exists {
    my ($self, $cplref, $umlref, $outref) = @_;

    # Here we could have two lists. We need to check if the user
    # has upgraded anything

    my @cpls = $self->_shift_to_temp($cplref);
    my @umls = $self->_shift_to_temp($umlref);

    # Check each that is in the current list against the saved list 
    # new arrivals => locally managed.

    foreach my $pkg (@cpls) {
	my @matches = grep { $pkg->is_equal($_) } @umls;

	if (@matches && ! $matches[0]->get_attrib()->{ISUNWANTED} ) {
	    # same version still on the system and it was
	    # not previously unwanted
	    push(@$outref,$pkg);
	} else {
	    # package version has changed or it has been reinstalled
	    $pkg->get_attrib()->{ISLOCAL} = 1;
	    push(@$outref,$pkg);  
	}
    }

    return SUCCESS;
}
#============================================================================#
# _merge_before_pkg_arrived - private
#----------------------------------------------------------------------------#
sub _merge_before_pkg_arrived {
    my ($self, $cplref, $outref) = @_;

    my @cpls = $self->_shift_to_temp($cplref);

    foreach my $pkg (@cpls) {
	$pkg->get_attrib()->{ISLOCAL} = 1;
	push(@$outref,$pkg);
    }

    return SUCCESS;
}
#============================================================================#
# _merge_after_pkg_missing - private
#----------------------------------------------------------------------------#
sub _merge_after_pkg_missing {
    my ($self, $umlref, $outref) = @_;

    my @umls = $self->_shift_to_temp($umlref);

    foreach my $pkg (@umls) {
	if ($pkg->get_attrib()->{ISUNWANTED}) {
	    # If it was locally specified as unwanted then keep it on 
	    # the uml. Otherwise just drop it.
	    push(@$outref,$pkg);
	}
    }

    return SUCCESS
}
#============================================================================#
# _merge_after_pkg_exists - private
#----------------------------------------------------------------------------#
sub _merge_after_pkg_exists {
    my ($self, $cplref, $umlref, $outref) = @_;

    # Here we could have two lists. We need to check if the user
    # has upgraded anything

    my @cpls = $self->_shift_to_temp($cplref);
    my @umls = $self->_shift_to_temp($umlref);

    foreach my $pkg (@cpls) {
	my @matches = grep { $pkg->is_equal($_) } @umls;

	if (@matches) {
	    # No change for this version
	    # But was this unwanted by the user and been forced through ?
	    if ($matches[0]->get_attrib()->{ISUNWANTED} &&
		$matches[0]->get_attrib()->{ISLOCAL}) {
		# Make it centrally administered
		push(@$outref,$pkg);
	    } else {
		push(@$outref,$matches[0]);
	    }
	} else {
	    # Version has been changed or extra version added
	    push(@$outref,$pkg);
	}
    }
    return SUCCESS;
}
#============================================================================#
# _merge_after_pkg_arrived - private
#----------------------------------------------------------------------------#
sub _merge_after_pkg_arrived {
    my ($self, $cplref, $outref) = @_;

    my @cpls = $self->_shift_to_temp($cplref);

    push(@$outref,@cpls);

    return SUCCESS;
}
#============================================================================#
# get_list - undocumented back door used for testing. Please don't use it.
#----------------------------------------------------------------------------#
sub get_list {
    my $self = shift;

    return $self->{_UML};
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
sub _get_testing {
    my $self = shift;
    return $self->{_OPTS}->{TESTING};
}
sub _set_testing {
    my $self = shift;
    $self->{_OPTS}->{TESTING} = shift;
}    
#+############################################################################
1;

=back

=head1 AUTHORS

Original Author : Ian Neilson <Ian.Neilson@cern.ch>
Modifications by: German Cancio <German.Cancio@cern.ch>

=head1 VERSION

$Id: LocalList.pm.cin,v 1.1 2003/08/21 16:07:25 gcancio Exp $

=cut



