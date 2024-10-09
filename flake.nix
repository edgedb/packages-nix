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
            in craneLib.buildPackage {
              strictDeps = true;

              src = craneLib.cleanCargoSource (pkgs.fetchgit source);
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
            });
        in {
          packages.edgedb-server = mk_edgedb_server {
            source = {
              x86_64-linux = {
                url = "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu/edgedb-server-5.6+51fd5fe.tar.zst";
                sha256 = "f3e06e6da9902aef062bd14849e7fbf0b3c30f0c0d136cda6bf05a407b9f8438";
              };
              aarch64-linux = {
                url = "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu/edgedb-server-5.6+01f1f64.tar.zst";
                sha256 = "f806ddf159eca3fb703861d52e7c343232ee076164d901a7129fb9742ea8ff70";
              };
              x86_64-darwin = {
                url = "https://packages.edgedb.com/archive/x86_64-apple-darwin/edgedb-server-5.6+9d333f3.tar.zst";
                sha256 = "9a9dbcb6e3feb76bdb2d58e30e99c8a33c321b36a08fbe8d51fce3f162392982";
              };
              aarch64-darwin = {
                url = "https://packages.edgedb.com/archive/aarch64-apple-darwin/edgedb-server-5.6+adb9e77.tar.zst";
                sha256 = "96fa55deaacaf4b7362c7cef6c1f83704262ccd1b9a69d0674b2bec8f2e9989c";
              };
            }.${system};
          };
          packages.edgedb-server-nightly = mk_edgedb_server {
            source = {
              x86_64-linux = {
                url = "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu/edgedb-server-5.6+51fd5fe.tar.zst";
                sha256 = "f3e06e6da9902aef062bd14849e7fbf0b3c30f0c0d136cda6bf05a407b9f8438";
              };
              aarch64-linux = {
                url = "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu/edgedb-server-5.6+01f1f64.tar.zst";
                sha256 = "f806ddf159eca3fb703861d52e7c343232ee076164d901a7129fb9742ea8ff70";
              };
              x86_64-darwin = {
                url = "https://packages.edgedb.com/archive/x86_64-apple-darwin/edgedb-server-5.6+9d333f3.tar.zst";
                sha256 = "9a9dbcb6e3feb76bdb2d58e30e99c8a33c321b36a08fbe8d51fce3f162392982";
              };
              aarch64-darwin = {
                url = "https://packages.edgedb.com/archive/aarch64-apple-darwin/edgedb-server-5.6+adb9e77.tar.zst";
                sha256 = "96fa55deaacaf4b7362c7cef6c1f83704262ccd1b9a69d0674b2bec8f2e9989c";
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
