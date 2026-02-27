# Sysbox Integration

This directory contains a NixOS module for [Sysbox](https://github.com/nestybox/sysbox), a next-generation OCI runtime for running system containers.

## What is Sysbox?

Sysbox enables running system containers with enhanced security and isolation. It allows you to run Docker, Systemd, Kubernetes, and other system-level software inside containers without privileged mode.

## Usage in This Configuration

Sysbox is already enabled for the `aura` system in `configuration.nix:295`:

```nix
virtualisation.sysbox.enable = true;
```

## Testing Sysbox

After rebuilding your system, you can test sysbox with Docker:

### 1. Check Services
```bash
systemctl status sysbox-mgr sysbox-fs
```

### 2. Verify Docker Integration
```bash
docker info | grep sysbox-runc
```

### 3. Run a Test Container
```bash
# Run a simple container with sysbox-runc
docker run --runtime=sysbox-runc --rm -it ubuntu:latest bash
```

### 4. Run Docker-in-Docker
```bash
# Run Docker inside Docker using sysbox
docker run --runtime=sysbox-runc --name=docker-in-docker -d nestybox/ubuntu-jammy-docker

# Execute commands inside
docker exec -it docker-in-docker docker run hello-world
```

## External Usage

Other flakes can use this sysbox module:

```nix
{
  inputs.your-dotfiles.url = "github:youruser/dotfiles";
  
  outputs = { nixpkgs, your-dotfiles, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        your-dotfiles.nixosModules.sysbox
        {
          virtualisation.sysbox.enable = true;
          virtualisation.docker.enable = true;  # or podman
        }
      ];
    };
  };
}
```

You can also use just the package overlay:

```nix
{
  inputs.your-dotfiles.url = "github:youruser/dotfiles";
  
  outputs = { nixpkgs, your-dotfiles, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [{
        nixpkgs.overlays = [ your-dotfiles.overlays.default ];
        environment.systemPackages = [ pkgs.sysbox ];
      }];
    };
  };
}
```

## Configuration Options

The module provides these options:

- `virtualisation.sysbox.enable` - Enable sysbox (default: false)
- `virtualisation.sysbox.package` - The sysbox package to use (default: pkgs.sysbox)

## What the Module Does

When enabled, the module automatically:

1. **Configures Container Runtimes**
   - Registers `sysbox-runc` with Docker (if Docker is enabled)
   - Registers `sysbox-runc` with Podman (if Podman is enabled)

2. **Sets Up Services**
   - `sysbox-mgr.service` - Manager service
   - `sysbox-fs.service` - Filesystem service

3. **Applies System Configuration**
   - Enables unprivileged user namespaces
   - Sets required sysctl values (inotify limits, kernel.keys)
   - Creates iptables compatibility layer in /sbin

4. **Installs Binaries**
   - `sysbox-runc` - The OCI runtime
   - `sysbox-mgr` - Manager daemon
   - `sysbox-fs` - Filesystem daemon

## Implementation Details

- **Version**: 0.6.7
- **License**: Apache 2.0
- **Platforms**: x86_64-linux, aarch64-linux
- **Package Type**: Pre-built .deb packages (not built from source)

The implementation is based on [this commit](https://github.com/CyberShadow/nixpkgs/commit/9f14ecca828c47b9696ffe588759779d5d7784a7) with improvements for:
- Module system compatibility (avoiding infinite recursion)
- Sysctl conflict resolution
- Automatic runtime registration

## Files

- `pkgs/sysbox/package.nix` - Package definition
- `modules/sysbox.nix` - NixOS module
- Exported as `nixosModules.sysbox` in flake.nix
- Exported as `overlays.default` in flake.nix
