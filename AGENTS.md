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
- `linux/arm64` (aarch64)

Multi-platform images use Docker manifests. Platform-specific images are tagged as:
- `ghcr.io/grigio/docker-nixuser:TAG-amd64`
- `ghcr.io/grigio/docker-nixuser:TAG-arm64`

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
- Note: Home directory ownership issue resolved by setting HOME=/tmp in environment, allowing Nix to fall back to the properly owned /home/nixuser without warnings.

## Overlayfs Permission Pitfalls (CRITICAL)

Docker images run on overlayfs in CI. `chown` on lower-layer files triggers copy-up of file contents and is unreliable. `chmod` only copies metadata and works reliably. Rules:

- **DO** use `chmod` to make files/dirs writable (e.g., `chmod -R a+w /nix/store`)
- **DO NOT** use `chown -R` on `/nix/store` — fails silently on overlayfs, causing "Permission denied" errors
- `/nix/var` is small, so `chown -R 1000:1000 /nix/var` works fine there
- When nix needs access to store paths (lock files, substitution), use `chmod` not `chown`
- Pre-create all per-user directories (`gcroots/per-user/1000`, etc.) at build time in `create-dirs` to avoid runtime creation failures

## buildLayeredImage uid/gid Limitation

`buildLayeredImage { uid = 1000; gid = 1000; }` only applies uid/gid to **store layers**, NOT the **customisation layer** (which contains files from `writeTextDir`, `runCommand`, `writeScriptBin`, etc.). The customisation layer always uses root:root. This means:
- Store paths (bash, nix, etc.) — owned by 1000:1000, no `chown` needed at runtime
- `/nix/var`, `/home`, `/etc`, scripts — owned by root:root, must be `chown`-ed in `setup-permissions`
- Use `chown -R 1000:1000 /nix/var` (small dir, fast) — no need for `chown -R /nix/store` (huge, slow, broken on overlayfs)
