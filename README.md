# docker-nixuser


A lightweight Docker image providing a full Nix package manager environment for non-root users. Perfect for testing Nix packages in an isolated sandbox (~223MB), with optional data persistence through volume mounting.

![CI](https://github.com/grigio/docker-nixuser/workflows/CI/badge.svg)

## Features

- Non-root user `nixuser` (UID/GID: 1000)
- Nix package manager with flakes support
- Proper SSL certificate configuration
- User profile setup for package management

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes support enabled
- [Docker](https://docs.docker.com/get-docker/) for running the container

## Quick Start

### 1. Build the Image

Build the Docker image using Nix flakes (this may take a few minutes on first run):

```bash
nix --extra-experimental-features 'nix-command flakes' build .#default
```

### 2. Load the Image

Load the built image into Docker:

```bash
docker load < result
```

### 3. Run the Container

Just to test

```bash
docker run -it --rm nix-nixuser:latest
```

Or specify a command:

```bash
docker compose up -d --remove-orphans
docker compose attach nixuser bash
cd  /data && nix profile add nixpkgs#opencode && opencode --hostname 0.0.0.0 --port 8000
```

### 4. Test Nix Installation

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

## Development

See [AGENTS.md](AGENTS.md) for development notes and internal configuration details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.