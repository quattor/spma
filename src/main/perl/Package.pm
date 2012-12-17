package SPM::Package;
#+############################################################################
#
# File: Package.pm
#

=head1 NAME

SPM::Package - Base class for abstract SPM package.

=head1 SYNOPSIS

    use SPM::Package;

    # Constructors
    $pkg = Package->new( $url, $name, $ver, $rel, $arch, \%attrib );
    ..
    $pkg = Package->new( undef, "Trojan-Horse", "*", "*", "i386",
			 { "isunwanted" => 1 } );
    ..
    $otherPkg = Package->new ( $someText );
    ..
    # Look at the package values (follows RPM naming conventions)
    #
    $self->report ("Package name is ",$pkg->get_name());
    $self->report ("Package version is ",$pkg->get_version());
    $self->report ("Package release is ",$pkg->get_release());
    $self->report ("Package architecture is ",$pkg->get_arch());
    ..
    # Check if package names match
    #
    if ($pkg->compare_name($otherPkg) == 0) {
	$self->report "Package names are identical"; }
    ..
    # Check is package version release and architectures match
    #
    if ($pkg->is_equal($otherPkg) == 1) {
	$self->report "Packages version release and architectures are identical"; }
    ..
    # Generate a string that can be loaded with new.
    #
    $text = $pkg->print();

=head1 DESCRIPTION

This package provides basic functionality of an abstract package class. The following methods are implemented

=over

=cut

use strict;
use vars qw(@ISA $VERSION);

use LC::Exception qw(SUCCESS throw_error);

use CAF::Reporter;
use CAF::Object;
 
$VERSION = 1.00;
@ISA = qw(CAF::Object CAF::Reporter);

#============================================================================#
# new
#----------------------------------------------------------------------------#

=item new( URL, NAME, VERSION, RELEASE, ARCH, ATTRIB )

    $pkg = Package->new( $url, $name, $ver, $rel, $arch, \%attrib );

    $pkg = Package->new( undef, "Trojan-Horse", "*", "*", "i386",
			 { "isunwanted" => 1 } );

    Class method for constructing a new Package object. URL can be
    blank or undefined. VERSION and/or RELEASE can be a single
    wildcard character of "*" which matches any corresponding
    attribute value. If VERSION is wild then RELEASE must be the
    same. ATTRIB is a reference to a hash of attribute keys and
    associated values.

=item new( TEXT )

    $pkg = Package->new( $text );
 
    Class method for constructing a package from text as written by 
    instance method print()

=cut

#-----------------------------------------------------------------------------#
sub _initialize {
    my $self = shift;

    $self->_base_init();       # Come to a known state

    if (scalar(@_) > 1) {
	
	return $self->_init_from_args(@_);

    } else {

	return $self->_init_from_text(@_);

    }
}
#============================================================================#
# get_name
#----------------------------------------------------------------------------#

=item get_name( ):SCALAR

    $self->report ("Package name is ",$pkg->get_name());
  
    Return the package name.

=cut

#----------------------------------------------------------------------------#
sub get_name {
    my $self = shift;
    return $self->{_NAME};
}
sub _set_name {
    my $self = shift;
    $self->{_NAME} = shift;
}
#============================================================================#
# get_version
#----------------------------------------------------------------------------#

=item get_version( ):SCALAR

     print "Package version is ",$pkg->get_version();
   
     Return the package version.

=cut

#-----------------------------------------------------------------------------#
sub get_version {
    my $self = shift;
    return $self->{_VERSION};
}
sub _set_version {
    my $self = shift;
    $self->{_VERSION} = shift;
    return defined $self->{_VERSION};
}
#============================================================================#
# get_release
#----------------------------------------------------------------------------#

=item get_release ( ):SCALAR

    print "Package release is ",$pkg->get_release();
  
    Return the package release. (Following RPM naming convention)

=cut

#----------------------------------------------------------------------------#
sub get_release {
    my $self = shift;
    return $self->{_RELEASE};
}
sub _set_release {
    my $self = shift;
    $self->{_RELEASE} = shift;
    return defined $self->{_RELEASE};
}
#============================================================================#
# get_arch
#----------------------------------------------------------------------------#

=item get_arch( ):SCALAR

    print "Package architecture is ",$pkg->get_arch();

    Return the package architecture.

=cut

#-----------------------------------------------------------------------------#
sub get_arch {
    my $self = shift;
    return $self->{_ARCH};
}
sub _set_arch {
    my $self = shift;
    $self->{_ARCH} = shift;
}
#============================================================================#
# get_URL
#----------------------------------------------------------------------------#

=item get_URL( ):SCALAR

    print "Package URL is ",$pkg->get_URL();
  
    Return the package URL.

=cut

#-----------------------------------------------------------------------------#
sub get_URL {
    my $self = shift;
    return $self->{_URL};
}
sub _set_URL {
    my $self = shift;
    $self->{_URL} = shift;
}
#============================================================================#
# get_attrib
#----------------------------------------------------------------------------#

