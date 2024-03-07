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
      perSystem = { config, system, ... }: {
        packages.edgedb-server =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            source = {
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
            }.${system};
          in pkgs.stdenvNoCC.mkDerivation {
              name = "edgedb-server";
              buildInputs = with pkgs; [
                # python3
              ];
              nativeBuildInputs = with pkgs; [
                zstd
              ] ++ lib.optionals (!pkgs.stdenv.isDarwin) [
                autoPatchelfHook
              ];

              dontPatchELF = pkgs.stdenv.isDarwin;
              dontFixup = pkgs.stdenv.isDarwin;
              src = pkgs.fetchurl {
                url = source.url;
                sha256 = source.hash;
              };
              installPhase = ''
                mkdir $out
                cp -r ./* $out
              '';
            };

      };
    };
}
