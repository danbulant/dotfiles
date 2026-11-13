{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  glib-networking,
  openssl,
  fontconfig,
  bzip2,
  gst_all_1,
  desktop-file-utils,
  xdg-utils,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "deadlock-mod-manager";
  version = "2.3.0";

  src = fetchurl {
    url = "https://github.com/deadlock-mod-manager/deadlock-mod-manager/releases/download/v${finalAttrs.version}/Deadlock.Mod.Manager_${finalAttrs.version}_amd64.deb";
    hash = "sha256-LP5Apu9X67MGp450WNrWx9ICHOd1NjH42JhehpFZH5Q=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook wrapGAppsHook3 ];
  buildInputs = [
    gtk3
    webkitgtk_4_1
    glib-networking
    openssl
    fontconfig
    bzip2
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r usr/bin usr/share "$out/"
    runHook postInstall
  '';

  preFixup = ''
    # Avoid CEF's >2 GiB mallinfo() crash and NVIDIA WebKit rendering failures.
    gappsWrapperArgs+=(
      --set GDK_BACKEND x11
      --set WEBKIT_DISABLE_DMABUF_RENDERER 1
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1
      --set FONTCONFIG_FILE "${fontconfig.out}/etc/fonts/fonts.conf"
      --prefix PATH : "${lib.makeBinPath [ desktop-file-utils xdg-utils ]}"
      --add-flags "--disable-auto-update"
    )
  '';

  meta = {
    description = "Mod manager for the Valve game Deadlock";
    homepage = "https://deadlockmods.app";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "deadlock-mod-manager";
  };
})
