
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

  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  networking.hostName = "eisen";
  networking.nameservers = ["1.1.1.1"];
  networking.networkmanager.enable = true;
  time.timeZone = lib.mkForce "Europe/Prague";
  i18n.defaultLocale = "en_US.UTF-8";

  services.dnsmasq.enable = true;
  security.rtkit.enable = true;
  security.polkit.enable = true;
  services.localtimed.enable = true;

  services.openssh.enable = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    openFirewall = true;
    extraUpFlags = [ "--advertise-exit-node" ];
  };
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };
  hardware.nvidia-container-toolkit.enable = true;
  services.avahi.enable = true;

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
  };
  services.lldpd.enable = true;
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

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

    kernelParams = [
        "nvidia_drm.fbdev=1" "nvidia_drm.modeset=1" "module_blacklist=i915"
        "initcall_blacklist=sysfb_init"
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
    ];

    # zfs.enabled = false;
    swraid.enable = false;

    initrd.systemd.enable = true;

    loader = {
      # systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 0;
      grub.enable = true;
      grub.device = "nodev";
      grub.efiSupport = true;
    };
  };

  users.users.dan = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "docker" "fuse" "video" "wireshark" "gamemode" "scanner" "lp" "kvm" "adbusers"];
    shell = pkgs.nushell;
    packages = with pkgs; [
      
    ];
  };
  nix.settings.trusted-users = [ "root" "@wheel" "dan" ];

  environment.systemPackages = with pkgs; [
    git
    nvtopPackages.full
    btop
    lshw
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # /etc/hosts :)
  networking.extraHosts = ''
  '';
}