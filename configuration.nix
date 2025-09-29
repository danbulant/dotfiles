
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, /*hyprland,*/ options, /*hyprland-plugins, */nixpkgs-unstable, lib, nixos-hardware, zen-browser/*, kwin-effects-forceblur*/, ... }:
let
  unstable-pkgs = nixpkgs-unstable.legacyPackages.x86_64-linux; #import nixpkgs-unstable.nixosModules.readOnlyPkgs {};
  # unstable-pkgs = hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports =
    [
      nixos-hardware.nixosModules.lenovo-legion-16ach6h-hybrid # this is borked in latest update for some reason, edid doesn't build
      # nixos-hardware.nixosModules.common-cpu-amd
      # nixos-hardware.nixosModules.common-cpu-amd-pstate
      # nixos-hardware.nixosModules.common-cpu-amd-zenpower
      # nixos-hardware.nixosModules.common-gpu-amd
      # nixos-hardware.nixosModules.common-gpu-nvidia
      # nixos-hardware.nixosModules.common-pc-laptop
      # nixos-hardware.nixosModules.common-pc-laptop-ssd
      ./hardware-configuration.nix
      # /etc/nixos/cachix.nix
    ];
  nyx.low-power.enable = true;

  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
    "cinny-unwrapped-4.2.3"
    "cinny-4.2.3"
     "libsoup-2.74.3"
    # "qbittorrent-4.6.4"
    # "cinny-3.2.0"
    "dotnet-sdk-wrapped-7.0.410"
    "dotnet-sdk-7.0.410"
    "dotnet-runtime-6.0.36"
    "dotnet-sdk-wrapped-6.0.428"
    "dotnet-sdk-6.0.428"
    "electron-33.4.11"
  ];


  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];

  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  fileSystems."/media/New BTRFS" = {
    device = "/dev/disk/by-uuid/26b1fa88-e270-45c7-a6c0-d46c9d4c6c90";
    fsType = "btrfs";
  };
  fileSystems."/media/secondary" = {
    device = "/dev/disk/by-uuid/050574C34881C3B9";
    fsType = "ntfs";
  };
  fileSystems."/media/windows" = {
    device = "/dev/disk/by-uuid/846A9EF06A9EDE6C";
    fsType = "ntfs";
  };

  # services.beesd.filesystems = {
  #   root = {
  #     spec = "UUID=26b1fa88-e270-45c7-a6c0-d46c9d4c6c90";
  #     hashTableSizeMB = 1024;
  #     extraOptions = [
  #       "-c" "4"
  #       "-g" "10"
  #     ];
  #   };
  # };

  networking.hostName = "lenovo-nix";
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  # networking.nameservers = ["1.1.1.1"];
  services.dnsmasq.settings.server = [ "127.0.0.1#5053" ];

  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [networkmanager-openconnect];
  networking.networkmanager.dns = "none";

  services.dnscrypt-proxy2 = {
    enable = true;
    # See https://github.com/DNSCrypt/dnscrypt-proxy/blob/master/dnscrypt-proxy/example-dnscrypt-proxy.toml
    settings = {
      sources.public-resolvers = {
        urls = [
          "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
          "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
        ];
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"; # See https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/public-resolvers.md
        cache_file = "/var/lib/dnscrypt-proxy/public-resolvers.md";
      };

      listen_addresses = ["127.0.0.1:5053"];
      ipv6_servers = false;
      block_ipv6 = ! (false);

      require_dnssec = true;
      require_nolog = false;
      require_nofilter = true;
      # aarhus university dns
      # bootstrap_resolvers = ["10.192.232.113:53"];

      # server_names = [ ... ];
    };
  };

  time.timeZone = lib.mkForce "Europe/Prague";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "cs_CZ.UTF-8";
    LC_IDENTIFICATION = "cs_CZ.UTF-8";
    LC_MEASUREMENT = "cs_CZ.UTF-8";
    LC_MONETARY = "cs_CZ.UTF-8";
    LC_NAME = "cs_CZ.UTF-8";
    LC_NUMERIC = "cs_CZ.UTF-8";
    LC_PAPER = "cs_CZ.UTF-8";
    LC_TELEPHONE = "cs_CZ.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };
  services.dnsmasq.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
   services.desktopManager.plasma6 = {
     enable = true;
   };
  #services.desktopManager.gnome.enable = true;
  services.xserver = {
    enable = false;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.printing.enable = true;
  hardware.sane.enable = true;
  hardware.acpilight.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.pam.loginLimits = [{
    domain = "*";
    type = "soft";
    item = "nofile";
    value = "64000";
  }];
  services.geoclue2.enable = true;
  services.localtimed.enable = true;
  services.lorri.enable = true;
  services.blueman.enable = true;
  qt.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  programs.wireshark.enable = true;
  programs.adb.enable = true;
  programs.partition-manager.enable = true;
  time.hardwareClockInLocalTime = true;

  users.users.dan = {
    isNormalUser = true;
    description = "John";
    extraGroups = [ "networkmanager" "wheel" "docker" "fuse" "video" "wireshark" "gamemode" "scanner" "lp" "kvm" "adbusers" "dialout"];
    shell = pkgs.fish;
    packages = with pkgs; [
      kdePackages.kate
    ];
  };
  nix.settings.trusted-users = [ "root" "@wheel" "dan" ];

  # Other defaults are set in home.nix
  # environment.sessionVariables.DEFAULT_BROWSER = "firefox";

  # programs.firefox.enable = true;
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://colmena.cachix.org"
    ];
    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  
  # Comment out below for the first time to avoid cache miss, if using flake
  programs.hyprland = {
    enable = true;
#    package = hyprland.packages.${pkgs.system}.hyprland;
    # portalPackage = hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland.override
    #  {
    #     inherit (pkgs) mesa;
    #   };

    # package = unstable-pkgs.hyprland;
  };
  # End comment out
  
  #xdg.configFile."menus/applications.menu".text = builtins.readFile ./applications.menu;
  environment.etc."/xdg/menus/plasma-applications.menu".text = builtins.readFile "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  # programs.hyprland.enable = true;
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;
  programs.gamemode.enable = true;
  programs.fish.enable = true;
  # Fix dynamic binaries from outside of nix
  programs.nix-ld = {
    enable = true;
    libraries = options.programs.nix-ld.libraries.default ++ (with pkgs; [
      libdrm
      mesa
      libxkbcommon
      openssl
      libGL libva
      libelf
    ]);
  };
  services.openssh.enable = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    openFirewall = true;
    extraUpFlags = [ "--advertise-exit-node" ];
  };
  hardware.opentabletdriver.enable = true;
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
#    enableNvidia = true;
  };
  # hardware.nvidia-container-toolkit.enable = true;
  services.avahi.enable = true;

  boot = {
    # Shortcuts for fixing things
    # alt+sysrq (prtsc) + key
    # h: Print help to the system log.
    # f: Trigger the kernel oom killer.
    # s: Sync data to disk before triggering the reset options below.
    # e: SIGTERM all processes except PID 0.
    # i: SIGKILL all processes except PID 0.
    # b: Reboot the system.
    kernel.sysctl."kernel.sysrq" = 1;

    # Visuals
    plymouth = {
        enable = true;
        theme = "deus_ex"; # motion is also cool
        themePackages = with pkgs; [
          (adi1090x-plymouth-themes.override {
            selected_themes = [ "deus_ex" ];
          })
        ];
    };
    kernelParams = [
        # attempt to fix nvidia perf
        "nvidia_drm.fbdev=1" "nvidia_drm.modeset=1" "module_blacklist=i915"
        "delayacct"
        "initcall_blacklist=sysfb_init"
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
    ];

    # Removing support for unneeded stuff
    # zfs.enabled = false;
    swraid.enable = false;

    initrd.systemd.enable = true;

    # OBS Studio virtual camera
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
      lenovo-legion-module
    ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
      options nvidia_drm modeset=1 fbdev=1
    '';
  };
  boot.loader.timeout = 0;

  # App image support
  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = "${pkgs.appimage-run}/bin/appimage-run";
    recognitionType = "magic";
    offset = 0;
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    magicOrExtension = ''\x7fELF....AI\x02'';
  };

  environment.systemPackages = with pkgs; [
    git
    nvtopPackages.full
    btop
    lshw
    hyprpolkitagent

    lenovo-legion


    # required for quickshell config; needs to be here for them to be included in import/plugin path
    kdePackages.qt5compat
    kdePackages.qtdeclarative
    kdePackages.qtlocation
    kdePackages.qtlocation.dev
    kdePackages.qtpositioning
    kdePackages.qtpositioning.dev
    kdePackages.kirigami
    kdePackages.kirigami-addons
    kdePackages.kirigami-addons.dev
    libsForQt5.appstream-qt
    libsForQt5.kcoreaddons
    libsForQt5.kirigami2
    kdePackages.syntax-highlighting

    (python313.withPackages(ps: with ps; [
      build
      pillow
      cffi
      libsass
      material-color-utilities
      materialyoucolor
      numpy
      packaging
      pillow
      psutil
      pycparser
      pyproject-hooks
      pywayland
      setproctitle
      setuptools
      setuptools-scm
      wheel

      pwntools
    ]))
  ];

  environment.variables =  let
        qtVersions = with pkgs; [
          qt5
          qt6
        ];
      in
      {
        QT_PLUGIN_PATH = map (qt: "/${qt.qtbase.qtPluginPrefix}") qtVersions;
        QML2_IMPORT_PATH = map (qt: "/${qt.qtbase.qtQmlPrefix}") qtVersions ++ (with unstable-pkgs; [
          "${quickshell}/lib/qt-6/qml/"
        ]);
      };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  # The nvidia fun part
  hardware.graphics = {
    enable = true;
    # package = unstable-pkgs.mesa.drivers;
    # Steam support
    enable32Bit = true;
    # package32 = unstable-pkgs.pkgsi686Linux.mesa.drivers;
    extraPackages = with pkgs; [
      libvdpau-va-gl
      nvidia-vaapi-driver
    ];
  };

  boot.kernelModules = ["amdgpu" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" "lenovo-legion-module"];
  hardware.nvidia = {
    open = false;
    # modesetting.enable = true;
    # powerManagement.enable = true;
    # nvidiaSettings = true;
    prime = {
      # hardware specific, beware!
      amdgpuBusId = lib.mkForce "PCI:06:00:0";
      nvidiaBusId = lib.mkForce "PCI:01:00:0";
    };
  };
  hardware.enableAllFirmware = true;
  services.cpupower-gui.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
   # USB_DENYLIST = "04d9:a0b8";
  };
  # powerManagement.powertop.enable = true;
  # powerManagement.cpuFreqGovernor = "powersave";

  security.polkit.enable = true;

  services.create_ap = {
    enable = false;
    settings = {
      INTERNET_IFACE = "eno1";
      WIFI_IFACE = "wlp4s0";
      SSID = "nixos.create_ap.enable";
      PASSPHRASE = "";
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    57621 # Spotify app discovery
    42000
    42001
    1716 # kdeconnect
  ];
  networking.firewall.allowedUDPPorts = [
    5353 # Google cast discovery
    42000 # warpinator
    42001 # warpinator 
    67 68 # dhcp
    1716 # kdeconnect
  ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  hardware.wooting.enable = true;
  
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
  };
  services.lldpd.enable = true;
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # /etc/hosts :)
  networking.extraHosts = ''
  '';
}
