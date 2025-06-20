{ nix-gaming, nixpkgs-unstable,/* suyu, */hyprland-plugins/*, hyprland*/, ... }:
{ pkgs, inputs, ...}:
let

  unstable = import nixpkgs-unstable {
    system = pkgs.system;
    config = {
	allowUnfree = true;
    };
  };

in
{
    home = {
        stateVersion = "24.05";

        packages = with pkgs; [
            # required by quickshell config
            unstable.quickshell
            wlogout
            fuzzel
            translate-shell
            hyprpicker
            hypridle
            hyprland-qtutils
            hyprwayland-scanner
            hyprcursor
            material-symbols
            cava
            cliphist
            matugen
            swww
            kdePackages.fcitx5-with-addons
            easyeffects
            mpvpaper
            uv
            hyprshot
            libsecret
            
            # cloud things
            minikube
            nebula
            nixpkgs-unstable.legacyPackages.${system}.jet-pilot
            k9s

            prismlauncher
            helix
            lf
            rawtherapee
            syncthingtray
            anki-bin
            xournalpp
            simple-scan
            godot_4
            rar
            wootility
            surrealdb
            pico-sdk
            elf2uf2-rs
            obsidian
            betaflight-configurator
            home-manager
            glxinfo
            pciutils
            nix-top
            grc
            onefetch
            inter
            fira
            fira-code
            # fira-code-nerdfont
            nerd-fonts.fira-code
            iosevka
            kitty
            rofi-wayland
            discord
            vesktop
            spotify
            spicetify-cli
            meslo-lgs-nf
            waybar
            chromium
            dunst
            sccache
            swaybg
            activitywatch
            networkmanagerapplet
            kubectl
            duf
            dust
            jetbrains.webstorm
            jetbrains.clion
            jetbrains.datagrip
            jetbrains.rider
            datovka
            nwg-displays
            wireguard-tools
            mongodb-compass
            unstable.mongodb-tools
            hashcat
            tldr
            dunst
            grim
            slurp
            wl-clipboard
            nextcloud-client
            kdePackages.plasma-workspace
            kdePackages.filelight
            kdePackages.kate
            kdePackages.ksystemstats
            kdePackages.kinfocenter
            kdePackages.kirigami-addons
            kdePackages.ark
            kdePackages.qtdeclarative
            cachix
            playerctl
            libcanberra-gtk3 # sound events
            qt6ct
            nil # nix language server
            nix-output-monitor
            expect
            nh
            
            udev-block-notify

            appimage-run
            mpv

            heroic
            heaptrack
            cinny-desktop
            gping
            gparted
            valgrind
            caddy
            jq
            htmlq
            fzf
            gleam
            erlang
            terraform
            nodejs
            corepack
            ansible
            aria2
            qbittorrent
            audacity
            bettercap
            duperemove
            ffmpeg
            flameshot
            ripgrep
            iotop
            nethogs
            john
            iperf
            mold
            nheko
            quickemu
            qemu
            socat
            websocat
            whois
            wifite2
            dig
            httpie
            inxi
            numbat
            wireshark
            nixfmt-rfc-style
            qpwgraph

            nixpkgs-unstable.legacyPackages.${system}.zed-editor
            nixpkgs-unstable.legacyPackages.${system}.pineflash
            unstable.nosql-booster

            android-tools
            hyperfine
            scc
            aircrack-ng
            strace
            ghidra
            ffuf
            sqlmap
            nmap
            rustscan
            thc-hydra
            file
            binwalk
            p7zip
            foremost
            gdb
            feroxbuster
            python312Packages.pypykatz
            screen
            openvpn
            ghostty

            mdbook
            nix-tree
            nix-du
            graphviz

            blender
            warpinator

            awatcher
            tigervnc

            oh-my-posh

            libva-utils
            atuin
            jc
            lsof
            carapace

            crate2nix
        ];
    };
    services.lorri.enable = true;
    wayland.windowManager.hyprland = {
#        enable = true;
        # package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        # portalPackage = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
        # plugins = [
        #     hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprexpo
        #     hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprtrails
        # ];
    };
    fonts.fontconfig = {
        enable = true;
        defaultFonts = {
            emoji = ["Noto Color Emoji"];
            monospace = ["Iosevka" "Iosevka NF" "FiraCode Nerd Font Mono"];
            sansSerif = ["Inter"];
            serif = ["Noto Serif"];
        };
    };
    programs = {
        fish = {
            enable = true;
            shellInit = ''
                source ~/.config/fish/config-old.fish

            '';
            # set -x PRISMA_SCHEMA_ENGINE_BINARY "${prisma-engines}/bin/schema-engine"
            # set -x PRISMA_QUERY_ENGINE_BINARY "${prisma-engines}/bin/query-engine"
            # set -x PRISMA_QUERY_ENGINE_LIBRARY "${prisma-engines}/lib/libquery_engine.node"
            # set -x PRISMA_FMT_BINARY "${prisma-engines}/bin/prisma-fmt"
            plugins = with pkgs.fishPlugins; [
                { name = "grc"; src = grc.src; }
                { name = "tide"; src = tide.src; }
            ];
        };
        nushell = {
            enable = true;

            # unstable, perhaps 25.05
            # plugins = with pkgs.nushellPlugins; [
            #     query
            #     skim
            #     net
            #     highlight
            #     gstat
            #     formats
            #     dbus
            #     units
            # ];
            # configFile.source = ./.config/nushell/base-config.nu;
            configFile.text = ''source base-config.nu'';
        };
        vscode = {
            enable = true;
            # package = nixpkgs-unstable.packages.${pkgs.system}.vscode;
            # package = unstable.pkgs.vscode;
            # extensions = with pkgs.vscode-extensions; [

            # ];
        };
        # nixvim = {
        #     enable = true;
        #     # colorscheme = "hanekawa_tsubasa";w
        #     colorschemes.onedark.enable = true;
        #     plugins = {
        #         wakatime.enable = true;
        #         cmp = {
        #             autoEnableSources = true;
        #             enable = true;
        #             settings.sources = [
        #                 { name = "fish"; }
        #                 { name = "nvim_lsp"; }
        #                 { name = "path"; }
        #                 { name = "buffer"; }
        #                 # { name = "treesitter"; }
        #             ];
        #         };
        #     };
        # };
        git = {
            enable = true;
            userName  = "Daniel Bulant";
            userEmail = "danbulant@gmail.com";
            difftastic.enable = true;
            signing = {
                signByDefault = true;
                key = "/home/dan/.ssh/id_ed25519";
            };
            extraConfig = {
                pull.rebase = false;
                pull.ff = "only";
                gpg.format = "ssh";
                commit.gpgsign = true;
                gpg.ssh.allowedSignersFile = "/home/dan/allowed_signers";
            };
        };
        gitui.enable = true;
        btop.enable = true;
        bat.enable = true;
        lsd.enable = true;
        fastfetch.enable = true;
        direnv.enable = true;
        direnv.nix-direnv.enable = true;
        # firefox.enable = true;
    };
    services.kdeconnect.enable = true;
    services.kdeconnect.indicator = true;
    services.blueman-applet.enable = true;
    services.mpris-proxy.enable = true;
    xdg.mimeApps = {
        enable = true;

        defaultApplications = {
            "text/html" = "firefox.desktop";
            "x-scheme-handler/http" = "firefox.desktop";
            "x-scheme-handler/https" = "firefox.desktop";
            "x-scheme-handler/about" = "firefox.desktop";
            "x-scheme-handler/unknown" = "firefox.desktop";
        };
    };
    
}
