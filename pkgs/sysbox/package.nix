{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  rsync,
  fuse,
  kmod,
}:

stdenv.mkDerivation rec {
  pname = "sysbox";
  version = "0.6.7";

  src = fetchurl {
    url = "https://github.com/nestybox/sysbox/releases/download/v${version}/sysbox-ce_${version}.linux_${
      {
        x86_64-linux = "amd64";
        aarch64-linux = "arm64";
      }
      .${stdenv.hostPlatform.system}
    }.deb";
    hash =
      {
        x86_64-linux = "sha256-t6w4nloZWSyt8W4Mow5AkZUWEo9uG3+Z4ctP9kVUFy4=";
        aarch64-linux = "sha256-FugBvWoeqk/5bO0hXCvJjvbM7qk1W0qOt6TYOSwj5JE=";
      }
      .${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  };

  nativeBuildInputs = [ dpkg ];

  buildInputs = [
    rsync
    fuse
    kmod
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r usr/* $out/
    cp -r lib $out/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Next-generation runc that empowers rootless containers to run workloads such as Systemd, Docker, and Kubernetes";
    homepage = "https://github.com/nestybox/sysbox";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "sysbox-runc";
  };
}
