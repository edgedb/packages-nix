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
      systems =
        [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      perSystem = { config, system, ... }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mk_edgedb_server = source:
            pkgs.stdenvNoCC.mkDerivation {
              name = "edgedb-server";
              buildInputs = [ ];
              nativeBuildInputs = [ pkgs.zstd ]
                ++ pkgs.lib.optionals (!pkgs.stdenv.isDarwin)
                [ pkgs.autoPatchelfHook ];
              dontPatchELF = pkgs.stdenv.isDarwin;
              dontFixup = pkgs.stdenv.isDarwin;
              src = pkgs.fetchurl source;
              installPhase = ''
                mkdir $out
                cp -r ./* $out
              '';
            };

          fetchEdgeDBServer = { platform, version }:
            let
              jsonURL =
                "https://packages.edgedb.com/archive/.jsonindexes/${platform}.json";
              jsonFile = builtins.fetchurl jsonURL;
              json = builtins.fromJSON (builtins.readFile jsonFile);
              package = builtins.head (builtins.filter (p:
                p.basename == "edgedb-server" && p.version_details.major
                == version.major && p.version_details.minor == version.minor)
                json.packages);
              installRef = builtins.head
                (builtins.filter (i: i.encoding == "zstd") package.installrefs);
            in {
              url = "https://packages.edgedb.com" + installRef.ref;
              sha256 = installRef.verification.sha256;
            };

          edgedbPlatform = {
            x86_64-linux = "x86_64-unknown-linux-gnu";
            aarch64-linux = "aarch64-unknown-linux-gnu";
            x86_64-darwin = "x86_64-apple-darwin";
            aarch64-darwin = "aarch64-apple-darwin";
          }.${system};

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
          packages.edgedb-server = mk_edgedb_server (fetchEdgeDBServer {
            platform = edgedbPlatform;
            version = {
              major = 5;
              minor = 3;
            };
          });
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
