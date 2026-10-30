{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  jdk25,
  addDriverRunpath,
  bash,
  coreutils,
  findutils,
  gnugrep,
  xrdb,
  xdpyinfo,
  libx11,
  libxxf86vm,
  libxrender,
  libxrandr,
  libxcursor,
  libxi,
  libglvnd,
  libdrm,
  libgbm,
}:
let
  # JOGL extracts its JNI libraries from JARs at runtime, outside autoPatchelf's
  # reach. Supply their X11/OpenGL dependencies and the host's graphics driver.
  libraryPath = lib.makeLibraryPath [
    libx11
    libxxf86vm
    libxrender
    libxrandr
    libxcursor
    libxi
    libglvnd
    libdrm
    libgbm
  ] + ":${jdk25}/lib/openjdk/lib:${addDriverRunpath.driverLink}/lib";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ugs-platform";
  version = "2.1.27";

  src = fetchurl {
    url = "https://github.com/winder/Universal-G-Code-Sender/releases/download/v${finalAttrs.version}/ugs-platform-app-${finalAttrs.version}.zip";
    hash = "sha256-9zITW2QLfY1kgpEi3vyRrn1F8YQaJCr+mKpAaJxzrlo=";
  };

  nativeBuildInputs = [ unzip makeWrapper copyDesktopItems ];
  dontBuild = true;

  desktopItems = [
    (makeDesktopItem {
      name = "ugs-platform";
      desktopName = "UGS Platform";
      comment = "CNC G-code sender with an integrated editor and 3D visualizer";
      exec = "ugs-platform";
      categories = [ "Development" "Engineering" ];
      startupWMClass = "Universal Gcode Sender";
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/ugs-platform" "$out/bin"
    cp -r . "$out/share/ugs-platform/"
    chmod +x "$out/share/ugs-platform/bin/ugsplatform"
    patchShebangs "$out/share/ugs-platform/bin/ugsplatform" \
      "$out/share/ugs-platform/platform/lib/nbexec"

    # Platform 2.1.27 contains Java 25 bytecode; PATH may otherwise select a
    # minimal JRE or an older JDK that leaves the NetBeans application empty.
    makeWrapper "$out/share/ugs-platform/bin/ugsplatform" "$out/bin/ugs-platform" \
      --add-flags "--jdkhome ${jdk25}/lib/openjdk" \
      --set _JAVA_AWT_WM_NONREPARENTING 1 \
      --prefix LD_LIBRARY_PATH : "${libraryPath}" \
      --prefix PATH : "${lib.makeBinPath [ bash coreutils findutils gnugrep xrdb xdpyinfo ]}"

    runHook postInstall
  '';

  meta = {
    description = "Universal G-Code Sender Platform with a 3D toolpath visualizer";
    homepage = "https://winder.github.io/ugs_website/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    mainProgram = "ugs-platform";
  };
})
