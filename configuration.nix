# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:
let
  unstable-pkgs = import <nixos-unstable> {};
in
{
  imports =
    [
      <nixos-hardware/lenovo/legion/16ach6h/hybrid>
      ./hardware-configuration.nix
      <home-manager/nixos>
      ./cachix.nix
    ];

  # Bootloader.
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
    #libinput.enable = true;
  };

  services.printing.enable = true;

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    #jack.enable = true;
  };
  services.geoclue2.enable = true;
  services.localtimed.enable = true;
  time.hardwareClockInLocalTime = true;

  users.users.dan = {
    isNormalUser = true;
    description = "John";
    extraGroups = [ "networkmanager" "wheel" "docker" "fuse" ];
    shell = pkgs.fish;
    packages = with pkgs; [
      kdePackages.kate
    #  thunderbird
    ];
  };
  home-manager.useGlobalPkgs = true;
  home-manager.users.dan = import ./home.nix;

  # Other defaults are set in home.nix
  environment.sessionVariables.DEFAULT_BROWSER = "firefox";

  programs.firefox.enable = true;
  programs.hyprland.enable = true;
  programs.hyprland.package = unstable-pkgs.hyprland;
  programs.hyprlock.enable = true;
  services.hypridle.enable = true;
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
  hardware.opengl.enable = true;

  hardware.nvidia = {
    prime = {
      # hardware specific, beware!
      amdgpuBusId = lib.mkForce "PCI:01:00:0";
      nvidiaBusId = lib.mkForce "PCI:06:00:0";
    };
  };

  security.polkit.enable = true;

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
