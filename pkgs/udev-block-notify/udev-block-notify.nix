{
  stdenv,
  fetchFromGitHub,
  multimarkdown,
  coreutils,
  libnotify,
  libudev-zero,
  systemdLibs,
  glib,
  pkg-config
}:
stdenv.mkDerivation {
  pname = "udev-block-notify";
  version = "0.7.11";

  src = fetchFromGitHub {
    owner = "eworm-de";
    repo = "udev-block-notify";
    rev = "e652f54edd9ea87c784d796435967a18189d1936";
    sha256 = "sha256-A0uhfb2mEAAJgxRkv+MWTk/9oFiz3r7deAlu1Kpk+CI=";
  };

  nativeBuildInputs = [ multimarkdown coreutils pkg-config ];
  buildInputs = [ libnotify libudev-zero systemdLibs glib ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/doc/udev-block-notify/screenshots
    mkdir -p $out/lib/systemd/user
    install -D -m0755 udev-block-notify $out/bin/udev-block-notify
    install -D -m0644 systemd/udev-block-notify.service $out/lib/systemd/user/udev-block-notify.service

    install -D -m0644 README.md $out/share/doc/udev-block-notify/README.md
    install -D -m0644 README.html $out/share/doc/udev-block-notify/README.html
    install -D -m0644 screenshots/usb.png $out/share/doc/udev-block-notify/screenshots/usb.png
    install -D -m0644 screenshots/optical.png $out/share/doc/udev-block-notify/screenshots/optical.png
  '';
}