=item get_attrib( ):HASHREF

    if ($pkg->get_attrib()->{ISMANDATORY}) {
	print "Package mandatory flag is enabled.\n";
    }
  
    Return a reference to the hash of package attributes.

=cut

#-----------------------------------------------------------------------------#
sub get_attrib {
    #
    # Return reference to attribute hash.
    #
    my $self = shift;
    
    return $self->{_ATTRIB};
}
sub _set_attrib {
    #
    # Set attributes from an input hash reference.
    #
    my $self = shift;
    my $aref = shift;

    unless (ref($aref)) {
	throw_error("Expecting hash reference of attributes");
	return;
    }
    foreach my $flag (keys(%$aref)) {
	my $ucflag = uc($flag);
	unless ($ucflag =~ /ISUNWANTED/ ||
		$ucflag =~ /ISMANDATORY/ ||
		$ucflag =~ /ISLOCAL/ ) {
	    throw_error("Unknown package attribute ($flag)");
	    return;
	}
	$self->get_attrib()->{$ucflag} = $$aref{$flag};
    }
    return SUCCESS;
}
#============================================================================#
# compare_name
#----------------------------------------------------------------------------#

=item compare_name( PACKAGE ):SCALAR

    if ($pkg->compare_name($otherPkg) == 0) {
	print "Package names are identical"; }

    Return -1 0 or 1 if given input PACKAGE name is string-wise less than, 
    equal to or greater than the name attribute of the current Package.

=cut

#-----------------------------------------------------------------------------#
sub compare_name {
    my $self = shift;

    my $otherPkg = shift;

    if (! defined $otherPkg) {
	throw_error("compare_name method requires an argument");
	return;
    }

    if ($otherPkg->isa("SPM::Package")) {
	return $otherPkg->get_name() cmp $self->get_name();
    } else {
	throw_error("compare_name method requires an argument of type SPM::Package");
	return;
    }
}
#============================================================================#
# is_equal
#----------------------------------------------------------------------------#

=item is_equal(PACKAGE):BOOL

    if ($pkg->is_equal($otherPkg)) {
	print "Packages are identical"; }

    Return 1 if given input PACKAGE release, version and architecture 
    attributes are string-wise the same as those of the current Package.
    Otherwise zero.

=cut

#-----------------------------------------------------------------------------#
sub is_equal {
    my $self = shift;
    my $otherPkg = shift;

    if (! defined $otherPkg || ! $otherPkg->isa("SPM::Package") ) {
	throw_error("is_equal method requires an argument Package");
	return;
    }

    if ($self->compare_name($otherPkg) == 0) {

	return ($self->_cmp($otherPkg->get_version(),$self->get_version()) &&
	        $self->_cmp($otherPkg->get_release(),$self->get_release()) &&
	        $self->_cmp($otherPkg->get_arch(),$self->get_arch()));
    } else {
	throw_error("is_equal called when Package names differ");
	return;
    }    
}
#============================================================================#
# print
#----------------------------------------------------------------------------#

=item print():SCALAR

    $text = $pkg->print();
 
    Return a string which represents the package from which a package
    can be constructed using the new(TEXT) constructor.

=cut 

#-----------------------------------------------------------------------------#
sub print {
    my $self = shift;
    my $out;

    if ($self->get_URL()) {
	$out = $self->get_URL();
    } else {
	$out = "";
    }

    return (join(" ",$out,$self->get_name(),$self->get_version(),
		 $self->get_release(),$self->get_arch(),$self->_print_attrib())
	    );
} 
#============================================================================#
# _base_init - private
#----------------------------------------------------------------------------#
sub _base_init {
    my $self = shift;
		
    # Data

    $self->{_URL}              = undef;
    $self->{_NAME}             = undef;
    $self->{_VERSION}          = undef;
    $self->{_RELEASE}          = undef;
    $self->{_ARCH}             = undef;

    # Attrib - bring to a known state


    $self->{_ATTRIB} = {
			 "ISMANDATORY" => undef,  #   - must be installed
			 "ISLOCAL"     => undef,  #   - locally administered
			 "ISUNWANTED"  => undef,  #   - must be deleted
			 
			 # Packager instructions
			 
			 #"NODEPS"      => undef,  #   - ignore dependancies
			 #"NOSCRIPTS"   => undef,  #   - ignore scripts
			 #"NOTRIGGERS"  => undef,  #   - ignore triggers

			 # Machine states

			 #"OFFPROD"    => undef,  #   - only process if off production
			 #"REBOOT"     => undef   #   - requires reboot after processing
			 };
    return SUCCESS;
}
#============================================================================#
# _init_from_args - private
#----------------------------------------------------------------------------#

