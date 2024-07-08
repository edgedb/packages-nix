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
                url = "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu/edgedb-server-5.5+8309006.tar.zst";
                sha256 = "9857f410e8ba194f458ab67df47f0652a23baaf54de9eca8ab6eac183ad209d4";
              };
              aarch64-linux = {
                url = "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu/edgedb-server-5.5+9a0d56f.tar.zst";
                sha256 = "09f0ec5ddec508be7cca9578f3e2ad34541ff45d90a34a161ba269c6dd2f56ac";
              };
              x86_64-darwin = {
                url = "https://packages.edgedb.com/archive/x86_64-apple-darwin/edgedb-server-5.5+c737136.tar.zst";
                sha256 = "00a839dca0af2e835553cd4e84624aa62d76351c99453f14c8741f8a678651ee";
              };
              aarch64-darwin = {
                url = "https://packages.edgedb.com/archive/aarch64-apple-darwin/edgedb-server-5.5+3bf8eae.tar.zst";
                sha256 = "c78afaa3f9fb2fe1516b3e03a950e41b1b5ee6607273f79b6270571e552258b6";
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
