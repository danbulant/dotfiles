if status is-interactive
    # Commands to run in interactive sessions can go here
    function react_to_pwd --on-variable PWD
        lsd
        if test -d .git
            echo
            onefetch
        end
    end
    echo -e "\n"
    fastfetch
end
set PATH $PATH $HOME/.cargo/bin $HOME/.local/share/pnpm $HOME/.local/bin $HOME/.spicetify $HOME/.bun/bin
set fish_greeting
set -x PNPM_HOME /home/dan/.local/share/pnpm

# tabtab source for packages
# uninstall by removing these lines
# [ -f ~/.config/tabtab/fish/__tabtab.fish ]; and . ~/.config/tabtab/fish/__tabtab.fish; or true

# direnv
direnv hook fish | source
#set -x LD_LIBRARY_PATH $LD_LIBRARY:$CONDA_PREFIX/lib
fish_ssh_agent

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
#if test -f /opt/anaconda/bin/conda
#    eval /opt/anaconda/bin/conda "shell.fish" "hook" $argv | source
#end
# <<< conda initialize <<<

# eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
# set -x PERL5LIB "/home/dan/perl5/lib/perl5:$PERL5LIB";
# set -x PERL_LOCAL_LIB_ROOT "/home/dan/perl5:$PERL_LOCAL_LIB_ROOT";
# set -x PERL_MB_OPT "--install_base \"/home/dan/perl5\"";
# set -x PERL_MM_OPT "INSTALL_BASE=/home/dan/perl5";
set -x SCCACHE_DIR "/media/New BTRFS/.sccache"
set -x RUSTC_WRAPPER (which sccache)

abbr -a nsp "nix-shell --run fish -p" 
abbr -a ns "nix-shell --run fish"