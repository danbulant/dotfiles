{
  pkgs,
  ...
}:

{
  services.hardware.openrgb.enable = true;
  boot = {
    kernelParams = [
      # attempt to fix nvidia perf
      "nvidia_drm.fbdev=1"
      "nvidia_drm.modeset=1"
      "module_blacklist=i915"
      "delayacct"
      "initcall_blacklist=sysfb_init"
      #"quiet"
      #"splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };

  # vr
  services.monado = {
    enable = true;
    defaultRuntime = true; # Register as default OpenXR runtime
  };
  systemd.user.services.monado.environment = {
    STEAMVR_LH_ENABLE = "1";
    XRT_COMPOSITOR_COMPUTE = "1";
    WMR_HANDTRACKING = "0";
    VIT_SYSTEM_LIBRARY_PATH = "${pkgs.basalt-monado}/lib/libbasalt.so";
  };
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraProfile = ''
        # Fixes timezones on VRChat
        unset TZ
        # Allows Monado/WiVRn to be used
        export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
      '';
    };
  };

  hardware.cpu.amd.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    # package = unstable-pkgs.mesa.drivers;
    # Steam support
    enable32Bit = true;
    # package32 = unstable-pkgs.pkgsi686Linux.mesa.drivers;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
    ];
  };
  environment.systemPackages = with pkgs; [
    nvitop
    basalt-monado
  ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    # powerManagement.enable = true;
    nvidiaSettings = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  # powerManagement.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;
}
