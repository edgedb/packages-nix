{
  description = "edgedb-server";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, crane, ... }:
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

          mk_artifact = { name, url }:
            pkgs.stdenvNoCC.mkDerivation {
              name = name;
              buildInputs = with pkgs; [ ];
              nativeBuildInputs = with pkgs;
                [ zstd ]
                ++ lib.optionals (!pkgs.stdenv.isDarwin) [ autoPatchelfHook ];

              dontPatchELF = pkgs.stdenv.isDarwin;
              dontFixup = pkgs.stdenv.isDarwin;
              src = pkgs.fetchurl url;
              installPhase = ''
                mkdir $out
                cp -r ./* $out
              '';
            };

          mk_edgedb_cli = { source }:
            (let
              inherit (pkgs) lib;

              craneLib = crane.mkLib pkgs;

              commonArgs = {
                src = craneLib.cleanCargoSource (pkgs.fetchgit source);
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
            in craneLib.buildPackage (commonArgs // {
              cargoArtifacts = craneLib.buildDepsOnly commonArgs;
            }));

            artifacts = import ./artifacts.nix;
        in {
          packages.edgedb-server = mk_artifact {
            name = "edgedb-server";
            url = artifacts.edgedb-server.${system};
          };
          packages.edgedb-server-nightly = mk_artifact {
            name = "edgedb-server";
            url = artifacts.edgedb-server-nightly.${system};
          };
          packages.gel-server-testing = mk_artifact {
            name = "gel-server";
            url = artifacts.gel-server-testing.${system};
          };
          packages.gel-ls = mk_artifact {
            name = "gel-ls";
            url = artifacts.gel-ls.${system};
          };

          packages.edgedb-cli = mk_edgedb_cli {
            source = {
              url = "https://github.com/edgedb/edgedb-cli";
              rev = "v5.5.2";
              hash = "sha256-CSs1Ql0zsGgSmZrlZIfj2pJdtAax7HUlfCq8oTbReng=";
            };
          };

          devShells.default = pkgs.mkShell {
            buildInputs = [
              pkgs.python312Packages.python
              pkgs.python312Packages.requests
              pkgs.python312Packages.jedi-language-server
              # pkgs.python312Packages.python-lsp-server
            ];
          };
        };
    };
}
