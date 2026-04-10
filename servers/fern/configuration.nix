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
