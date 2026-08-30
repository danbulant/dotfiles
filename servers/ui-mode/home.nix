{
  helium,
  zed,
  omp,
  colmena,
  dms,
  zen-browser,
  nix-gaming,
  nixpkgs-unstable, # suyu,
  hyprland-plugins, # , hyprland
  pkgs,
  danksearch,
  niri,
  affinity-nix,
  inputs,
  nix-monitor,
  rusic,
  codexbar,
  config,
  dmm,
  #  paseo,
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

  unstable = import nixpkgs-unstable {
    system = pkgs.system;
    config = {
      allowUnfree = true;
    };
  };
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

  deadlockModManager = dmm.packages.${pkgs.system}.nightly.overrideAttrs (oldAttrs: {
    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (oldAttrs)
        pname
        version
        src
        ;
      pnpm = pkgs.pnpm_11;
      fetcherVersion = 4;
      sourceRoot = "source";
      hash = "sha256-ZxlP6zOwY9Fxa4BCqnUoCmci3lviHn7H3HU5SnmdrSU=";
    };
    postPatch = (oldAttrs.postPatch or "") + ''
            substituteInPlace apps/desktop/src-tauri/Cargo.toml \
              --replace 'tauri-wry = ["tauri/wry"]' 'tauri-wry = ["tauri/wry"]
      cef = []'

            substituteInPlace apps/desktop/src-tauri/src/mod_manager/steam_manager.rs \
              --replace '    let steam_dir = steamlocate::SteamDir::from_dir(&path).map_err(|_| {' '    if !path.join("steamapps").join("libraryfolders.vdf").exists() {
            return Err(Error::InvalidInput(
              "Invalid Steam path: not a valid Steam installation directory".to_string(),
            ));
          }

          let steam_dir = steamlocate::SteamDir::from_dir(&path).map_err(|_| {'
    '';
  });

  osuLazerBinNvidia = pkgs.symlinkJoin {
    name = "osu-lazer-bin-glx-mesa";
    paths = [ (nix-gaming.packages.${system}.osu-lazer-bin.override { gmrun_enable = false; }) ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/osu! \
        --set SDL_VIDEODRIVER x11 \
        --set __GLX_VENDOR_LIBRARY_NAME mesa \
        --set DRI_PRIME 1 \
        --unset MESA_VK_DEVICE_SELECT \
        --unset __EGL_EXTERNAL_PLATFORM_CONFIG_DIRS \
        --unset __EGL_VENDOR_LIBRARY_FILENAMES
    '';
  };

  osuLazerBinDebug = pkgs.writeShellScriptBin "osu-debug" ''
    set -eu

    log="/tmp/osu-lazer-bin-debug.$(date +%s)"
    resolved="$(${pkgs.coreutils}/bin/readlink -f "$(command -v osu!)")"

    {
      echo "PATH=$(command -v osu!)"
      echo "RESOLVED=$resolved"
      echo "ARGV=$*"
      echo "--- wrapper ---"
      ${pkgs.gnused}/bin/sed -n '1,80p' "$resolved" || true
      echo "--- env ---"
      env | ${pkgs.gnugrep}/bin/grep -E '^(SDL_|OSU_|__EGL|__GLX|EGL_|GLX_|LIBGL|MESA|DRI_|GBM|WLR|AQ_|DISPLAY|WAYLAND_DISPLAY|XDG_SESSION|XDG_CURRENT|PIPEWIRE|vblank)' | sort || true
    } > "$log.env"

    exec > >(${pkgs.coreutils}/bin/tee "$log.stdout")
    exec 2> >(${pkgs.coreutils}/bin/tee "$log.stderr" >&2)

    echo "Writing debug logs to $log.env, $log.stdout, and $log.stderr" >&2
    exec osu! "$@"
  '';

  # system = stdenv.hostPlatform.system;
in
{
  imports = [
    ./dotfiles.nix
    omp.homeManagerModules.default
    zen-browser.homeModules.beta
    dms.homeModules.dank-material-shell
    danksearch.homeModules.default
    nix-monitor.homeManagerModules.default
    # niri.homeManagerModules.default
    # dms.homeModules.niri
  ];
  home = {
    stateVersion = "25.11";

    packages = with pkgs; [
      protontricks
      waypipe
      cinny
      #spacedrive-master
      eden
      gh
      inkscape
      osuLazerBinNvidia
      osuLazerBinDebug
      deadlockModManager
      #firefox
      unrar
      wine
      codexbar.packages.${pkgs.system}.default
      codex
      jellyfin-desktop
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
      gearlever
      linux-wallpaperengine
      lmstudio
      #spacetimedb
      nixd
      buck2
      (rusic.packages.${system}.default)
      affine
      voxtype-vulkan
      #affinity-nix.packages.x86_64-linux.v3
      biome
      bun
      lenovo-legion
      itch
      filezilla
      nicotine-plus
      proton-vpn
      dgop
      mysql-workbench
      i2c-tools
      kdePackages.kimageformats
      power-profiles-daemon
      #tail-tray
      helium
      opencode
      perf
      #obs-studio
      flamegraph
      samply
      font-awesome
      arduino-ide
      libxkbfile

      #            dioxus-cli
      cosmic-files
      cosmic-player
      cosmic-screenshot
      cosmic-applibrary
      cosmic-ext-calculator
      cosmic-icons
      examine

      flix
      postgresql
      upower
      usbutils
      killall
      powertop
      pgadmin4-desktopmode
      thunderbird-bin
      logisim-evolution
      typst
      typstyle
      typstwriter
      colmena.defaultPackage.${system}
      usbimager
      #bitwarden-desktop
      #metasploit
      lenovo-legion
      burpsuite
      zap
      kubernetes-helm

      # required by quickshell config
      # unstable.quickshell
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
      #awww
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

      # cloud things
      minikube
      #nebula
      #nixpkgs-unstable.legacyPackages.${system}.jet-pilot
      k9s

      prismlauncher
      lf
      rawtherapee
      syncthingtray
      anki-bin
      xournalpp
      simple-scan
      godot_4
      #rar
      wootility
      #surrealdb
      pico-sdk
      elf2uf2-rs
      obsidian
      betaflight-configurator
      home-manager
      #glxinfo
      pciutils
      nix-top
      grc
      onefetch
      inter
      #fira
      #fira-code
      # fira-code-nerdfont
      nerd-fonts.fira-code
      iosevka
      kitty
      #rofi-wayland
      rofi
      discord
      vesktopWrapped
      spotify
      spicetify-cli
      meslo-lgs-nf
      waybar
      chromium
      #dunst
      sccache
      swaybg
      activitywatchFixed
      networkmanagerapplet
      #kubectl
      duf
      dust
      #jetbrains.webstorm
      #jetbrains.clion
      #jetbrains.datagrip
      # jetbrains.rider
      #jetbrains.idea-ultimate
      jre_minimal
      datovka
      nwg-displays
      wireguard-tools
      mongodb-compass
      unstable.mongodb-tools
      #hashcat
      tldr
      #dunst
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
      cachix
      playerctl
      libcanberra-gtk3 # sound events
      #qt6ct
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
      #cinny-desktop
      gping
      gparted
      valgrind
      caddy
      jq
      htmlq
      fzf
      gleam
      erlang
      terraform
      nodejs
      #corepack
      ansible
      aria2
      qbittorrent
      audacity
      bettercap
      duperemove
      ffmpeg
      flameshot
      ripgrep
      iotop
      nethogs
      # john
      iperf
      mold
      nheko
      quickemu
      qemu
      socat
      websocat
      whois
      #wifite2
      dig
      httpie
      inxi
      numbat
      wireshark
      nixfmt
      qpwgraph

      zed-editor
      #nixpkgs-unstable.legacyPackages.${system}.zed-editor
      # zed.packages.${system}.default
      nixpkgs-unstable.legacyPackages.${system}.pineflash
      #unstable.nosql-booster

      android-tools
      hyperfine
      scc
      aircrack-ng
      strace
      # ghidra
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
      #ghostty
      nvtopPackages.full
      openrgb-with-all-plugins

      mdbook
      nix-tree
      nix-du
      graphviz

      #blender
      warpinator

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
      # rubik
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
  wayland.windowManager.hyprland = {
    #        enable = true;
    # package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # portalPackage = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    # plugins = [
    #     hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo
    #     hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprtrails
    # ];
  };
  # programs.dsearch.enable = true;
  programs.dank-material-shell = {
    enable = true;
    package = dmsShell;
    systemd.enable = true;
    # niri = {
    #   enableKeybinds = false; # Sets static preset keybinds
    #   # enableSpawn = true; # Auto-start DMS with niri, if enabled
    # };
  };
  # programs.niri.enable = true;
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
    omp = {
      enable = true;
      package = omp.packages.${system}.default.overrideAttrs (oldAttrs: {
        # The upstream smoke test otherwise inherits a build directory that
        # Bun has already unlinked while creating the compiled executable.
        preInstallCheck = (oldAttrs.preInstallCheck or "") + ''
          mkdir -p "$TMPDIR/omp-install-check"
          cd "$TMPDIR/omp-install-check"
        '';
      });
    };
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
        # (builtins.fetchurl {
        #   url = "https://raw.githubusercontent.com/MrOtherGuy/fx-autoconfig/master/program/config.js";
        #   sha256 = "1mx679fbc4d9x4bnqajqx5a95y1lfasvf90pbqkh9sm3ch945p40";
        # })
        # (builtins.toFile (builtins.readFile ./uc.js))
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

      # unstable, perhaps 25.05
      # plugins = with pkgs.nushellPlugins; [
      #     query
      #     skim
      #     net
      #     highlight
      #     gstat
      #     formats
      #     dbus
      #     units
      # ];
      # configFile.source = ./.config/nushell/base-config.nu;
      configFile.text = "source base-config.nu";
    };
    vscode = {
      enable = true;
      # package = nixpkgs-unstable.packages.${pkgs.system}.vscode;
      # package = unstable.pkgs.vscode;
      # extensions = with pkgs.vscode-extensions; [

      # ];
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
    /*
      configFile."openxr/1/active_runtime.json".source =
        "${pkgs.monado}/share/openxr/1/openxr_monado.json";
      configFile."openvr/openvrpaths.vrpath".text = ''
        {
          "config" :
          [
            "${config.xdg.dataHome}/Steam/config"
          ],
          "external_drivers" : null,
          "jsonid" : "vrpathreg",
          "log" :
          [
            "${config.xdg.dataHome}/Steam/logs"
          ],
          "runtime" :
          [
            "${pkgs.opencomposite}/lib/opencomposite"
          ],
          "version" : 1
        }
      '';
    */
    mimeApps = {
      enable = true;

      defaultApplications = {
        "x-scheme-handler/http" = "zen-beta.desktop";
        "x-scheme-handler/https" = "zen-beta.desktop";
        "x-scheme-handler/chrome" = "zen-beta.desktop";
        "text/html" = "zen-beta.desktop";
        "application/x-extension-htm" = "zen-beta.desktop";
        "application/x-extension-html" = "zen-beta.desktop";
        "application/x-extension-shtml" = "zen-beta.desktop";
        "application/xhtml+xml" = "zen-beta.desktop";
        "application/x-extension-xhtml" = "zen-beta.desktop";
        "application/x-extension-xht" = "zen-beta.desktop";
        "x-scheme-handler/discord" = "vesktop.desktop";
      };
    };
  };

}
