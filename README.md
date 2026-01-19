# docker-nixuser


A lightweight Docker image providing a full Nix package manager environment for non-root users. Perfect for testing Nix packages in an isolated sandbox (~223MB), with optional data persistence through volume mounting.

![CI](https://github.com/grigio/docker-nixuser/workflows/CI/badge.svg)
![flake.lock](https://github.com/grigio/docker-nixuser/actions/workflows/flake-update-check.yml/badge.svg)
![Multi-platform](https://img.shields.io/badge/platforms-linux%2Famd64%2C%20linux%2Farm64-blue)

**UPDATE**: If you want a more light and mainstream approch you can use the official opencode alpine container with a few tweaks https://github.com/grigio/opencode-alpine-box

## Features

- Non-root user `nixuser` (UID/GID: 1000)
- Nix package manager with flakes support
- Proper SSL certificate configuration
- User profile setup for package management

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes support enabled
- [Docker](https://docs.docker.com/get-docker/) for running the container

## Quick Start

### Option 1: Pull from GitHub Container Registry (Recommended)

Pull the pre-built image from GHCR:

```bash
# Pull latest release (auto-selects architecture)
docker run --rm ghcr.io/grigio/docker-nixuser:latest sh -c 'whoami && nix profile add nixpkgs#hello && hello'

# Pull specific version (auto-selects architecture)
docker run --rm ghcr.io/grigio/docker-nixuser:0.0.1 sh -c 'whoami && nix profile add nixpkgs#hello && hello'

# Pull specific architecture explicitly
docker run --rm ghcr.io/grigio/docker-nixuser:latest-amd64 sh -c 'whoami && nix profile add nixpkgs#hello && hello'
docker run --rm ghcr.io/docker-nixuser:latest-arm64 sh -c 'whoami && nix profile add nixpkgs#hello && hello'
```

### Option 2: Build Locally

Build the Docker image using Nix flakes (this may take a few minutes on first run):

```bash
nix --extra-experimental-features 'nix-command flakes' build .#default
```

Load the built image into Docker:

```bash
docker load < result
```

### Run the Container

Just to test:

```bash
docker run -v ./data:/data --rm -ti ghcr.io/grigio/docker-nixuser:latest sh -c "cd /data && opencode"

```

Or specify a command:

```bash
docker compose up -d --remove-orphans
docker compose run --remove-orphans nixuser bash -c "cd /data && opencode"
```

### Test Nix Installation

Verify the setup by installing and running a test package:

```bash
docker run --rm nix-nixuser:latest sh -c 'whoami && nix profile add nixpkgs#hello && hello'
```

Expected output:
```
nixuser
Hello, world!
```

## Usage

### Installing Packages

Inside the container, install packages using Nix:

```bash
# Install a package
nix profile add nixpkgs#git

# List installed packages
nix profile list

# Run the package
git --version
```

### Data Persistence

The `./data` directory is mounted at `/data` in the container for persisting files between runs.

## Troubleshooting

### Build Issues
- Ensure Nix experimental features are enabled: `nix --extra-experimental-features 'nix-command flakes'`
- Check that Docker is running and accessible

### Runtime Issues
- If Nix commands fail, verify the container has internet access for package downloads
- Permission errors may occur if the image wasn't built with proper user setup

### Nix Daemon
- The container automatically starts the Nix daemon; wait a moment after startup if commands hang

### SSL Certificate Errors
- The image includes CA certificates; if issues persist, check your host's certificate setup

## Release Process

This project uses automated releases through GitHub Actions:

1. **Development**: Make changes and push to `master` branch
2. **Tag**: Create a version tag: `git tag v0.0.2`
3. **Push tag**: `git push origin v0.0.2`
4. **Automatic**: CI builds, tests, and publishes multi-platform images to GitHub Container Registry

**Available Images:**
- `ghcr.io/grigio/docker-nixuser:latest` - Latest release (multi-arch manifest)
- `ghcr.io/grigio/docker-nixuser:0.0.1` - Specific version (multi-arch manifest)
- `ghcr.io/grigio/docker-nixuser:0.0.2` - Latest version (multi-arch manifest)
- `ghcr.io/grigio/docker-nixuser:latest-amd64` - Latest amd64 only
- `ghcr.io/grigio/docker-nixuser:latest-arm64` - Latest arm64 only

## Development

See [AGENTS.md](AGENTS.md) for development notes and internal configuration details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.