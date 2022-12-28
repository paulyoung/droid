{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    flake-utils,
    rust-overlay
  }:
    let
      supportedSystems = [
        flake-utils.lib.system.aarch64-darwin
        flake-utils.lib.system.x86_64-darwin
      ];
    in
      flake-utils.lib.eachSystem supportedSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (import rust-overlay)
            ];
          };

          rust = pkgs.rust-bin.stable.latest.default;

          # NB: we don't need to overlay our custom toolchain for the *entire*
          # pkgs (which would require rebuilding anything else which uses rust).
          # Instead, we just want to update the scope that crane will use by
          # appending our specific toolchain there.
          craneLib = (crane.mkLib pkgs).overrideToolchain rust;

          src = ./.;

          cargoArtifacts = craneLib.buildDepsOnly {
            inherit src;
            nativeBuildInputs = [
              pkgs.cmake
              pkgs.darwin.apple_sdk.frameworks.Security
            ];
          };

          droid = craneLib.buildPackage {
            inherit cargoArtifacts src;
            nativeBuildInputs = [
              pkgs.darwin.apple_sdk.frameworks.AppKit
              pkgs.darwin.apple_sdk.frameworks.DiskArbitration
              pkgs.darwin.apple_sdk.frameworks.Foundation
              pkgs.darwin.apple_sdk.frameworks.OpenGL
            ];
          };

          apps = {
            droid = flake-utils.lib.mkApp {
              drv = droid;
            };
          };
        in
          rec {
            checks = {
              inherit droid;
            };

            packages = {
              inherit droid;
            };

            inherit apps;

            defaultPackage = packages.droid;

            defaultApp = apps.droid;

            devShell = pkgs.mkShell {
              RUST_SRC_PATH = pkgs.rust.packages.stable.rustPlatform.rustLibSrc;
              inputsFrom = builtins.attrValues checks;
              nativeBuildInputs = pkgs.lib.foldl
                (state: drv: builtins.concatLists [state drv.nativeBuildInputs])
                []
                (pkgs.lib.attrValues packages)
              ;
            };
          }
      );
}
