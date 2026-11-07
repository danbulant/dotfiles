{ pkgs, nixpkgs-pcb, ... }:

{
  # NetworkManager opens the browser for AU's SAML/MFA authentication.
  services.anyconnect-webauth = {
    enable = true;
    connections.au = {
      gateway = "remote.au.dk/AU-ACCESS";
      connectionName = "AU-ACCESS";
    };
  };

  networking.networkmanager.dispatcherScripts = [
    {
      # The VPN profile is recreated on each connect; route GitLab after activation.
      source = pkgs.writeShellScript "au-vpn-dns" ''
        set -euo pipefail
        [ "$2" = vpn-up ] || exit 0
        [ "''${CONNECTION_ID:-}" = AU-ACCESS ] || exit 0
        [ -n "''${VPN_IP_IFACE:-}" ] || exit 0
        domains=("~gitlab.au.dk")
        while IFS= read -r domain; do
          [ -z "$domain" ] || domains+=("$domain")
        done < <(${pkgs.networkmanager}/bin/nmcli -g IP4.DOMAIN,IP6.DOMAIN device show "$VPN_IP_IFACE")
        ${pkgs.systemd}/bin/resolvectl domain "$VPN_IP_IFACE" "''${domains[@]}"
      '';
    }
  ];

  environment.systemPackages = [
    nixpkgs-pcb.legacyPackages.${pkgs.stdenv.hostPlatform.system}.pcb2gcode
    (pkgs.callPackage ../../pkgs/flatcam/package.nix { })
  ];

  programs.steam.enable = true;
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
users.users.dan.extraGroups = [
  "dialout"
];
}
