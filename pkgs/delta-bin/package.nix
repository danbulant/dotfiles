{
  alsa-lib,
  autoPatchelfHook,
  dbus,
  fontconfig,
  glib,
  lib,
  libGL,
  libsecret,
  makeWrapper,
  openssl,
  requireFile,
  stdenv,
  vulkan-loader,
  wayland,
  xkeyboard_config,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "delta-bin";
  version = "0.6.1";

  src = requireFile {
    name = "delta-linux-x86_64.tar.gz";
    url = "https://delta.dev/download";
    hash = "sha256-Q/CSFKlIDd47DwQk/QatfBs8AtM/ObTA3TFOTvggcsE=";
    message = ''
      Delta is beta-gated and cannot be downloaded without a Zed account.
      Download the Linux x86_64 archive from https://delta.dev/download, then run:

        nix-store --add-fixed sha256 delta-linux-x86_64.tar.gz
    '';
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  runtimeDependencies = [
    alsa-lib
    dbus
    fontconfig
    glib
    libGL
    libsecret
    openssl
    vulkan-loader
    wayland
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -a ./. $out/
    rm $out/install.sh

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/delta \
      --set-default XKB_CONFIG_ROOT "${xkeyboard_config}/share/X11/xkb"
  '';

  meta = {
    description = "Collaborative agent workspace from the creators of Zed";
    homepage = "https://delta.dev/";
    license = lib.licenses.unfree;
    mainProgram = "delta";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
