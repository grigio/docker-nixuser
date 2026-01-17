{
  description = "NixOS Docker with user Nix Access";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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

        opencode
        curl

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
          # Setup permissions for user operations with standard store
          mkdir -p /nix/store/.links
          
          # Create and set permissions for nix/var directory structure
          mkdir -p /nix/var/nix/{db,profiles,gcroots,temproots,userpool}
          mkdir -p /nix/var/nix/profiles/per-user/1000
          
          # Make nixuser owner of the entire nix directory structure
          chown -R 1000:1000 /nix
          chmod -R 755 /nix
          
             # Ensure user directories exist and are owned by user
             mkdir -p /home/nixuser/.local/state /home/nixuser/.cache
             echo "" > /home/nixuser/.bashrc
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
           # Switch to nixuser using setpriv with standard store location
           if [ $# -eq 0 ]; then
             exec setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/nixuser USER=nixuser NIX_REMOTE= bash
           else
             exec setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/nixuser USER=nixuser NIX_REMOTE= "$@"
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
          "NIX_PATH=nixpkgs=${inputs.nixpkgs}"
           "NIX_REMOTE="
           "UMASK=022"
        ];
      };
    };
  };
}