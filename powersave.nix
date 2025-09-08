
{ inputs, config, lib, pkgs, nixos-hardware, ... }:
{
  options = {
    nyx.low-power.enable = 
      lib.mkEnableOption "enables low profile optimizations to reduce watt use";
  };
  imports = [
    nixos-hardware.nixosModules.common-gpu-nvidia-disable
  ];
  config = lib.mkIf config.nyx.low-power.enable {
    boot = {
      kernelParams = [
#      "pcie_aspm.policy=powersupersave"
#      "amd_pstate=passive"
#      "mitigations=auto"
      ];

      extraModprobeConfig = ''
      # AMD iGPU tuning
      options amdgpu dc=1
      options amdgpu deep_color=1
      options amdgpu aspm=1
      # Force dGPU off by default to save power (only use when explicitly requested)
      options amdgpu runpm=1
      '';
    };

    networking.networkmanager.wifi.powersave = true;
    programs.sway.xwayland.enable = false;
    services.pipewire.jack.enable = false;
    powerManagement.enable = true;
    powerManagement.cpuFreqGovernor = "schedutil";
    # powerManagement.cpuFreqGovernor = "powersave";
    services.power-profiles-daemon.enable = false;

    services.auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          energy_performance_preference = "power";
          turbo = "never";
        };
        charger = {
#          governor = "powersave";
          turbo = "auto";
        };
      };
    };

    services.tlp = {
      enable = true;
      settings = {
        TLP_DEFAULT_MODE = "BAT";
        CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
        CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_power";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        PCIE_ASPM_ON_AC = "default";
        PCIE_ASPM_ON_BAT = "powersupersave";
        RUNTIME_PM_ON_AC = "auto";
        RUNTIME_PM_ON_BAT = "auto";
        USB_AUTOSUSPEND = "1";
        WIFI_PWR_ON_AC = "on";
        WIFI_PWR_ON_BAT = "on";
        DEVICES_TO_DISABLE_ON_BAT = "bluetooth";
        DEVICES_TO_DISABLE_ON_STARTUP = "bluetooth";
        DISK_IDLE_SECS_ON_AC = "60";
        DISK_IDLE_SECS_ON_BAT = "30";
        SATA_LINKPWR_ON_AC = "med_power_with_dipm";
        SATA_LINKPWR_ON_BAT = "min_power";
        SOUND_POWER_SAVE_ON_AC = "1";
        SOUND_POWER_SAVE_ON_BAT = "1";
#        PLATFORM_PROFILE_ON_AC = "performance";
#        PLATFORM_PROFILE_ON_BAT = "balanced";
        PLATFORM_PROFILE_ON_AC = "balanced";
        PLATFORM_PROFILE_ON_BAT = "low-power";
      };
    };
    powerManagement.powertop.enable = true;
    services.thermald.enable = true;

    hardware = {
      opengl = {
        enable = true;
        extraPackages = with pkgs; [ mesa ];
      };
      amdgpu.overdrive.enable = lib.mkForce false;
    };

    services.printing.enable = lib.mkForce false;
    hardware.bluetooth.enable = lib.mkForce false;
    services.avahi.enable = lib.mkForce false;
    services.fwupd.enable = true;
    services.locate.enable = false;
    services.openssh.enable = lib.mkForce false;
    programs.java.enable = lib.mkForce false;
    services.upower.enable = lib.mkForce false;
    services = {
      xserver.windowManager.fvwm2.gestures = lib.mkForce false;
      libinput.enable = lib.mkForce false;
    };
    hardware.opentabletdriver.enable = lib.mkForce false;
    programs.kdeconnect.enable = lib.mkForce false;

    virtualisation = {
      # docker.enable = lib.mkForce false;
      libvirtd.enable = lib.mkForce false;
    };
  };
}
