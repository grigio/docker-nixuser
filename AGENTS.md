# Development Guide

NOTE: Keep it updated with the most useful non-trivial dev info. Keep it minimal.

## CI Publishing (CRITICAL)

The `publish` job runs on `v*` tag push (`push: tags: ['v*']`), **not** on push to master. Push to master only runs `build` (test, no ghcr.io push). To publish:
```bash
git tag vX.Y.Z && git push origin vX.Y.Z
```
Note: Uses `push: tags` trigger, not `create` event — `git push --tags` triggers it reliably.
The tag triggers both `build` and `publish` jobs. The `publish` job builds amd64 + arm64, pushes platform-specific images, then creates multi-arch manifests (version + latest).

## Multi-Platform CI Builds

The CI workflow builds Docker images for:
- `linux/amd64` (x86_64)
- `linux/arm64` (aarch64) — built via Nix `--system aarch64-linux` with QEMU emulation

Multi-platform images use Docker manifests. Platform-specific images are tagged as:
- `ghcr.io/grigio/docker-nixuser:TAG-amd64`
- `ghcr.io/grigio/docker-nixuser:TAG-arm64`

Arm64 builds use `docker/setup-qemu-action` for QEMU binfmt registration, allowing Nix to
cross-build for `aarch64-linux` on amd64 runners via `nix build .#default --system aarch64-linux`.

## Flake Auto-Update

The `flake-update-check.yml` workflow runs weekly (Sunday 2 AM UTC) and:
1. Checks if `flake.lock` is up to date
2. Updates GitHub status check
3. Automatically creates a pull request if updates are available

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

## Overlayfs Permission Pitfalls (CRITICAL)

Docker images run on overlayfs in CI. `chown` on lower-layer files triggers copy-up of file contents and is unreliable. `chmod` only copies metadata and works reliably. Rules:

- **DO** use `chmod` to make files/dirs writable (e.g., `chmod -R a+w /nix/store`)
- **DO NOT** use `chown -R` on `/nix/store` — fails silently on overlayfs, causing "Permission denied" errors
- `/nix/var` is small, so `chown -R 1000:1000 /nix/var` works fine there
- When nix needs access to store paths (lock files, substitution), use `chmod` not `chown`
- Pre-create all per-user directories (`gcroots/per-user/1000`, etc.) at build time in `create-dirs` to avoid runtime creation failures

## Single-Layer Image with buildImage

The image uses `pkgs.dockerTools.buildImage` (not `buildLayeredImage`), producing exactly **1 Docker layer** (previously ~99 layers with `buildLayeredImage`).

### How It Works

`buildImage` with `copyToRoot`:
1. Each store path is **re-rooted** via `rsync` — files appear at standard paths (e.g., `/bin/bash`, `/etc/nix/nix.conf`)
2. The full Nix store paths (`/nix/store/hash-...`) are also included from the closure
3. `uid = 1000; gid = 1000` sets ownership on the re-rooted layer files
4. Everything goes into a single Docker layer

### Runtime Permissions

All files in the single layer are owned by 1000:1000. The Nix store paths (from closure) remain root:root. The `setup-permissions` script handles this:
- `chmod a+w /nix/store /nix/store/.links` — makes store itself writable (NOT recursive: 111k files on overlayfs is extremely slow)
- `chown -R 1000:1000 /nix/var` — small dir, fast chown
- `chown -R 1000:1000 /home/nixuser` — small dir, fast chown

This is overlayfs-safe: no `chown` on `/nix/store`.

### Performance Pitfalls

- **Never use `chmod -R` on `/nix/store`**: The image has ~111k files under `/nix/store`. Recursive chmod on overlayfs triggers a metadata copy-up for every file, taking minutes. Only `/nix/store` and `/nix/store/.links` need write permissions (Nix creates new store paths there; existing paths are read-only).
