# nix-nixuser

A Docker image that provides a Nix package manager environment running as a non-root user (`nixuser`).

## Overview

This project builds a minimal Docker image with Nix installed and configured to run under a non-root user. The image is designed for development and testing environments where you need Nix functionality without root privileges.

## Features

- Non-root user `nixuser` (UID/GID: 1000)
- Nix package manager with flakes support
- Proper SSL certificate configuration
- User profile setup for package management

## Quick Start

### 1. Build the Image

```bash
nix --extra-experimental-features 'nix-command flakes' build .#default
```

### 2. Load the Image

```bash
docker load < result
```

### 3. Run the Container

```bash
docker run -it --rm nix-nixuser:latest
docker run -it --rm nix-nixuser:latest bash
```

### 4. Test Nix Installation

```bash
docker run --rm nix-nixuser:latest sh -c 'whoami && nix profile add nixpkgs#hello && hello'
```

Expected output:
```
nixuser
Hello, world!
```

## Configuration

- **User**: `nixuser` (UID/GID: 1000)
- **Working Directory**: `/home/nixuser`
- **Environment Variables**:
  - `HOME=/tmp` (falls back to user home for Nix operations)
  - `USER=nixuser`
  - `PATH=/bin:/usr/bin:/home/nixuser/.nix-profile/bin`
  - `TMPDIR=/home/nixuser/.cache`
  - `SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt`
  - `NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt`
  - `NIX_REMOTE_TRUSTED_PUBLIC_KEYS=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=`
  - `NIX_PATH=nixpkgs=https://nixos.org/channels/nixpkgs-unstable`
  - `UMASK=022`

## Development

See [AGENTS.md](AGENTS.md) for development notes and internal configuration details.</content>
<parameter name="filePath">/home/grigio/Code/nixdev/README.md