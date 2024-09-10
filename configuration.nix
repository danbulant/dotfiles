# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, hyprland, hyprland-plugins, nixpkgs-unstable, lib, nixos-hardware, zen-browser/*, kwin-effects-forceblur*/, ... }:
# let
  # unstable-pkgs = nixpkgs-unstable.legacyPackages.x86_64-linux; #import nixpkgs-unstable.nixosModules.readOnlyPkgs {};
  # unstable-pkgs = hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
# in
{
  imports =
    [
      # nixos-hardware.lenovo-legion-16ach6h-hybrid # this is borked in latest update for some reason, edid doesn't build
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      nixos-hardware.nixosModules.common-cpu-amd-zenpower
      nixos-hardware.nixosModules.common-gpu-amd
      nixos-hardware.nixosModules.common-gpu-nvidia
      nixos-hardware.nixosModules.common-pc-laptop
      nixos-hardware.nixosModules.common-pc-laptop-ssd
      ./hardware-configuration.nix
      ./cachix.nix
    ];

  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];


  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];

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

  networking.hostName = "lenovo-nix";
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Prague";
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
    LC_TIME = "cs_CZ.UTF-8";
  };

  services.xserver.enable = false;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver = {
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.printing.enable = true;
  hardware.acpilight.enable = true;
  hardware.pulseaudio.enable = false;
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
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  programs.wireshark.enable = true;
  time.hardwareClockInLocalTime = true;

  users.users.dan = {
    isNormalUser = true;
    description = "John";
    extraGroups = [ "networkmanager" "wheel" "docker" "fuse" "video" "wireshark" "gamemode"];
    shell = pkgs.fish;
    packages = with pkgs; [
      kdePackages.kate
      zen-browser.packages."${system}".specific
    ];
  };

  # Other defaults are set in home.nix
  environment.sessionVariables.DEFAULT_BROWSER = "firefox";

  programs.firefox.enable = true;
  nix.settings = {
    substituters = [
      "https://hyprland.cachix.org"
      "https://cache.nixos.org"
      "https://nix-gaming.cachix.org"
    ];
    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
  };
  
  # Comment out below for the first time to avoid cache miss, if using flake
  programs.hyprland = {
    enable = true;
    package = hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland.override
      {
        inherit (pkgs) mesa;
      };

    # package = unstable-pkgs.hyprland;
  };
  # End comment out

  # programs.hyprland.enable = true;
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;
  programs.gamemode.enable = true;
  programs.fish.enable = true;
  programs.nix-ld.enable = true; # Fix dynamic binaries from outside of nix
  services.openssh.enable = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    openFirewall = true;
    extraUpFlags = [ "--advertise-exit-node" ];
  };
  hardware.opentabletdriver.enable = true;
  virtualisation.docker.enable = true;
  services.avahi.enable = true;
  

  environment.systemPackages = with pkgs; [
    git
    nvtopPackages.full
    btop
    lshw
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  # The nvidia fun part
  hardware.graphics = {
    enable = true;
    # package = unstable-pkgs.mesa.drivers;
    # Steam support
    enable32Bit = true;
    # package32 = unstable-pkgs.pkgsi686Linux.mesa.drivers;
  };

  boot.kernelModules = ["amdgpu"];
  hardware.nvidia = {
    open = false;
    modesetting.enable = true;
    powerManagement.enable = true;
    prime = {
      # hardware specific, beware!
      amdgpuBusId = lib.mkForce "PCI:06:00:0";
      nvidiaBusId = lib.mkForce "PCI:01:00:0";
    };
  };

  security.polkit.enable = true;
  # OBS Studio virtual camera
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    57621 # Spotify app discovery
  ];
  networking.firewall.allowedUDPPorts = [
    5353 # Google cast discovery
  ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
