{
  config,
  pkgs,
  options,
  nixpkgs-unstable,
  lib,
  dms,
  ...
}:

{

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

      # Required for modern Intel GPUs (Xe iGPU and ARC)
      intel-media-driver # VA-API (iHD) userspace
      vpl-gpu-rt # oneVPL (QSV) runtime

      # Optional (compute / tooling):
      intel-compute-runtime # OpenCL (NEO) + Level Zero for Arc/Xe
      #     libvdpau-va-gl
      nvidia-vaapi-driver
    ];
  };
  hardware.nvidia = {
    open = false;
    modesetting.enable = true;
    powerManagement.enable = true;
    nvidiaSettings = true;
  };
}
