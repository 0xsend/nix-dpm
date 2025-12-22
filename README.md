# nix-dpm

Nix flake for the [Digital Asset Package Manager (dpm)](https://docs.digitalasset.com/build/3.4/dpm/dpm.html) - the official CLI tool for the DAML SDK.

## What is dpm?

`dpm` is a drop-in replacement for the now-deprecated `daml` assistant. It provides commands for:

- **Building DAML projects**: `dpm build`
- **Running tests**: `dpm test`
- **Code generation**: `dpm codegen-java`, `dpm codegen-js`, `dpm codegen-alpha-typescript`
- **Running sandbox**: `dpm sandbox`
- **Managing SDK versions**: `dpm install`, `dpm version`
- **And more**: `dpm studio`, `dpm new`, `dpm docs`, etc.

## Installation

### Using as an overlay (recommended)

Add this flake to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-dpm.url = "github:your-org/nix-dpm";  # Update with actual repo
  };

  outputs = { self, nixpkgs, nix-dpm, ... }:
    let
      system = "aarch64-darwin";  # or your system
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nix-dpm.overlays.default ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.dpm ];
      };
    };
}
```

### Direct package reference

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-dpm.url = "github:your-org/nix-dpm";  # Update with actual repo
  };

  outputs = { self, nixpkgs, nix-dpm, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ nix-dpm.packages.${system}.default ];
      };
    };
}
```

### Run directly with nix run

```bash
nix run github:your-org/nix-dpm -- build
nix run github:your-org/nix-dpm -- test
```

### Enter a shell with dpm

```bash
nix develop github:your-org/nix-dpm
```

## Supported Platforms

| Platform | Architecture |
|----------|--------------|
| macOS    | arm64 (M1/M2/M3) |
| macOS    | amd64 (Intel) |
| Linux    | amd64 |
| Linux    | arm64 |

## Automated Updates

This repository automatically checks for new dpm releases daily via GitHub Actions. When a new version is detected:

1. **Check**: Fetches latest version from Digital Asset
2. **Hash**: Downloads all platform tarballs and computes SHA256 hashes
3. **Verify**: Builds and tests on all 4 platforms (Linux x86_64, Linux ARM64, macOS x86_64, macOS ARM64)
4. **Commit**: Auto-commits the update if all builds pass

You can also manually trigger an update via the GitHub Actions UI.

## Security Model

Digital Asset does not currently provide GPG signatures or published checksums for dpm releases. The security model relies on:

| Layer | Protection |
|-------|------------|
| **Transport** | HTTPS to Google Artifact Registry |
| **Storage** | Google Cloud infrastructure integrity |
| **Verification** | SHA256 hashes computed at packaging time |
| **Nix Store** | Content-addressed storage (hash becomes the identity) |
| **CI Checks** | Build verification on all 4 platforms before commit |
| **Runtime Check** | Binary version must match expected version |

Once hashes are committed, Nix's content-addressed store ensures you always get the exact same binary.

## Manual Updates

To manually update to a new version:

```bash
./scripts/update-version.sh           # Latest version
./scripts/update-version.sh 3.4.10    # Specific version
```

Or manually:

1. Get the latest version:
   ```bash
   curl -sS https://get.digitalasset.com/install/latest
   ```

2. Run the update script or manually compute hashes:
   ```bash
   VERSION="X.Y.Z"
   for PLATFORM in darwin-arm64 darwin-amd64 linux-amd64 linux-arm64; do
     TARBALL="dpm-${VERSION}-${PLATFORM}.tar.gz"
     URL="https://artifactregistry.googleapis.com/download/v1/projects/da-images/locations/europe/repositories/public-generic/files/dpm-sdk:${VERSION}:${TARBALL}:download?alt=media"
     echo "${PLATFORM}:"
     curl -SLf "${URL}" | shasum -a 256
   done
   ```

3. Update `dpm-sources.json` with the new version and hashes

4. Test the build:
   ```bash
   nix build .#dpm
   ./result/bin/dpm version
   ```

## Project Structure

```
nix-dpm/
├── .github/
│   └── workflows/
│       ├── ci.yml             # Build verification on PR/push
│       └── update-dpm.yml     # Daily auto-update workflow
├── scripts/
│   └── update-version.sh      # Version update script
├── flake.nix                  # Nix flake with overlay and packages
├── flake.lock                 # Locked dependencies
├── dpm.nix                    # Package derivation for dpm
├── dpm-sources.json           # Version and SHA256 hashes
└── README.md                  # This file
```

## License

This Nix packaging is provided under the Apache 2.0 license. The dpm tool itself is distributed by Digital Asset under their license terms.
