{
  description = "edgedb-server";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, crane, fenix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem = { config, system, ... }:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          mk_edgedb_server = { source }:
            pkgs.stdenvNoCC.mkDerivation {
              name = "edgedb-server";
              buildInputs = with pkgs; [ ];
              nativeBuildInputs = with pkgs;
                [ zstd ]
                ++ lib.optionals (!pkgs.stdenv.isDarwin) [ autoPatchelfHook ];

              dontPatchELF = pkgs.stdenv.isDarwin;
              dontFixup = pkgs.stdenv.isDarwin;
              src = pkgs.fetchurl source;
              installPhase = ''
                mkdir $out
                cp -r ./* $out
              '';
            };

          mk_edgedb_cli = { source }:
            (let
              inherit (pkgs) lib;

              craneLib = crane.lib.${system};
              src = craneLib.cleanCargoSource (pkgs.fetchgit source);

              commonArgs = {
                inherit src;
                strictDeps = true;

                nativeBuildInputs = [ pkgs.pkg-config ];

                buildInputs = [ pkgs.openssl pkgs.perl ]
                  ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];

                # we use native-tls/vendored, but here we override that so cargo does not try to build it
                # since it lacks a proper build env
                OPENSSL_NO_VENDOR = true;

                # don't check as we rely on GitHub Action tests for correctness
                # running clippy and tests here would require:
                # - starting edgedb-server,
                # - cloning shared-client-testcases git submodule, so shared-client-test
                #   crate can be generated
                doCheck = false;
              };

              # Build *just* the cargo dependencies, so we can reuse
              # all of that work (e.g. via cachix) when running in CI
              cargoArtifacts = craneLib.buildDepsOnly commonArgs;
            in craneLib.buildPackage
            (commonArgs // { inherit cargoArtifacts; }));

        in {
          packages.edgedb-server = mk_edgedb_server {
            source = {
              x86_64-linux = {
                url = "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu/edgedb-server-5.3+cc878d8.tar.zst";
                sha256 = "b2009ff44b9a30941aa58311a0327f3b81922b16000d8831cd8cfcd061bba2f8";
              };
              aarch64-linux = {
                url = "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu/edgedb-server-5.3+f424d2d.tar.zst";
                sha256 = "0ed2990b57f5f9692d0c99f225e6947ca6aedaaeb932ba82c8915b37066f8c4a";
              };
              x86_64-darwin = {
                url = "https://packages.edgedb.com/archive/x86_64-apple-darwin/edgedb-server-5.3+f3aa580.tar.zst";
                sha256 = "dc7a41bf457846e5e751816bdfa17d87ec01db4dedae73c78bfa3c5d8cd1fef9";
              };
              aarch64-darwin = {
                url = "https://packages.edgedb.com/archive/aarch64-apple-darwin/edgedb-server-5.3+a480d96.tar.zst";
                sha256 = "cde32a355333cca83b35afa7a04b68f857a6d8d0f372a31745cdcd2509b63861";
              };
            }.${system};
          };

          packages.edgedb-cli = mk_edgedb_cli {
            source = {
              url = "https://github.com/edgedb/edgedb-cli";
              rev = "v5.1.0";
              hash = "sha256-znxAtfSeepLQqkPsEzQBp3INZym5BLap6m29C/9z+h8=";
            };
          };
        };
    };
}