sub _init_from_args {
    
    # Name version release architecture and attrib are all mandatory

    my $self = shift;
    my $errtxt1 = " missing from Package construction argument list";
    
    $self->_set_URL(shift);
    $self->_set_name(shift)    || (throw_error("NAME $errtxt1"),return);
    $self->_set_version(shift) || (throw_error("VERSION $errtxt1"),return);
    $self->_set_release(shift) || (throw_error("RELEASE $errtxt1"),return);
    $self->_set_arch(shift)    || (throw_error("ARCHITECTURE $errtxt1"),return);
    $a=shift;
    if (defined $a) { # can be undef
      $self->_set_attrib(shift)  || # Load the attrib
	(throw_error("Missing or invalid attrib encountered in Package ".
		     "construction argument list"),return);
    }

    return SUCCESS if $self->_is_valid();
}
#============================================================================#
# _init_from_text
#----------------------------------------------------------------------------#
sub _init_from_text {

    # Load Package from something like - 
    #
    #  http:/blah/fo,myname 1.2 3.4 noarch islocal ismandatory
    #
    #  This is absolute minimum valid input -
    #
    #  - myname 1.2 3.4 noarch
    #
    my $self = shift;
    my $pData = shift;

    if (! $pData ) {
	throw_error("Missing values for package loading");
	return (undef);
    } else {
	# Fill me up..

	my @pData = split(/ +/,$pData);

	if (scalar(@pData) >= 5) {

	    $self->_set_URL(shift(@pData));
	    $self->_set_name(shift(@pData));
	    $self->_set_version(shift(@pData));
	    $self->_set_release(shift(@pData));
	    $self->_set_arch(shift(@pData));

	    my %attribs;

	    while (@pData) {
		$attribs{uc(shift(@pData))} = 1;
	    }
	    $self->_set_attrib(\%attribs);

	} else {
	    throw_error("Invalid package specification found: ".$pData);
	    return (undef);
	}
    }
    return SUCCESS if $self->_is_valid();
}
#============================================================================#
# _is_valid - private
#----------------------------------------------------------------------------#
sub _is_valid {
    #
    # Check some basic things about a package make sense. If these are not
    # true some assumptions outside may not be valid.
    #
    my $self = shift;

    # Check that the wildcard is very simple and only in the version and
    # release

    my $prefix = "Package load error: (".$self->print().") ";
    my $err = 0;
    my $is_wild = 0;

    if ($self->get_URL() && $self->_is_wild_text($self->get_URL())) {
	$self->error($prefix."Wildcard is not valid in the URL");
	$err = 1;
    }
    if ($self->_is_wild_text($self->get_name())) {
	$self->error($prefix."Wildcard is not valid in the name.");
	$err = 1;
    }
#    if ($self->_is_wild_text($self->get_arch())) {
#	$self->error($prefix."Wildcard is not valid in the architecture.");
#	$err = 1;
#    }
    if ($self->_is_wild_text($self->get_version())) {
	unless (length($self->get_version()) == 1) {
	    $self->error($prefix."Only simple wildcard '*' is allowed.");
	    $err = 1;
	}
	unless ($self->_is_wild_text($self->get_release())) {
	    $self->error($prefix."Release cannot be specified with wildcard version.");
	    $err = 1;
	}
	$is_wild = 1;
    } elsif ($self->_is_wild_text($self->get_release())) {
	unless (length($self->get_release()) == 1) {
	    $self->error($prefix."Only simple wildcard '*' is allowed.");
	    $err = 1;
	}
	$is_wild = 1;
    }

    return 0 if $err;

    if ($is_wild) {
	unless ($self->get_attrib()->{ISUNWANTED}) {
	    $self->log($prefix."Wildcards can only be used with ISUNWANTED attribute.");
	    $err = 1;
	}
    }

    return ($err == 0);
}
sub _is_wild_text {
    my $self = shift;
    my $text = shift;

    return ( index($text,"*") >= 0 );
}
#============================================================================#
# _print_attrib - private
#----------------------------------------------------------------------------#
sub _print_attrib {
    #
    # Store attributes in a string
    # Currently only attributes with non-zero values are saved
    #
    my $self = shift;
    my $attribref = $self->get_attrib();
    my $out = '';

    foreach my $attrib ( keys( %$attribref ) ) {
	
	if ( $attribref->{$attrib} ) {
	    $out = join(' ',$out,uc($attrib));
	}
    }
    return $out;
}
#============================================================================#
# _cmp - private
#----------------------------------------------------------------------------#
sub _cmp {
    #
    # Compare two strings honouring most primitive wildcard 
    # of single "*"
    #
    my $self = shift;
    my ($str1, $str2) = @_;

    if ($str1 eq "*" || $str2 eq "*") {
	return 1;
    } elsif ($str1 eq $str2) {
	return 1;
    }
    return 0;
}
#+############################################################################
1;

=back

=head1 AUTHORS

Ian Neilson, modifications by German Cancio

=head1 VERSION

$Id: Package.pm.cin,v 1.4 2006/07/19 06:45:32 gcancio Exp $

=cut
