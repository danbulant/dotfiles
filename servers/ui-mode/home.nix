{
  helium,
  omp,
  delta,
  colmena,
  dms,
  zen-browser,
  pkgs,
  config,
  danksearch,
  nix-monitor,
  codexbar,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  dmsShell = dms.packages.${system}.dms-shell.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      if [[ -f quickshell/Services/PopoutService.qml ]]; then
        patch -p1 < ${../../pkgs/dms-settings-reopen.patch}
      fi
    '';
  });

  activitywatchPackages =
    pkgs.qt6Packages.callPackage "${pkgs.path}/pkgs/applications/office/activitywatch"
      { };
  activitywatchFixed = pkgs.activitywatch.override {
    aw-server-rust = pkgs.aw-server-rust.overrideAttrs (oldAttrs: {
      env = (oldAttrs.env or { }) // {
        AW_WEBUI_DIR = activitywatchPackages.aw-webui.overrideAttrs {
          doCheck = false;
        };
      };
    });
  };

  vesktopWrapped = pkgs.vesktop.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postFixup = (oldAttrs.postFixup or "") + ''
      wrapProgram $out/bin/vesktop \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.pipewire ]}" \
        --add-flags "--ozone-platform=wayland --enable-features=WebRTCPipeWireCapturer,WaylandWindowDecorations"
    '';
  });


  osuAppImageNvidia = pkgs.writeShellScriptBin "osu!" ''
    set -eu

    appimage="''${OSU_APPIMAGE:-$HOME/Downloads/osu.AppImage}"
    if [ ! -f "$appimage" ]; then
      echo "osu! AppImage not found: $appimage" >&2
      exit 1
    fi

    export LD_LIBRARY_PATH="${pkgs.icu}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export __EGL_VENDOR_LIBRARY_FILENAMES="/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json"
    export __GLX_VENDOR_LIBRARY_NAME="nvidia"

    exec ${pkgs.appimage-run}/bin/appimage-run "$appimage" "$@"
  '';

