package SPM::SysVPkgr;
#+############################################################################
#
# File: SysVPkgr.pm
#

=head1 NAME

SPM::SysVPkgr - Packager class implementation for SysV Packager

=head1 SYNOPSIS

    use SPM::SysVPkgr;
    ..
    $pkgr = SPM::SysVPkgr->new( );
    ..
    @pkgs = $pkgr->get_installed_list();
    ..
    $status = $pkgr->execute_ops( \@ops );
    ..
    # The following methods are implemented by the Packager base class
    ..
    @ops = $pkgr->get_diff_ops( \@srcpkgs, \@tgtpkgs );
    ..
    @ops = $pkgr->get_all_ops( \@srcpkgs, \@tgtpkgs );
    ..
    $status = $pkgr->execute( \@currentList, \@targetList );


=head1 DESCRIPTION

    This class implements the SPM Packager interface for the PKG
    packager. It uses 'pkgt' to apply operations.

=over

=cut

use strict;
use vars qw(@ISA $VERSION $this_app);

use LC::Exception qw(SUCCESS throw_error);
use LC::File qw(file_contents remove);
use LC::Process ();

use SPM::Packager ();

use SPM::Op qw(OP_INSTALL OP_DELETE OP_REPLACE);

*this_app = \$main::this_app;

$VERSION = 1.10;
@ISA = qw(SPM::Packager);

my $TRANSACTION_COMMAND = '/usr/bin/pkgt';
my $QUERY_COMMAND = 'pkginfo';
my $PKG_DB_DIR = '/var/sadm/pkg';

#============================================================================#
# new
#----------------------------------------------------------------------------#

=item new( )

    $pkgr = SPM::SysVPkgr->new( )

    Initialize an SysV Packager object.

=cut

#-----------------------------------------------------------------------------#
sub _initialize {
    my ($self,$cachepath,$proxytype,$proxyhost,$proxyport,$dbpath,$test) = @_;

    $self->_set_dbpath($dbpath);
    $self->_set_testing($test);

    return $self->SUPER::_initialize($cachepath,$proxytype,$proxyhost,$proxyport);
}
#============================================================================#
# get_installed_list
#----------------------------------------------------------------------------#

=item get_installed_list(  ):LIST

    @pkgs = $pkgr->get_installed_list();
  
    Return a list of all installed packages.

=cut

#-----------------------------------------------------------------------------#
sub get_installed_list {
    my $self = shift;

    my ($qryout, $err);

    my @pkgs;

    my $cmd = $QUERY_COMMAND;


    $self->debug(1,'getting locally installed packages with '.$cmd);

    my $execute_status = LC::Process::execute([ $cmd ],
					      timeout => 600,
					      stdout => \$qryout,
					      stderr => \$err
					      );
    if ($err) {
	throw_error("Failed to run pkginfo to retrieve installed packages (".
		    $err.")");
	return;

    }
      
    foreach my $line (split(/\n/,$qryout)) {
      next if ($line =~ m%^\s*$%);
      my $name;
      $name=(split(/\s+/,$line))[1];
      my $pkginfodir = $PKG_DB_DIR.'/'.$name;
      unless (-d $pkginfodir) {
	$self->warn("Incoherent pkg DB directory: $pkginfodir not found");
	next;
      }
      my $pkginfofile = $pkginfodir.'/pkginfo';
      unless (-e $pkginfofile) {
	$self->warn("Incoherent pkg DB file: $pkginfofile not found");
	next;
      }
      my $pkginfo = file_contents($pkginfofile);
      my $version = '0.0';
      if ($pkginfo =~ m%\bVERSION=(\d.*)%) {
	$version = $1;
	$version =~ s%,.*$%%;
      }
      my $release = '0';
      if ($pkginfo =~ m%\bRELEASE=(\d.*)%) {
	$release = $1;
      }
      my $arch = 'unknown';
      if ($pkginfo =~ m%\bARCH=(.*)\b%) {
	$arch = $1;
      }
      my $pkg = SPM::Package->new(undef,$name,$version,$release,$arch, {});
      if ($pkg) {
	push(@pkgs,$pkg);
      } else {
	return;
      }
    }
    $self->debug(1,scalar(@pkgs).' packages found installed.');    
    return  \@pkgs;
}
#============================================================================#
# execute_ops
#----------------------------------------------------------------------------#

=item execute_ops( OPSLISTREF )

    $status = $pkgr->execute_ops( \@ops );
  
    Apply the given operations.

=cut

