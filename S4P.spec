%define pkgname S4P
%define filelist %{pkgname}-%{version}-filelist
%define filelist_ts1 %{pkgname}-TS1-%{version}-filelist
%define filelist_ts2 %{pkgname}-TS2-%{version}-filelist
%define maketest 1
%define prefix_ops /tools/gdaac/OPS
%define prefix_ts1 /tools/gdaac/TS1
%define prefix_ts2 /tools/gdaac/TS2

name:      %{pkgname}
summary:   S4P - package of general utilities to support S4P
version:   5.28.5
release:   GESDISC%{?dist}
buildarch: noarch
License: GESDISC_Internal
Group: GESDISC_Internal
prefix:    %{prefix_ops}
source:    %{pkgname}-%{version}.tar.gz
buildroot: %{_tmppath}/%{name}-%{version}-%(id -u -n)

%package TS1
Summary: TS1 mode of S4P - package of general utilities to support S4P
Group: GESDISC_Internal
prefix: %{prefix_ts1}

%package TS2
Summary: TS2 mode of S4P - package of general utilities to support S4P
Group: GESDISC_Internal
prefix: %{prefix_ts2}

%description
S4P - package of general utilities to support S4P

%description TS1
S4P - package of general utilities to support S4P, TS1 mode

%description TS2
S4P - package of general utilities to support S4P, TS2 mode

%prep
%setup -q -n %{pkgname}-%{version}
chmod -R u+w %{_builddir}/%{pkgname}-%{version}

%build

%install
# create temporary installation directory
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%{__perl} Makefile.PL PREFIX=%{buildroot}%{prefix_ops}
%{__make}
%if %maketest
%{__make} test
%endif
%{makeinstall}

#/usr/lib/rpm/brp-compress

# remove special files
find %{buildroot} -name "perllocal.pod" \
    -o -name ".packlist"                \
    -o -name "*.bs"                     \
    |xargs -i rm -f {}

# no empty directories
find %{buildroot}%{prefix_ops}             \
    -type d -depth                      \
    -exec rmdir {} \; 2>/dev/null


# generate filelist

find %{buildroot}%{prefix_ops} -type f |sed s@%{buildroot}@@ > %filelist

# install TS1
%{__perl} Makefile.PL PREFIX=%{buildroot}%{prefix_ts1}
%{makeinstall}
#/usr/lib/rpm/brp-compress
# remove special files
find %{buildroot} -name "perllocal.pod" \
    -o -name ".packlist"                \
    -o -name "*.bs"                     \
    |xargs -i rm -f {}

# no empty directories
find %{buildroot}%{prefix_ts1}             \
    -type d -depth                      \
    -exec rmdir {} \; 2>/dev/null

# generate filelist
find %{buildroot}%{prefix_ts1} -type f |sed s@%{buildroot}@@ > %filelist_ts1

# install TS2
%{__perl} Makefile.PL PREFIX=%{buildroot}%{prefix_ts2}
%{makeinstall}
#/usr/lib/rpm/brp-compress
# remove special files
find %{buildroot} -name "perllocal.pod" \
    -o -name ".packlist"                \
    -o -name "*.bs"                     \
    |xargs -i rm -f {}

# no empty directories
find %{buildroot}%{prefix_ts2}             \
    -type d -depth                      \
    -exec rmdir {} \; 2>/dev/null

# generate filelist
find %{buildroot}%{prefix_ts2} -type f |sed s@%{buildroot}@@ > %filelist_ts2

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files -f %filelist
%defattr(-,cmadm,cmgrp)

%files TS1 -f %filelist_ts1
%defattr(-,cmadm,cmgrp)

%files TS2 -f %filelist_ts2
%defattr(-,glei,testanddev)

%changelog
* Thu Jun 26 2008 dvgerasi@discette
- Initial build.

