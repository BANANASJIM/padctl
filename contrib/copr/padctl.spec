Name:           padctl
Version:        0.1.0
Release:        1%{?dist}
Summary:        HID gamepad remapper with declarative TOML config

License:        MIT
URL:            https://github.com/BANANASJIM/padctl

%global _arch_tag %{expand:%(uname -m)}-linux-musl
Source0:        %{url}/releases/download/v%{version}/padctl-v%{version}-%{_arch_tag}.tar.gz

BuildArch:      x86_64 aarch64
# Prebuilt binary — no Zig toolchain needed
BuildRequires:  coreutils
AutoReqProv:    no

%description
padctl is a HID gamepad compatibility daemon.  It reads declarative
TOML profiles and re-maps gamepad input via uinput, with per-device
systemd socket activation and udev integration.

%prep
%setup -q -n padctl-v%{version}-%{_arch_tag}

%install
install -Dm755 bin/padctl          %{buildroot}%{_bindir}/padctl

install -Dm644 install/padctl.service \
    %{buildroot}%{_unitdir}/padctl.service

install -Dm644 install/99-padctl.rules \
    %{buildroot}%{_udevrulesdir}/99-padctl.rules

find devices -name '*.toml' | while read -r toml; do
    install -Dm644 "${toml}" "%{buildroot}%{_datadir}/padctl/${toml}"
done

install -Dm644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE

%files
%license LICENSE
%{_bindir}/padctl
%{_unitdir}/padctl.service
%{_udevrulesdir}/99-padctl.rules
%{_datadir}/padctl/

%post
%systemd_post padctl.service

%preun
%systemd_preun padctl.service

%postun
%systemd_postun_with_restart padctl.service

%changelog
* Thu Mar 20 2026 padctl maintainers <maintainers@padctl.dev> - 0.1.0-1
- Initial COPR package (prebuilt binary)
