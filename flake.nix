{
  description = "NixOS Docker with user Nix Access";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = inputs@{ self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system}.default = pkgs.dockerTools.buildLayeredImage {
      name = "nix-nixuser";
      tag = "latest";

      # Base layer with core system packages
      contents = with pkgs; [
        bashInteractive
        coreutils
        nix
        cacert
        shadow
        util-linux
        sudo

        (writeTextDir "etc/nix/nix.conf" "experimental-features = nix-command flakes\nsubstituters = https://cache.nixos.org/\ntrusted-users = root nixuser\nsandbox = false\nbuild-users-group =\nssl-cert-file = ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt\nrequire-sigs = false\n")
        (writeTextDir "etc/passwd" "root:x:0:0::/root:/bin/bash\nnixuser:x:1000:1000::/home/nixuser:/bin/bash\n")
        (writeTextDir "etc/group" "root:x:0:\nnixuser:x:1000:\nnixbld:x:30000:1000\n")
        (writeTextDir "root/.bashrc" "")

        (runCommand "create-dirs" {} ''
          mkdir -p $out/nix/store/.links
          mkdir -p $out/nix/var/nix/{db,profiles,gcroots,temproots,userpool}
          # Create user profile structure with proper ownership
          mkdir -p $out/nix/var/nix/profiles/per-user/1000
        '')
        (writeScriptBin "setup-permissions" ''
          #!/bin/bash
          # Setup permissions for user operations
          mkdir -p /nix/store/.links
          chmod -R 755 /nix/store/.links
          chown -R 1000:1000 /nix/store/.links
          
          # Create and set permissions for nix/var directory structure
          mkdir -p /nix/var/nix/{db,profiles,gcroots,temproots,userpool}
          mkdir -p /nix/var/nix/profiles/per-user
          mkdir -p /nix/var/nix/{gcroots,temproots,userpool}/per-user/1000
          
          # Set proper ownership and permissions on parent directories
          chown root:root /nix/var/nix/profiles
          chmod 755 /nix/var/nix/profiles
          
           # Make per-user directory accessible and owned by user
           chown 1000:1000 /nix/var/nix/profiles/per-user
           chmod 755 /nix/var/nix/profiles/per-user
           chown 1000:1000 /nix/var/nix/profiles/per-user/1000
           chmod 755 /nix/var/nix/profiles/per-user/1000
          
           # Remove and recreate db directory for clean single-user setup
           rm -rf /nix/var/nix/db
           mkdir -p /nix/var/nix/db
           chown 1000:1000 /nix/var/nix/db
           chmod 755 /nix/var/nix/db
          
          # Set ownership for temp dirs
          chown 1000:1000 /nix/var/nix/{gcroots,temproots,userpool}
          chmod 755 /nix/var/nix/{gcroots,temproots,userpool}
          
          # Set ownership for user's profile directories
          chown -R 1000:1000 /nix/var/nix/{gcroots,temproots,userpool}/per-user/1000
          chmod -R 755 /nix/var/nix/{gcroots,temproots,userpool}/per-user/1000
          
             # Ensure user directories exist and are owned by user
            mkdir -p /home/nixuser/.local/state /home/nixuser/.cache /home/nixuser/.local/state/nix/{db,profiles,gcroots,temproots,userpool,log}
            mkdir -p /home/nixuser/.nix-store/.links
            echo "" > /home/nixuser/.bashrc
            # Create local nix state
            mkdir -p /home/nixuser/.nix-defexpr
            chown -R 1000:1000 /home/nixuser
            chmod -R 755 /home/nixuser
        '')
        (writeScriptBin "init-container" ''
          #!/bin/bash
          # Run as root to setup permissions
          /bin/setup-permissions
        '')
        (writeScriptBin "entrypoint" ''
          #!/bin/bash
          # Setup permissions as root
          /bin/setup-permissions
          
          cd /home/nixuser
           # Switch to nixuser using setpriv with completely local store
          if [ $# -eq 0 ]; then
            exec setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/nixuser USER=nixuser NIX_REMOTE= NIX_STORE_DIR=/home/nixuser/.nix-store NIX_STATE_DIR=/home/nixuser/.local/state/nix NIX_LOG_DIR=/home/nixuser/.local/state/nix/log bash
          else
            exec setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/nixuser USER=nixuser NIX_REMOTE= NIX_STORE_DIR=/home/nixuser/.nix-store NIX_STATE_DIR=/home/nixuser/.local/state/nix NIX_LOG_DIR=/home/nixuser/.local/state/nix/log "$@"
          fi
        '')
      ];

      # No extraCommands needed - home directory setup done at runtime
      extraCommands = ''
        # All home directory setup moved to runtime to avoid permission issues
      '';

      config = {
        WorkingDir = "/home/nixuser";
        Entrypoint = [ "/bin/entrypoint" ];
        Env = [
          "HOME=/tmp"
          "USER=nixuser"
          "PATH=/bin:/usr/bin:/home/nixuser/.nix-profile/bin"
          "TMPDIR=/home/nixuser/.cache"
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
          "NIX_REMOTE_TRUSTED_PUBLIC_KEYS=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "NIX_PATH=nixpkgs=https://nixos.org/channels/nixpkgs-25.11"
          "NIX_REMOTE="
          "NIX_STORE_DIR=/home/nixuser/.nix-store"
          "UMASK=022"
        ];
      };
    };
  };
}