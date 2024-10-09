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
                url = "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu.nightly/edgedb-server-6.0-dev.8863+a0a475a.tar.zst";
                sha256 = "b2f5f72ea57a42c0178fb2f86b2630c65d787b4128e00086f1f801ac15096e4e";
              };
              aarch64-linux = {
                url = "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu.nightly/edgedb-server-6.0-dev.8835+2b65754.tar.zst";
                sha256 = "d56b6fdb91f8d3dd5ea88a81361f8566805186c72f9c4031d0411ff48c935da1";
              };
              x86_64-darwin = {
                url = "https://packages.edgedb.com/archive/x86_64-apple-darwin.nightly/edgedb-server-6.0-dev.8865+ef5f171.tar.zst";
                sha256 = "277f4727e97b8db001065af233bbddd7e4a49300ad34fe698f7666765b1ad98d";
              };
              aarch64-darwin = {
                url = "https://packages.edgedb.com/archive/aarch64-apple-darwin.nightly/edgedb-server-6.0-dev.8865+d0f459d.tar.zst";
                sha256 = "587254ded2f6e0dae6b644bf5b934d1bf067c73899b8eb91ffa7c6334784c48b";
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