in
{
  imports = [
    ./dotfiles.nix
    omp.homeManagerModules.default
    zen-browser.homeModules.beta
    dms.homeModules.dank-material-shell
    danksearch.homeModules.default
    nix-monitor.homeManagerModules.default
  ];
  home = {
    stateVersion = "25.11";

    packages = with pkgs; [
      art
      darktable
      delta.packages.${system}.delta
      kicad
      protontricks
      waypipe
      cinny
      eden
      gh
      inkscape
      osuAppImageNvidia
      unrar
      wine
      codexbar.packages.${pkgs.system}.default
      codex
      (kdePackages.qt6ct.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [ ../../pkgs/qt6ct-0.11.patch ];
        name = "qt6ct-kde";
      }))
      moonlight-qt
      bubblewrap
      exiftool
      kdePackages.qtstyleplugin-kvantum
      libsForQt5.qt5ct
      libsForQt5.qtstyleplugin-kvantum
      ddcutil
      linux-wallpaperengine
      nixd
      buck2
      voxtype-vulkan
      biome
      bun
      itch
      filezilla
      nicotine-plus
      proton-vpn
      dgop
      i2c-tools
      kdePackages.kimageformats
      power-profiles-daemon
      helium
      opencode
      perf
      flamegraph
      samply
      font-awesome
      arduino-ide
      libxkbfile

      cosmic-icons

      flix
      postgresql
      upower
      usbutils
      killall
      powertop
      logisim-evolution
      typst
      typstyle
      typstwriter
      colmena.packages.${system}.colmena
      zap
      kubernetes-helm

      wlogout
      fuzzel
      translate-shell
      hyprpicker
      hypridle
      hyprland-qtutils
      hyprwayland-scanner
      hyprcursor
      material-symbols
      cava
      cliphist
      matugen
      kdePackages.fcitx5-with-addons
      easyeffects
      mpvpaper
      uv
      hyprshot
      libsecret
      hyprls
      ddcutil
      brightnessctl
      libqalculate

      k9s

      prismlauncher
      lf
      rawtherapee
      syncthingtray
      xournalpp
      godot_4
      pico-sdk
      elf2uf2-rs
      obsidian
      home-manager
      pciutils
      nix-top
      grc
      onefetch
      inter
      nerd-fonts.fira-code
      iosevka
      kitty
      rofi
      vesktopWrapped
      spotify
      spicetify-cli
      meslo-lgs-nf
      waybar
      chromium
      sccache
      swaybg
      activitywatchFixed
      networkmanagerapplet
      duf
      dust
      jre_minimal
      datovka
      nwg-displays
      wireguard-tools
      tldr
      grim
      slurp
      wl-clipboard
      nextcloud-client
      kdePackages.filelight
      kdePackages.kate
      kdePackages.ksystemstats
      kdePackages.kinfocenter
      kdePackages.kirigami-addons
      kdePackages.ark
      kdePackages.qtdeclarative
      kdePackages.dolphin
      kdePackages.gwenview
      kdePackages.okular
      cachix
      playerctl
      libcanberra-gtk3 # sound events
      nil # nix language server
      nix-output-monitor
      expect
      nh

      udev-block-notify

      appimage-run
      mpv

      heroic
      gamescope
      heaptrack
      gping
      gparted
      valgrind
      caddy
      jq
      htmlq
      fzf
      nodejs
      ansible
      aria2
      qbittorrent
      audacity
      bettercap
      duperemove
      ffmpeg
      ripgrep
      iotop
      nethogs
      iperf
      mold
      quickemu
      qemu
      socat
      websocat
      whois
      dig
      httpie
      inxi
      numbat
      wireshark
      nixfmt
      qpwgraph

      zed-editor

      android-tools
      hyperfine
      scc
      aircrack-ng
      strace
      ffuf
      sqlmap
      nmap
      rustscan
      thc-hydra
      file
      binwalk
      p7zip
      foremost
      gdb
      feroxbuster
      python312Packages.pypykatz
      screen
      openvpn
      nvtopPackages.full
      openrgb-with-all-plugins

      mdbook
      nix-tree
      nix-du
      graphviz


      awatcher
      tigervnc

      oh-my-posh

      libva-utils
      atuin
      jc
      lsof
      carapace

      crate2nix

      liberation_ttf
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
      google-fonts
    ];

    pointerCursor = {
      gtk.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 16;
    };
  };
  gtk = {
    enable = true;
    colorScheme = "dark";
  };
  programs.man.enable = false;
  services.lorri.enable = true;
  programs.dank-material-shell = {
    enable = true;
    package = dmsShell;
    systemd.enable = true;
  };
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      emoji = [ "Noto Color Emoji" ];
      monospace = [
        "Iosevka"
        "Iosevka NF"
        "FiraCode Nerd Font Mono"
      ];
      sansSerif = [ "Inter" ];
      serif = [ "Noto Serif" ];
    };
  };
  programs = {
    omp.enable = true;
    omp.package = omp.packages.${system}.default.overrideAttrs (old: {
      # The Nix build copies the Cargo addon directly, bypassing the upstream
      # build script that stamps its release version before embedding.
      buildPhase =
        assert pkgs.lib.assertMsg (pkgs.lib.hasInfix ''echo "Compiling OMP"'' old.buildPhase) "OMP build phase changed; update the native addon stamp";
        builtins.replaceStrings
          [ ''echo "Compiling OMP"'' ]
          [
            ''
              bun scripts/stamp-native-version.ts "packages/natives/native/pi_natives.linux-x64-baseline.node"
              echo "Compiling OMP"
            ''
          ]
          old.buildPhase;
    });
    nix-monitor.enable = true;
    nix-monitor.rebuildCommand = [
      "bash"
      "-c"
      "cd /home/dan/projects/dotfiles; nh os switch ."
    ];
    zen-browser = {
      enable = true;
      extraPrefs = ''
        user_pref("media.webrtc.camera.allow-pipewire", true);
      '';
      extraPrefsFiles = [
        (builtins.path {
          path = ./uc.js;
          name = "config.js";
        })
      ];
    };
    fish = {
      enable = true;
      shellInit = ''
        source ~/.config/fish/config-old.fish
      '';
      plugins = with pkgs.fishPlugins; [
        {
          name = "grc";
          src = grc.src;
        }
        {
          name = "tide";
          src = tide.src;
        }
      ];
    };
    nushell = {
      enable = true;

      configFile.text = "source base-config.nu";
    };
    vscode = {
      enable = true;
    };
    difftastic.enable = true;
    difftastic.git.enable = true;
    git = {
      enable = true;
      settings = {
        user.name = "Daniel Bulant";
        user.email = "danbulant@gmail.com";
        pull.rebase = false;
        pull.ff = "only";
        gpg.format = "ssh";
        commit.gpgsign = true;
        gpg.ssh.allowedSignersFile = "/home/dan/allowed_signers";
      };
      signing = {
        signByDefault = true;
        key = "/home/dan/.ssh/id_ed25519";
      };
    };
    gitui.enable = true;
    btop.enable = true;
    bat.enable = true;
    lsd.enable = true;
    fastfetch.enable = true;
    direnv.enable = true;
    direnv.nix-direnv.enable = true;
  };
  services.kdeconnect.enable = true;
  services.kdeconnect.indicator = true;
  services.blueman-applet.enable = true;
  services.mpris-proxy.enable = true;
  xdg = {
    mimeApps = {
      enable = true;
      # Register code/config formats too: Zed only advertises text/plain.
      associations.added = config.xdg.mimeApps.defaultApplications;

      defaultApplications =
        let
          defaultsFor = desktop: types: pkgs.lib.genAttrs types (_: [ desktop ]);
        in
        defaultsFor "zen-beta.desktop" [
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/chrome"
          "text/html"
          "application/xhtml+xml"
          "application/x-extension-htm"
          "application/x-extension-html"
          "application/x-extension-shtml"
          "application/x-extension-xhtml"
          "application/x-extension-xht"
        ]
        // defaultsFor "dev.zed.Zed.desktop" [
          "text/plain"
          "application/x-zerosize"
          "text/markdown"
          "text/x-nix"
          "text/x-python"
          "text/x-shellscript"
          "application/x-shellscript"
          "text/x-c"
          "text/x-csrc"
          "text/x-chdr"
          "text/x-c++src"
          "text/x-c++hdr"
          "text/x-java"
          "text/x-rust"
          "text/rust"
          "text/x-go"
          "text/javascript"
          "application/javascript"
          "application/x-javascript"
          "application/typescript"
          "application/json"
          "application/ld+json"
          "application/toml"
          "text/x-toml"
          "application/yaml"
          "application/x-yaml"
          "text/yaml"
          "text/x-yaml"
          "application/xml"
          "text/xml"
          "text/css"
          "text/x-scss"
          "text/x-sass"
          "text/x-makefile"
          "text/x-cmake"
          "text/x-log"
          "text/x-tex"
          "text/x-typst"
          "text/vnd.typst"
          "text/csv"
          "text/tab-separated-values"
          "application/sql"
          "application/x-php"
          "application/x-ruby"
          "application/x-perl"
          "x-scheme-handler/zed"
        ]
        // defaultsFor "org.kde.gwenview.desktop" [
          "image/avif"
          "image/gif"
          "image/heif"
          "image/jpeg"
          "image/jxl"
          "image/png"
          "image/bmp"
          "image/x-eps"
          "image/x-icns"
          "image/x-ico"
          "image/vnd.microsoft.icon"
          "image/x-portable-bitmap"
          "image/x-portable-graymap"
          "image/x-portable-pixmap"
          "image/x-xbitmap"
          "image/x-xpixmap"
          "image/tiff"
          "image/x-psd"
          "image/x-webp"
          "image/webp"
          "image/x-tga"
          "image/x-xcf"
          "image/openraster"
          "image/svg+xml"
          "image/svg+xml-compressed"
          "application/x-krita"
        ]
        // defaultsFor "okularApplication_pdf.desktop" [
          "application/pdf"
          "application/x-gzpdf"
          "application/x-bzpdf"
        ]
        // defaultsFor "okularApplication_epub.desktop" [ "application/epub+zip" ]
        // defaultsFor "okularApplication_ghostview.desktop" [
          "application/postscript"
          "application/x-gzpostscript"
          "application/x-bzpostscript"
        ]
        // defaultsFor "okularApplication_dvi.desktop" [
          "application/x-dvi"
          "application/x-gzdvi"
          "application/x-bzdvi"
        ]
        // defaultsFor "okularApplication_djvu.desktop" [
          "image/vnd.djvu"
          "image/vnd.djvu+multipage"
        ]
        // defaultsFor "okularApplication_xps.desktop" [
          "application/oxps"
          "application/vnd.ms-xpsdocument"
        ]
        // defaultsFor "okularApplication_comicbook.desktop" [
          "application/x-cbr"
          "application/x-cbz"
          "application/x-cbt"
          "application/x-cb7"
          "application/vnd.comicbook+zip"
          "application/vnd.comicbook-rar"
        ]
        // defaultsFor "okularApplication_mobi.desktop" [ "application/x-mobipocket-ebook" ]
        // defaultsFor "okularApplication_fb.desktop" [ "application/x-fictionbook+xml" ]
        // defaultsFor "mpv.desktop" [
          "video/mp4"
          "video/mpeg"
          "video/mp2t"
          "video/x-matroska"
          "video/webm"
          "video/quicktime"
          "video/x-msvideo"
          "video/vnd.avi"
          "video/x-ms-wmv"
          "video/x-flv"
          "video/x-m4v"
          "video/ogg"
          "video/3gpp"
          "video/3gpp2"
          "audio/mpeg"
          "audio/mp4"
          "audio/aac"
          "audio/flac"
          "audio/ogg"
          "audio/opus"
          "audio/x-opus+ogg"
          "audio/x-vorbis+ogg"
          "audio/x-wav"
          "audio/vnd.wave"
          "audio/x-aiff"
          "audio/x-matroska"
          "audio/webm"
          "audio/x-ms-wma"
          "audio/x-ape"
          "audio/x-wavpack"
          "audio/x-mpegurl"
          "audio/mpegurl"
          "audio/x-scpls"
          "application/ogg"
          "application/x-mpegurl"
          "application/vnd.apple.mpegurl"
          "application/x-cue"
        ]
        // defaultsFor "org.kde.ark.desktop" [
          "application/zip"
          "application/vnd.rar"
          "application/x-rar"
          "application/x-rar-compressed"
          "application/x-7z-compressed"
          "application/x-tar"
          "application/x-compressed-tar"
          "application/x-bzip-compressed-tar"
          "application/x-bzip2-compressed-tar"
          "application/x-xz-compressed-tar"
          "application/x-lzma-compressed-tar"
          "application/x-zstd-compressed-tar"
          "application/gzip"
          "application/x-bzip"
          "application/x-bzip2"
          "application/x-xz"
          "application/x-lzma"
          "application/zstd"
          "application/x-lz4"
          "application/x-lzip"
          "application/x-cpio"
          "application/x-archive"
          "application/x-java-archive"
          "application/vnd.ms-cab-compressed"
        ]
        // defaultsFor "org.qbittorrent.qBittorrent.desktop" [
          "application/x-bittorrent"
          "x-scheme-handler/magnet"
        ]
        // defaultsFor "org.wireshark.Wireshark.desktop" [
          "application/vnd.tcpdump.pcap"
          "application/x-pcapng"
        ]
        // defaultsFor "com.github.xournalpp.xournalpp.desktop" [
          "application/x-xoj"
          "application/x-xojpp"
          "application/x-xopp"
          "application/x-xopt"
        ]
        // {
          "inode/directory" = [ "org.kde.dolphin.desktop" ];
          "x-scheme-handler/discord" = [ "vesktop.desktop" ];
        };
    };
  };

}
