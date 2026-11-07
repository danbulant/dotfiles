{ lib, stdenvNoCC, fetchFromGitHub, fetchurl, python313, makeWrapper, makeDesktopItem, copyDesktopItems, qt6, chromium }:
let
  python = python313.withPackages (ps: with ps; [
    setuptools numpy cycler python-dateutil kiwisolver six dill simplejson qrcode
    rtree shapely ortools lxml svg-path svglib fonttools ezdxf reportlab pyserial
    matplotlib pyopengl pyqt6 freetype-py vispy darkdetect gdal rasterio tkinter
    (buildPythonPackage {
      pname = "svgtrace";
      version = "2023";
      format = "wheel";
      src = fetchurl {
        url = "https://files.pythonhosted.org/packages/63/33/adf80cfad336c35adab3f074282fe67c58179203bab4482fb36e53cb38e1/svgtrace-2023-py3-none-any.whl";
        hash = "sha256-epM+mX59td9/aPAoAzyU8e/bHpskRapClb4MmhQcpa0=";
      };
      dependencies = [ playwright pillow ];
      # Nix supplies Chromium; never download browsers into the user's profile.
      pythonRemoveDeps = [ "install-playwright" ];
      postInstall = ''
        substituteInPlace $out/${python313.sitePackages}/svgtrace/__init__.py \
          --replace-fail 'from install_playwright import install' "" \
          --replace-fail 'install(p.chromium)' "pass" \
          --replace-fail 'browser = p.chromium.launch(' 'browser = p.chromium.launch(executable_path="${chromium}/bin/chromium",'
      '';
      pythonImportsCheck = [ "svgtrace" ];
    })
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "flatcam";
  version = "8.995-unstable-b6e87db";
  src = fetchFromGitHub {
    owner = "dwrobel";
    repo = "flatcam";
    rev = "b6e87dbf1e20819f136ac5ecaa4ebebfb69e89c2";
    hash = "sha256-RaQYw3EVUEWVRGL7Pwhe5cSSU6WoBosiS0CeVim1Wfs=";
  };
  # The pinned refactor retained a second startup pass, duplicating signals and scripts.
  # Keep signal wiring in _setup_signal_connections and execute --shellfile only once.
  patches = [
    ./fix-duplicate-startup.patch
    # GUI isolation returns nested pass lists; flatten them without losing polygon holes.
    ./fix-nested-geometry.patch
    # Reset only numeric parsing after Qt adopts the user's locale, before workers start.
    ./fix-numeric-locale.patch
  ];
  postPatch = ''
    substituteInPlace appPlugins/ToolImage.py \
      --replace-fail 'from pyppeteer.chromium_downloader import check_chromium' \
        'from pathlib import Path; check_chromium = lambda: Path("${chromium}/bin/chromium").is_file()'
  '';
  nativeBuildInputs = [ makeWrapper copyDesktopItems qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtwayland ];
  dontBuild = true;
  dontWrapQtApps = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    PYTHONPATH="$PWD" ${python}/bin/python ${./test-geometry.py}
    runHook postCheck
  '';
  desktopItems = [ (makeDesktopItem {
    name = "flatcam";
    desktopName = "FlatCAM Evo";
    comment = "PCB isolation routing and CNC toolpath generation";
    exec = "flatcam";
    categories = [ "Development" "Engineering" ];
  }) ];
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/flatcam $out/bin
    cp -r . $out/share/flatcam/
    makeWrapper ${python}/bin/python $out/bin/flatcam \
      --add-flags "$out/share/flatcam/flatcam.py" \
      "''${qtWrapperArgs[@]}"
    runHook postInstall
  '';
  meta = {
    description = "PCB CAM tool for generating CNC toolpaths";
    homepage = "https://github.com/dwrobel/flatcam";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "flatcam";
  };
}
