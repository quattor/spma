package SPM::Op;
#+############################################################################
#
# File: Op.pm
#

=head1 NAME

SPM::Op - Class representing an SPMA packager operation

=head1 SYNOPSIS

    use SPM::Op qw(OP_INSTALL OP_DELETE OP_REPLACE OP_NOTHING);
    ..
    my $op = SPM::Op->new(OP_DELETE, \@pkgs_to_delete); 
    ..
    my $oper = $op->get_operation()
    ..
    my @pkgs = $op->get_packages()
    ..
    my @pkgs = $op->get_source_packages()
    ..
    my @pkgs = $op->get_target_packages()

=head1 DESCRIPTION

=over

=cut

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
use Exporter;
use LC::Exception qw(SUCCESS throw_error);

use CAF::Reporter;
use CAF::Object;

use constant   OP_NOTHING   => " ";
use constant   OP_DELETE    => "D";
use constant   OP_INSTALL   => "I";
use constant   OP_REPLACE   => "R";

$VERSION = 1.00;
@ISA = qw(Exporter CAF::Object CAF::Reporter);

@EXPORT = qw();
@EXPORT_OK = qw(OP_DELETE OP_INSTALL OP_REPLACE OP_NOTHING);

#=============================================================================#
# new
#-----------------------------------------------------------------------------#

=item new(OP, PACKAGES [,MOREPACKAGES])

    use SPM::Op qw(OP_DELETE OP_INSTALL OP_REPLACE OP_NOTHING);
    ..
    my $pkg = Op->new(OP_DELETE, \@pkgs_to_delete );
    ..
    my $pkg = Op->new(OP_INSTALL, \@pkgs_to_install );
    ..
    my $pkg = Op->new(OP_REPLACE, \@pkgs_to_delete, \@pkgs_to_install );
    ..

    Object constructor. Takes an operation to perform and a list of packages
    on which the operation should be applied. Valid operations are

    OP_DELETE  - delete the given packages
    OP_INSTALL - install the given packages (Note:NOT and upgrade/downgrade)
    OP_REPLACE - replace package versions (Note:package names MUST be equal)
    OP_NOTHING - NUL operation where package lists are identical but attributes
                 may be different.

    DELETE and INSTALL operations take a single list of packages. 
    REPLACE and NOTHING operations take a source and target list.

=cut

#-----------------------------------------------------------------------------#
sub _initialize {
    my $self = shift;

    my ($op, $pkgsrc, $pkgtgt) = @_;

    my (@pkgsrc, @pkgtgt);

    unless ($op eq OP_NOTHING || $op eq OP_DELETE || $op eq OP_INSTALL || 
	    $op eq OP_REPLACE ) {
	throw_error("Invalid operation code: $op");
	return;
    }

    unless (ref($pkgsrc) eq "ARRAY") {
	throw_error("Constructor expecting reference to list of packages.");
	return;
    }

    for my $p (@$pkgsrc) {
	push(@pkgsrc, $p);
    }

    if ($op eq OP_REPLACE || $op eq OP_NOTHING) {
	unless (ref($pkgtgt) eq "ARRAY") {
	    throw_error("Replace or nul operation construction requires two package lists.");
	    return;
	}
	for my $p (@$pkgtgt) {
	    push(@pkgtgt, $p);
	}
    }

    $self->{_OPER} = $op;
    $self->{_PKGSRC} =  \@pkgsrc;
    $self->{_PKGTGT} =  \@pkgtgt;

    return SUCCESS;
}
#=============================================================================#
# get_operation
#-----------------------------------------------------------------------------#

=item get_operation():SCALAR

    use SPM::Op qw(OP_INSTALL OP_DELETE OP_REPLACE OP_NOTHING);
    ..
    my $code = $op->get_operation();

    Returns the object operation code. One of -

    OP_DELETE, OP_INSTALL, OP_REPLACE, OP_NOTHING

=cut

#-----------------------------------------------------------------------------#
sub get_operation {
    my $self = shift;

    return $self->{_OPER};
}
#=============================================================================#
# get_packages
#-----------------------------------------------------------------------------#

=item get_packages( ):LIST

    my @opers = $op->get_packages();

    Return the list of packages for the operation

=cut

#-----------------------------------------------------------------------------#
sub get_packages {
     my $self = shift;

     my @out;

     push(@out, $self->get_source_packages());
     push(@out, $self->get_target_packages());

     return @out;
}
#=============================================================================#
# get_source_packages
#-----------------------------------------------------------------------------#

=item get_source_packages( ):LIST

    my @pkgs = $op->get_source_packages()

    Return a list of source packages. i.e the first package list to constructors
    taking two lists.

=cut

#-----------------------------------------------------------------------------#
sub get_source_packages {
     my $self = shift;

     my @out;

     push(@out, @{$self->{_PKGSRC}});

     return @out;
}
#=============================================================================#
# get_target_packages
#-----------------------------------------------------------------------------#

=item get_target_packages():LIST

    my @pkgs = $op->get_target_packages()

    Return a list of source packages. i.e the second package list to 
    constructors taking two lists.

=cut

#-----------------------------------------------------------------------------#
sub get_target_packages {
     my $self = shift;

     my @out;

     push(@out, @{$self->{_PKGTGT}});

     return @out;
}
#=============================================================================#
# print
#-----------------------------------------------------------------------------#

=item print( ):SCALAR

    print 'This operation will '.$op->print().'.'

    Return a string describing the operation. 

=cut

#-----------------------------------------------------------------------------#
sub print {
    my $self = shift;
    my $txt = undef;

    if ($self->get_operation() eq OP_REPLACE) {
	$txt = "replace ";
	foreach my $pkg ($self->get_source_packages()) {
	    $txt = $txt." ".$pkg->print();
	}
	$txt = $txt." with ";
	foreach my $pkg ($self->get_target_packages()) {
	    $txt = $txt." ".$pkg->print();
	}
    } else {

	$txt = "erase"            if     $self->get_operation() eq OP_DELETE;
	$txt = "install"           if     $self->get_operation() eq OP_INSTALL;

	if (defined($txt)) {
	    foreach my $pkg ($self->get_packages()) {
		$txt = $txt." ".$pkg->print();
	    }
	}
    }
    return $txt;
}
#+#############################################################################
1;

=back

=head1 AUTHOR

Ian Neilson

=head1 VERSION

$Id: Op.pm.cin,v 1.1 2003/08/21 16:07:26 gcancio Exp $

=cut