sub execute_ops {
    my $self = shift;

    my $ops = shift;

    my ($pkgtout, $err);

    my $pkgtops = "/tmp/spma_ops.".$$;   # File to store pkgt instructions

    unless (ref($ops) eq 'ARRAY') {
	throw_error("Program error. SysV packager execute_ops method called ".
		    "with invalid or missing operations list.");
    }

    unless ($self->_write_ops($ops, $pkgtops)) {
	throw_error("Failed to write instructions for pkgt to $pkgtops.");
	return
    }

    my $cmd = $TRANSACTION_COMMAND;

    $cmd .= " --noaction" if ($self->_get_testing());
    $cmd .= " --verbose" if ($this_app->option('verbose')
			    || $this_app->option('debug'));
    $cmd .= " --debug ". $this_app->option('debug') 
	if ($this_app->option('debug'));

    $self->verbose ("command to be executed: $cmd $pkgtops");
    $self->verbose ("pkgt operations in $pkgtops :\n",
		    file_contents($pkgtops));

    my $execute_status = LC::Process::execute([ "$cmd $pkgtops" ],
					      timeout => 18000,
					      stdout => \$pkgtout,
					      stderr => \$err
					      );
    my $pkgt_status = $?;

    $self->verbose ("pkgt execution finished with return status: ".
		    $pkgt_status);

    remove($pkgtops);

    if ($pkgtout) {
      $self->info("pkgt output produced:");
      $self->report($pkgtout);
    }

    if ($err) {
      $self->warn("pkgt STDERR output produced:");
      $self->warn($err);
    }

    # If we managed to execute the transaction we'll return the command 
    # exit status (should be 0-success, 1-error)

    if ($execute_status) {
        # ($? >> 8), and $? & 127 gives which signal, if any, 
	# the process died from, and $? & 128 
	return $pkgt_status >> 8 ;
    } else {
	# Otherwise we failed to execute command
	return -1;
    }
}
#============================================================================#
# _write_ops - private
#----------------------------------------------------------------------------#
sub _write_ops {
    my $self = shift;

    my $ops = shift;
    my $file = shift;

    my $ops_list = '';

    foreach my $op (@$ops) {
	my $txt = $self->_print_op($op);
	$ops_list = join("\n",$ops_list,$txt);
    }

    return file_contents($file,$ops_list);
}
#============================================================================#
# _print_op - private
#----------------------------------------------------------------------------#
sub _print_op {
    my $self = shift;
    
    my $op = shift;   

    my $str;
    my $code = $op->get_operation();

    my @pkgs = $op->get_packages();

    if ($code eq OP_DELETE) {

	return "-e ".$self->_print_package($pkgs[0]);

    } elsif ($code eq OP_INSTALL) {

	return "-i ".$self->_print_package_cache_path($pkgs[0]);

    } elsif ($code eq OP_REPLACE) {
	my @tgts = $op->get_target_packages();

	return "-u ".$self->_print_package_cache_path($tgts[0]);

    } else {
	throw_error("Packager does not support \"$code\" operation.");
	return;
    }
}

#============================================================================#
# _print_package_filename - private
#----------------------------------------------------------------------------#
sub _print_package_filename {
    my ($self,$pkg)=@_;

    return $self->_print_package($pkg)."-".
      $pkg->get_release().".".$pkg->get_arch.".pkg";
#     return $self->_print_package($pkg)."-".$pkg->get_version()."-".
#       $pkg->get_release().".".$pkg->get_arch.".pkg";
}

#============================================================================#
# _print_package - private
#----------------------------------------------------------------------------#
sub _print_package {
    my $self = shift;
    my $pkg = shift;

    return $pkg->get_name()."-".$pkg->get_version();
#     return $pkg->get_name();
}

#============================================================================#
# _get_dbpath - private
#----------------------------------------------------------------------------#
sub _get_dbpath {
    my $self = shift;
    return $self->{_OPTS}->{DBPATH};
}
sub _set_dbpath {
    my $self = shift;
    $self->{_OPTS}->{DBPATH} = shift;
}
sub _get_testing {
    my $self = shift;
    return $self->{_OPTS}->{TESTING};
}
sub _set_testing {
    my $self = shift;
    $self->{_OPTS}->{TESTING} = shift;
}    
#+#############################################################################
1;

=back

=head1 AUTHOR

Juan Pelegrin

=head1 VERSION

$Id: SysVPkgr.pm.cin,v 1.8 2005/08/10 13:59:59 defert Exp $

=cut









