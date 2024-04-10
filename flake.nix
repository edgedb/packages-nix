{
  description = "edgedb-server";
  inputs = {    
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem = let
        sources = {
          v4_5 = {
            x86_64-linux = {
              url = "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu/edgedb-server-4.5%2B28216a1.tar.zst";
              hash = "sha256-xu1Zg6QEGdbDixUvfclz1unJMLLmVo0nkjfC9tThPpg=";
            };
            x86_64-darwin = {
              url = "https://packages.edgedb.com/archive/x86_64-apple-darwin/edgedb-server-4.5%2B9324bab.tar.zst";
              hash = "07y48ikfcrfaswlhnn0k24q8l3y44y3a8naqpvry5pv3z02pmhb0";
            };
            aarch64-linux = {
              url = "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu/edgedb-server-4.5%2B4294eaf.tar.zst";
              hash = "17igv222xsybs479l5glqmxazmh84idd8afkrbpn5i93s7ybzqnn";
            };
            aarch64-darwin = {
              url = "https://packages.edgedb.com/archive/aarch64-apple-darwin/edgedb-server-4.5%2B641a8f3.tar.zst";
              hash = "13yfj95kjhfi51cilccr6a9sbh3f15zc5944kz8br9mir694rd1m";
            };
          };
          v5_0_beta = {
            x86_64-linux = {
              url = "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu.testing/edgedb-server-5.0-beta.2%2Bb09e6c0.tar.zst";
              hash = "sha256-cNxf91ic+vT/w1feWUUgtf+Djm8qi+DUI+qioU9uV4s=";
            };
            aarch64-linux = {
              url = "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu.testing/edgedb-server-5.0-beta.2%2Bdf6373c.tar.zst";
              hash = "1dj3mbzjd5cg1wqzs9d354ja2xs564iynkywwxsijh6ch7fqqdvj";
            };
          };
        };
        mk_edgedb_server = { sources, system, pkgs }: pkgs.stdenvNoCC.mkDerivation {
          name = "edgedb-server";
          buildInputs = with pkgs; [];
          nativeBuildInputs = with pkgs; [
            zstd
          ] ++ lib.optionals (!pkgs.stdenv.isDarwin) [
            autoPatchelfHook
          ];

          dontPatchELF = pkgs.stdenv.isDarwin;
          dontFixup = pkgs.stdenv.isDarwin;
          src = pkgs.fetchurl {
            url = sources.${system}.url;
            sha256 = sources.${system}.hash;
          };
          installPhase = ''
            mkdir $out
            cp -r ./* $out
          '';
        };
      in { config, system, ... }: {
        packages.edgedb-server = mk_edgedb_server { sources = sources.v4_5; system = system; pkgs = nixpkgs.legacyPackages.${system}; };
        packages.edgedb-server-5_0_beta = mk_edgedb_server { sources = sources.v5_0_beta; system = system; pkgs = nixpkgs.legacyPackages.${system}; };
      };
    };
}
