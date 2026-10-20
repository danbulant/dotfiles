{ sops-nix, ... }:
{
  imports = [ sops-nix.nixosModules.sops ];

  # Reuse the existing host identity; never generate or copy private keys.
  sops.age = {
    sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    generateKey = false;
  };
  sops.gnupg.sshKeyPaths = [ ];

  # Declare secrets only after the encrypted host file has been provisioned.
  # No service paths or credentials change merely by importing this module.
}
