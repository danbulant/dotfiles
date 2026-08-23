{ pkgs, ... }:

{
  services.openssh.settings.MaxSessions = 64;

  hardware.graphics.extraPackages = with pkgs; [
    # Required for modern Intel GPUs (Xe iGPU and ARC)
    intel-media-driver # VA-API (iHD) userspace
    vpl-gpu-rt # oneVPL (QSV) runtime

    # Optional compute/tooling for Intel GPUs
    intel-compute-runtime # OpenCL (NEO) + Level Zero for Arc/Xe
  ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };
  services.thermald.enable = true;

}
