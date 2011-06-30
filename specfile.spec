#
# spma rpm spec file
#
# $Id: specfile.spec,v 1.29 2007/11/09 14:39:49 gcancio Exp $
#
# Copyright (c) 2002 EU DataGrid.
# For license conditions see http://www.eu-datagrid.org/license.html
#
Summary: @DESCR@
Name: @NAME@
Version: @VERSION@
Release: @RELEASE@
License: http://cern.ch/eu-datagrid/license.html
Vendor: EDG / CERN
Packager: @AUTHOR@
Group: @GROUP@/System
URL: @QTTR_URL@
Source: @TARFILE@
BuildArch: noarch
BuildRoot: /var/tmp/%{name}-build
Obsoletes: edg-spma

Requires: perl-CAF >= 1.4.1
Requires: perl-LC >= 0.20030818
Requires: perl-libwww-perl
Requires: rpmt-py

%description 
The Software Package Management Agent (SPMA)
from the quattor toolsuite (http://cern.ch/quattor)

%prep
%setup

%build
make
 
%install
rm -rf $RPM_BUILD_ROOT
make PREFIX=$RPM_BUILD_ROOT install

#make DESTDIR=$RPM_BUILD_ROOT VERSION=$RPM_PACKAGE_VERSION install

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%attr(755,root,root) @QTTR_BIN@/spma
@QTTR_PERLLIB@/SPM/LocalList.pm
@QTTR_PERLLIB@/SPM/Op.pm
@QTTR_PERLLIB@/SPM/Package.pm
@QTTR_PERLLIB@/SPM/PackageListFile.pm
@QTTR_PERLLIB@/SPM/Packager.pm
@QTTR_PERLLIB@/SPM/Policy.pm
@QTTR_PERLLIB@/SPM/RPMPkgr.pm
@QTTR_PERLLIB@/SPM/SysVPkgr.pm
%config @QTTR_ROTATED@/spma
%doc @QTTR_MAN@/man1/spma.1.gz
%doc @QTTR_MAN@/man3/SPM::LocalList.3pm.gz
%doc @QTTR_MAN@/man3/SPM::Op.3pm.gz
%doc @QTTR_MAN@/man3/SPM::Package.3pm.gz
%doc @QTTR_MAN@/man3/SPM::PackageListFile.3pm.gz
%doc @QTTR_MAN@/man3/SPM::Packager.3pm.gz
%doc @QTTR_MAN@/man3/SPM::Policy.3pm.gz
%doc @QTTR_MAN@/man3/SPM::RPMPkgr.3pm.gz
%doc @QTTR_MAN@/man3/SPM::SysVPkgr.3pm.gz
%dir @QTTR_DOC@/
%doc @QTTR_DOC@/README
%doc @QTTR_DOC@/MAINTAINER
%doc @QTTR_DOC@/ChangeLog
%doc @QTTR_DOC@/spma.conf
%dir @QTTR_VAR@/spma-cache/
%dir @QTTR_LOCKD@/
%config(noreplace) @QTTR_ETC@/spma.conf
%attr(755,root,root) @QTTR_SBIN@/spma_wrapper.sh
%attr(755,root,root) @QTTR_SBIN@/spma_ncm_wrapper.sh

%package -n CERN-CC-spma-notd
Group: @GROUP@/System
Summary: quattor SPMA config wrappers for CERN-CC
Requires: spma
Requires: ncm-ncd
Requires: ncm-spma
Requires: CERN-CC-notd
%description -n CERN-CC-spma-notd
CERN-CC not.d entries for quattor SPMA agent:

%files -n CERN-CC-spma-notd
%defattr(-,root,root)
%config @QTTR_ETC@/not.d/spma
%config @QTTR_ETC@/not.d/spma_ncm







