# Development Guide

NOTE: Keep it updated with the most useful non-trivial dev info. Keep it minimal.

## Docker Image

The project creates a Docker image with Nix package manager running as non-root user `nixuser`.

### Build
```bash
nix --extra-experimental-features 'nix-command flakes' build .#default
```

### Load Image
```bash
docker load < result
```

### Run Container
```bash
docker run -it nix-nixuser:latest
```

### Test Nix Installation
```bash
docker run --rm nix-nixuser:latest sh -c 'whoami && nix profile add nixpkgs#hello && hello'
```
Expected output:
```
nixuser
Hello, world!
```


## Development Commands

- Build: `nix --extra-experimental-features 'nix-command flakes' build .#default`
- Load: `docker load < result`
- Test: `docker run --rm nix-nixuser:latest sh -c 'whoami && nix --version'`
- Test package installation: `docker run --rm nix-nixuser:latest sh -c 'whoami && nix profile add nixpkgs#hello && hello'`

## Container Configuration Details
- User: `nixuser` (UID/GID: 1000)
- Working directory: `/home/nixuser`
- Environment variables:
  - `TMPDIR=/home/nixuser/.cache`
  - `SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt`
  - `NIX_REMOTE_TRUSTED_PUBLIC_KEYS=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=`
- Entrypoint sets up proper directory permissions before switching to nixuser
- Note: Home directory ownership issue resolved by setting HOME=/tmp in environment, allowing Nix to fall back to the properly owned /home/nixuser without warnings.