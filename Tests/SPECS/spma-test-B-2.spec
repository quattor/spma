#
# Test package for the SPMA component agent
#
Name: spma-test-B
Summary: EU DataGrid WP4 Configuration Database
Version: 2
Release: 1
License: BSD License
Vendor: DataGrid
Distribution: DataGrid
Packager: %{packager}
Group: Grid/EDG
Prefix: /tmp/edg/spma
URL: http://cern.ch/hep-proj-grid-fabric-config
BuildRoot: %{_builddir}/%{name}-%{version}-%{release}-root
#Source: %{name}-%{version}.tar.gz
#Docdir: %{prefix}/share/doc

%description
This is the EU DataGrid (http://www.eu-datagrid.org) Fabric Management
Work Package (http://cern.ch/hep-proj-grid-fabric) Configiguration
Database.

#%prep
#echo Execute prep.

#%build
#echo Execute build.

%install
[ -d $RPM_BUILD_ROOT ] && rm -fr $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{prefix}
touch $RPM_BUILD_ROOT%{prefix}/%{name}-%{version}.test

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%{prefix}/%{name}-%{version}.test
