{
  pkgs,
  craneLib,
  upstreamRoot,
  spacebotRoot,
  frontendSrc,
  daemonRustSrc,
  desktopRustSrc,
  cliRustSrc,
}:
let
  inherit (pkgs) lib stdenv;
  targetTriple = stdenv.hostPlatform.config;
  pdfiumVersion = "6666";
  archiveToolPackages = with pkgs; [
    unzip
    gnutar
    gzip
    bzip2
    xz
    p7zip
  ];
  daemonRuntimePath = lib.makeBinPath ([ pkgs.ffmpeg_7.bin ] ++ archiveToolPackages);
  gstreamerPackages = with pkgs.gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ];
  gstreamerPluginPath = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstreamerPackages;

  tauriCargoToml = builtins.fromTOML (
    builtins.readFile "${upstreamRoot}/apps/tauri/src-tauri/Cargo.toml"
  );
  version = tauriCargoToml.package.version;

  pdfiumUrl =
    if stdenv.hostPlatform.isx86_64 then
      "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F${pdfiumVersion}/pdfium-linux-x64.tgz"
    else if stdenv.hostPlatform.isAarch64 then
      "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F${pdfiumVersion}/pdfium-linux-arm64.tgz"
    else
      throw "Unsupported platform for pdfium: ${stdenv.hostPlatform.system}";

  pdfiumHash =
    if stdenv.hostPlatform.isx86_64 then
      "sha256-stUhbZ1ZfqxqpV1eFTEMd+F0xXVP2YE3sqPh6J7yd7I="
    else if stdenv.hostPlatform.isAarch64 then
      "sha256-cydMLWhrN5C6WxUw6HLpl/51S05QBG/+SudvO/6MNZM="
    else
      throw "Unsupported platform for pdfium: ${stdenv.hostPlatform.system}";

  pdfium = stdenv.mkDerivation {
    pname = "pdfium";
    version = pdfiumVersion;
    src = pkgs.fetchurl {
      url = pdfiumUrl;
      hash = pdfiumHash;
    };

    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib $out/include
      cp lib/libpdfium.so $out/lib/
      cp -r include/. $out/include/
      runHook postInstall
    '';
  };

  bunNix = pkgs.runCommandLocal "spacedrive-bun.nix" { } ''
    substitute ${./bun.nix} $out --replace-fail __ROOT__ ${frontendSrc}
  '';

  frontend = stdenv.mkDerivation {
    pname = "spacedrive-frontend";
    inherit version;
    src = frontendSrc;

    nativeBuildInputs = [ pkgs.bun2nix.hook ];
    bunDeps = pkgs.bun2nix.fetchBunDeps {
      bunNix = bunNix;
    };
    dontRunLifecycleScripts = true;

    dontConfigure = true;

    postPatch = ''
      cp ${../bun.lock} bun.lock
      ln -s ${spacebotRoot} ../spacebot

      substituteInPlace apps/tauri/src/contextMenu.ts \
        --replace-fail \
          "import { Menu, MenuItem, Submenu, PredefinedMenuItem } from '@tauri-apps/api/menu';" \
          "import { LogicalPosition } from '@tauri-apps/api/dpi'; import { Menu, MenuItem, Submenu, PredefinedMenuItem } from '@tauri-apps/api/menu';" \
        --replace-fail \
          'await menu.popup();' \
          'await menu.popup(new LogicalPosition(position.x, position.y));'

      # The sidebar is z-[65]. Radix portals default to z-50, which puts the
      # space switcher menu behind the translucent sidebar stacking context.
      # Radix copies the content z-index to its popper wrapper, so raising the
      # content also fixes the compositor order of the wrapper.
      substituteInPlace packages/interface/src/components/SpacesSidebar/SpaceSwitcher.tsx \
        --replace-fail \
          'className="min-w-[var(--radix-dropdown-menu-trigger-width)] p-1"' \
          'className="z-[100] min-w-[var(--radix-dropdown-menu-trigger-width)] p-1"'

      # The published primitives package uses these classes for its dialog
      # overlay and content, but Tailwind does not scan the package through its
      # node_modules symlink. Define the missing utilities explicitly.
      substituteInPlace apps/tauri/src/index.css \
        --replace-fail \
          '@source "../../../../spaceui/packages/primitives/src";' \
          '@source "../../../../spaceui/packages/primitives/src";

/* Utilities referenced by @spacedrive/primitives but absent from this build. */
.z-\[102\] { z-index: 102; }
.z-\[103\] { z-index: 103; }'

    '';

    buildPhase = ''
      runHook preBuild
      bun run --filter @sd/tauri build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r apps/tauri/dist/. $out/
      runHook postInstall
    '';
  };

  commonNativeBuildInputs = with pkgs; [
    cmake
    pkg-config
    protobuf
  ];

  commonBuildInputs = with pkgs; [
    openssl
  ];

  daemonBuildInputs = commonBuildInputs ++ [
    pkgs.ffmpeg_7
  ];

  daemonNativeBuildInputs = commonNativeBuildInputs ++ [
    pkgs.clang
    pkgs.llvmPackages.libclang
  ];

  desktopBuildInputs = commonBuildInputs ++ [
    pkgs.dbus
    pkgs.glib
    pkgs.glib-networking
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-libav
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-ugly
    pkgs.gtk3
    pkgs.libayatana-appindicator
    pkgs.libsoup_3
    pkgs.webkitgtk_4_1
  ];

  commonArgs = {
    inherit version;
    strictDeps = true;
    doCheck = false;
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "256";
    CARGO_PROFILE_RELEASE_LTO = "off";
    nativeBuildInputs = commonNativeBuildInputs;
    buildInputs = commonBuildInputs;
  };

  rust197PostPatch = ''
    substituteInPlace crates/task-system/src/system.rs \
      --replace-fail '.fetch_update(' '.try_update('
  '';

  daemonCargoArtifacts = craneLib.buildDepsOnly (
    commonArgs
    // {
      pname = "spacedrive-cargo-artifacts";
      src = daemonRustSrc;
      cargoExtraArgs = "--package sd-core --bin sd-daemon --features ffmpeg";
      buildInputs = daemonBuildInputs;
      nativeBuildInputs = daemonNativeBuildInputs;
      LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
      BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.ffmpeg_7.dev}/include";
      FFMPEG_DIR = "${pkgs.ffmpeg_7.dev}";
    }
  );

  cliCargoArtifacts = craneLib.buildDepsOnly (
    commonArgs
    // {
      pname = "sd-cli-cargo-artifacts";
      src = cliRustSrc;
      cargoExtraArgs = "--package sd-cli --bin sd-cli";
    }
  );

  desktopCargoArtifacts = craneLib.buildDepsOnly (
    commonArgs
    // {
      pname = "spacedrive-desktop-cargo-artifacts";
      src = desktopRustSrc;
      cargoExtraArgs = "--package spacedrive --bin Spacedrive";
      buildInputs = desktopBuildInputs;
    }
  );

  sd-daemon = craneLib.buildPackage (
    commonArgs
    // {
      pname = "sd-daemon";
      src = daemonRustSrc;
      cargoArtifacts = daemonCargoArtifacts;
      cargoExtraArgs = "--package sd-core --bin sd-daemon --features ffmpeg";
      postPatch = rust197PostPatch + ''
        substituteInPlace core/src/volume/platform/linux.rs \
          --replace-fail \
            '.args(["-h", "-T"]) // -T shows filesystem type' \
            '.args(["-B1", "-T"]) // Exact bytes; unlike -h, this is locale-independent'

        substituteInPlace core/src/volume/utils.rs \
          --replace-fail '"/" | "/usr"' '"/usr"' \
          --replace-fail \
            'assert!(should_hide_by_mount_path(Path::new("/")));' \
            'assert!(!should_hide_by_mount_path(Path::new("/")));'
      '';
      buildInputs = daemonBuildInputs;
      nativeBuildInputs = daemonNativeBuildInputs ++ [ pkgs.makeWrapper ];
      LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
      BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.ffmpeg_7.dev}/include";
      FFMPEG_DIR = "${pkgs.ffmpeg_7.dev}";
      postFixup = ''
        wrapProgram $out/bin/sd-daemon \
          --prefix PATH : ${daemonRuntimePath} \
          --set PDFIUM_LIB_PATH ${pdfium}/lib/libpdfium.so
      '';
    }
  );

  sd-cli = craneLib.buildPackage (
    commonArgs
    // {
      pname = "sd-cli";
      src = cliRustSrc;
      cargoArtifacts = cliCargoArtifacts;
      cargoExtraArgs = "--package sd-cli --bin sd-cli";
      postPatch = rust197PostPatch;
    }
  );

  desktopItem = pkgs.makeDesktopItem {
    name = "spacedrive";
    desktopName = "Spacedrive";
    exec = "spacedrive";
    icon = "spacedrive";
    categories = [
      "FileManager"
      "Utility"
    ];
    terminal = false;
  };

  spacedrive-desktop = craneLib.buildPackage (
    commonArgs
    // {
      pname = "spacedrive-desktop";
      src = desktopRustSrc;
      cargoArtifacts = desktopCargoArtifacts;
      cargoExtraArgs = "--package spacedrive --bin Spacedrive";
      patches = [
        ../graceful-global-shortcut.patch
      ];
      postPatch = rust197PostPatch + ''
        substituteInPlace apps/tauri/src-tauri/src/main.rs \
          --replace-fail 'for i in 0..30 {' 'for i in 0..300 {' \
          --replace-fail 'connection not available after 3 seconds' 'connection not available after 30 seconds'

        substituteInPlace apps/tauri/src-tauri/tauri.conf.json \
          --replace-fail '"decorations": true' '"decorations": false'

        substituteInPlace apps/tauri/src-tauri/src/windows.rs \
          --replace-fail 'true,  // decorations' 'false, // decorations'

        substituteInPlace apps/tauri/src-tauri/src/main.rs \
          --replace-fail \
            '// Explicitly remove menu on Windows' \
            '// Explicitly remove the native menu bar on Windows and Linux'
        sed -i '/Explicitly remove the native menu bar/{
          n
          s/#\[cfg(target_os = "windows")\]/#[cfg(any(target_os = "windows", target_os = "linux"))]/
        }' apps/tauri/src-tauri/src/main.rs
        grep -Fq '#[cfg(any(target_os = "windows", target_os = "linux"))]' \
          apps/tauri/src-tauri/src/main.rs
      '';

      nativeBuildInputs = commonNativeBuildInputs ++ [
        pkgs.wrapGAppsHook4
      ];

      buildInputs = desktopBuildInputs;

      preBuild = ''
        mkdir -p apps/tauri/dist
        cp -r ${frontend}/. apps/tauri/dist/

        mkdir -p target/release
        cp ${sd-daemon}/bin/sd-daemon target/release/sd-daemon
        cp ${sd-daemon}/bin/sd-daemon target/release/sd-daemon-${targetTriple}
        chmod +x target/release/sd-daemon target/release/sd-daemon-${targetTriple}
      '';

      postInstall = ''
        mkdir -p $out/bin $out/share/icons/hicolor/128x128/apps
        ln -s ${sd-daemon}/bin/sd-daemon $out/bin/sd-daemon
        ln -s ${sd-daemon}/bin/sd-daemon $out/bin/sd-daemon-${targetTriple}
        cp apps/tauri/src-tauri/icons/128x128.png $out/share/icons/hicolor/128x128/apps/spacedrive.png
      '';

      postFixup = ''
        wrapProgram $out/bin/Spacedrive \
          --set GST_PLUGIN_SYSTEM_PATH_1_0 ${gstreamerPluginPath} \
          --set WEBKIT_DMABUF_RENDERER_FORCE_SHM 1 \
          --set WEBKIT_FORCE_COMPOSITING_MODE 1
      '';

      meta = with lib; {
        description = "Spacedrive desktop application";
        homepage = "https://github.com/spacedriveapp/spacedrive";
        license = licenses.agpl3Only;
        mainProgram = "Spacedrive";
        platforms = platforms.linux;
      };
    }
  );

  spacedrive = pkgs.symlinkJoin {
    name = "spacedrive";
    paths = [
      spacedrive-desktop
      sd-daemon
      desktopItem
    ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      ln -s Spacedrive $out/bin/spacedrive
    '';
    meta = spacedrive-desktop.meta // {
      mainProgram = "spacedrive";
    };
  };

  ui-test = pkgs.rustPlatform.buildRustPackage {
    pname = "ui-test";
    version = "0.1.0";
    src = ../tools/ui-test;
    cargoLock.lockFile = ../tools/ui-test/Cargo.lock;

    meta = with lib; {
      description = "Spacedrive UI test scaffold and scenario runner";
      homepage = "https://github.com/spacedriveapp/spacedrive";
      license = licenses.agpl3Only;
      mainProgram = "ui-test";
      platforms = platforms.linux;
    };
  };

  test-ui-full = pkgs.writeShellApplication {
    name = "test-ui-full";
    runtimeInputs = with pkgs; [
      chromium
      chromedriver
      curl
      jq
      python3
      python3Packages.selenium
    ];
    text = ''
      export TEST_UI_FULL_PY=${../tools/ui-test/test_ui_full.py}
      export CHROME_BIN=${pkgs.chromium}/bin/chromium
      export CHROMEDRIVER_BIN=${pkgs.chromedriver}/bin/chromedriver
      exec ${pkgs.bash}/bin/bash ${../tools/ui-test/test-ui-full.sh} "$@"
    '';
  };
in
{
  inherit
    frontend
    sd-cli
    sd-daemon
    spacedrive-desktop
    spacedrive
    ;
}
