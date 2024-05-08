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
                url =
                  "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu/edgedb-server-4.5%2B28216a1.tar.zst";
                sha256 = "sha256-xu1Zg6QEGdbDixUvfclz1unJMLLmVo0nkjfC9tThPpg=";
              };
              x86_64-darwin = {
                url =
                  "https://packages.edgedb.com/archive/x86_64-apple-darwin/edgedb-server-4.5%2B9324bab.tar.zst";
                sha256 = "07y48ikfcrfaswlhnn0k24q8l3y44y3a8naqpvry5pv3z02pmhb0";
              };
              aarch64-linux = {
                url =
                  "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu/edgedb-server-4.5%2B4294eaf.tar.zst";
                sha256 = "17igv222xsybs479l5glqmxazmh84idd8afkrbpn5i93s7ybzqnn";
              };
              aarch64-darwin = {
                url =
                  "https://packages.edgedb.com/archive/aarch64-apple-darwin/edgedb-server-4.5%2B641a8f3.tar.zst";
                sha256 = "13yfj95kjhfi51cilccr6a9sbh3f15zc5944kz8br9mir694rd1m";
              };
            }.${system};
          };
          packages.edgedb-server-5_0_beta = mk_edgedb_server {
            source = {
              x86_64-linux = {
                url =
                  "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu.testing/edgedb-server-5.0-beta.2%2Bb09e6c0.tar.zst";
                sha256 = "sha256-cNxf91ic+vT/w1feWUUgtf+Djm8qi+DUI+qioU9uV4s=";
              };
              aarch64-linux = {
                url =
                  "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu.testing/edgedb-server-5.0-beta.2%2Bdf6373c.tar.zst";
                sha256 = "1dj3mbzjd5cg1wqzs9d354ja2xs564iynkywwxsijh6ch7fqqdvj";
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
