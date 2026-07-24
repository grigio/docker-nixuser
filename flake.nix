{
  description = "NixOS Docker with user Nix Access";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = inputs@{ self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.dockerTools.buildImage {
            name = "nix-nixuser";
            tag = "latest";
            uid = 1000;
            gid = 1000;

            copyToRoot = with pkgs; [
              bashInteractive
              coreutils
              nix
              cacert
              shadow
              util-linux
              sudo
              procps
              gnugrep
              gnused
              which
              findutils
              iputils
              gnumake
              curl
              bun
              uv
              nano
              git
              opencode

              (writeTextDir "etc/nix/nix.conf" "experimental-features = nix-command flakes\nsubstituters = https://cache.nixos.org/\ntrusted-users = root nixuser\nsandbox = false\nbuild-users-group =\nssl-cert-file = ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt\nrequire-sigs = false\n")
              (writeTextDir "etc/passwd" "root:x:0:0::/root:/bin/bash\nnixuser:x:1000:1000::/home/nixuser:/bin/bash\n")
              (writeTextDir "etc/group" "root:x:0:\nnixuser:x:1000:\nnixbld:x:30000:1000\n")
              (writeTextDir "root/.bashrc" "")

              (runCommand "create-dirs" { } ''
                mkdir -p $out/nix/store/.links
                mkdir -p $out/nix/var/nix/{db,profiles,gcroots,temproots,userpool}
                mkdir -p $out/nix/var/nix/profiles/per-user/1000
                mkdir -p $out/nix/var/nix/{gcroots,temproots,userpool}/per-user/1000
                mkdir -p $out/home/nixuser
              '')
              (writeScriptBin "setup-permissions" ''
                #!/bin/bash
                chown -R 1000:1000 /nix/var
                chmod -R 755 /nix/var
                chmod a+w /nix/store /nix/store/.links
                mkdir -p /home/nixuser/.local/state /home/nixuser/.cache
                echo "" > /home/nixuser/.bashrc
                chown -R 1000:1000 /home/nixuser
                chmod -R 755 /home/nixuser
              '')
              (writeScriptBin "entrypoint" ''
                #!/bin/bash
                /bin/setup-permissions
                cd /home/nixuser
                if [ $# -eq 0 ]; then
                  exec setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/nixuser USER=nixuser NIX_REMOTE= bash
                else
                  exec setpriv --reuid=1000 --regid=1000 --init-groups env HOME=/home/nixuser USER=nixuser NIX_REMOTE= "$@"
                fi
              '')
            ];

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
        });
    };
}
