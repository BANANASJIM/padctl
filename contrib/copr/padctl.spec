# Version: update this field when cutting a new COPR release (not overwritten by release.yml).
Name:           padctl
Version:        0.1.16
Release:        1%{?dist}
Summary:        HID gamepad remapper with declarative TOML config

License:        LGPL-2.1-or-later
URL:            https://github.com/BANANASJIM/padctl

# TODO: update once release tarballs exist at the URL below.
%ifarch x86_64
%global _arch_tag x86_64-linux-musl
%endif
%ifarch aarch64
%global _arch_tag aarch64-linux-musl
%endif
Source0:        %{url}/releases/download/v%{version}/padctl-v%{version}-%{_arch_tag}.tar.gz

ExclusiveArch:  x86_64 aarch64
# Prebuilt musl static binary — no Zig toolchain needed.
BuildRequires:  coreutils
BuildRequires:  systemd-rpm-macros
Requires:       systemd
Requires:       bash
Requires:       util-linux
Requires:       coreutils
AutoReqProv:    no

%description
padctl is a HID gamepad compatibility daemon.  It reads declarative
TOML profiles and re-maps gamepad input via uinput, with per-device
systemd socket activation and udev integration.

%prep
%setup -q -n padctl-v%{version}-%{_arch_tag}

%install
# Run padctl's own installer to generate all files (service, udev rules, scripts).
./bin/padctl install --destdir %{buildroot} --prefix /usr

%files
%license LICENSE
%{_bindir}/padctl
%{_bindir}/padctl-capture
%{_bindir}/padctl-debug
%{_bindir}/padctl-reconnect
%{_userunitdir}/padctl.service
%{_udevrulesdir}/60-padctl.rules
%{_udevrulesdir}/61-padctl-driver-block.rules
%{_udevrulesdir}/90-padctl.rules
%{_modulesloaddir}/padctl.conf
%{_datadir}/padctl/

%post
%systemd_user_post padctl.service
# modules-load.d only loads at next boot; load now so the daemon works first run.
modprobe uhid uinput || true

%preun
%systemd_user_preun padctl.service

%postun
%systemd_user_postun_with_restart padctl.service

%changelog
* Mon Jun 16 2026 padctl maintainers <maintainers@padctl.dev> - 0.1.16-1
- Bump to 0.1.16
- Fix %%files: padctl install writes the user unit to %%{_userunitdir}, not %%{_unitdir}
- Use systemd user-scope scriptlet macros to match the user unit
- modprobe uhid uinput in %%post so the daemon works before the next boot

* Fri Apr 04 2026 padctl maintainers <maintainers@padctl.dev> - 0.1.0-1
- Fix ExclusiveArch (was incorrectly BuildArch)
- Update udev rules: 99-padctl.rules -> 60-padctl.rules + 61-padctl-driver-block.rules
- Add padctl-debug, padctl-capture, padctl-reconnect to %files
- Drop padctl-resume.service (removed in issue #131 Problem B fix)
- Use padctl install to generate all files instead of manual installs
- Add Requires: systemd

* Thu Mar 20 2026 padctl maintainers <maintainers@padctl.dev> - 0.1.0-0
- Initial COPR package (prebuilt binary)
