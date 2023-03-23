{
  description = "Rust bindings for DBusMenu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        gir-rs = pkgs.callPackage ./gir-rs.nix { };

        mkGir = { library, version, ... }@options: let
          gir-files = pkgs.fetchFromGitHub {
            owner = "gtk-rs";
            repo = "gir-files";
            rev = "0.17.2";
            hash = "sha256-p7XvEHxRRUntmKx+KLHUqRxARHNGq3GdTVpTL22fhU8=";
          };

          girToml = (pkgs.formats.toml {}).generate "Gir.toml" {
            options = options // {
              girs_directories = (options.girs_directories or []) ++ [
                "${./gir}"
                "${pkgs.libdbusmenu-gtk3}/share/gir-1.0"
                "${gir-files}"
              ];
            };
          };
        in pkgs.runCommand "${library}-${version}" {} ''
          ${gir-rs}/bin/gir -c ${girToml} -o $out
        '';
      in
      {
        packages.gir-rs = gir-rs;

        packages.libdbusmenu-sys = mkGir {
          library = "Dbusmenu";
          version = "0.4";
          min_cfg_version = "16";
          work_mode = "sys";
          single_version_file = true;
          external_libraries = [
            "GLib"
            "GObject"
          ];
        };
      });
}
