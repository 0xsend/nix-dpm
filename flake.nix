{
  description = "Digital Asset Package Manager (dpm) - Nix package and overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Overlay that adds dpm to pkgs
      overlay = final: prev: {
        dpm = final.callPackage ./dpm.nix { };
      };

      # Systems to build for
      supportedSystems = [
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      # Export the overlay for use in other flakes
      overlays.default = overlay;
      overlays.dpm = overlay;
    }
    //
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        # Expose dpm as a package
        packages = {
          default = pkgs.dpm;
          dpm = pkgs.dpm;
        };

        # Development shell with dpm available
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.dpm ];

          shellHook = ''
            echo "dpm $(dpm version --active 2>/dev/null || echo ${pkgs.dpm.version}) available"
          '';
        };

        # Allow `nix run` to execute dpm
        apps.default = flake-utils.lib.mkApp {
          drv = pkgs.dpm;
        };
      }
    );
}
