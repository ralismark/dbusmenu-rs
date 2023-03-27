{
  description = "Rust bindings for DBusMenu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      overlays.default = self: super: {
        gir-rs = self.callPackage ./gir-rs.nix { };

        libdbusmenu-gtk3 = super.libdbusmenu-gtk3.overrideAttrs (prev: {
          patches = (prev.patches or []) ++ [
            (builtins.toFile "requires-glib.patch" ''
              --- a/libdbusmenu-glib/dbusmenu-glib-0.4.pc.in
              +++ b/libdbusmenu-glib/dbusmenu-glib-0.4.pc.in
              @@ -5,7 +5,7 @@
               includedir=@includedir@

               Cflags: -I''${includedir}/libdbusmenu-glib-0.4
              -Requires:
              +Requires: glib-2.0
               Libs: -L''${libdir} -ldbusmenu-glib

               Name: libdbusmenu-glib
            '')
          ];
        });
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

        mkGir = {
          pname,
          version,
          options,
          fixup ? "",
          ...
        }@attrs: let
          gir-files = pkgs.fetchFromGitHub {
            owner = "gtk-rs";
            repo = "gir-files";
            rev = "0.17.2";
            hash = "sha256-p7XvEHxRRUntmKx+KLHUqRxARHNGq3GdTVpTL22fhU8=";
          };

          writeToml = (pkgs.formats.toml {}).generate;

          girToml = writeToml "Gir.toml" {
            options = options // {
              library = pname;
              version = version;
              girs_directories = (options.girs_directories or []) ++ [
                "${./gir}"
                "${pkgs.libdbusmenu-gtk3}/share/gir-1.0"
                "${gir-files}"
              ];
            };
          };

          attrs' = builtins.removeAttrs attrs [
            "options"
            "fixup"
          ];

          # ifMode = mode: s: if mode == work_mode then s else "";

          src = pkgs.runCommand "${pname}-${version}" attrs' ''
            mkdir $out
            ${pkgs.gir-rs}/bin/gir -c ${girToml} -o $out

            # fixup
            rm $out/src/auto/versions.txt

            sed -i $out/src/lib.rs \
              -e '/^#\[link/d' \
              -e '/^\/\/from /d'

            sed -i $out/Cargo.toml \
              -e 's/git = ".*"/version = "0.15"/'

            ${fixup}
          '';
        in src;
      in
      rec {
        packages.gir-rs = pkgs.gir-rs;

        packages.libdbusmenu-sys = mkGir {
          pname = "Dbusmenu";
          version = "0.4";

          options = {
            min_cfg_version = "16";
            work_mode = "sys";
            single_version_file = true;
            external_libraries = [
              "GLib"
              "GObject"
            ];
            lib_version_overrides = [ {
              version = "0.4";
              lib_version = "0.17";
            } ];
          };
        };

        packages.libdbusmenu-gtk3-sys = mkGir {
          pname = "DbusmenuGtk3";
          version = "0.4";

          options = {
            min_cfg_version = "16";
            work_mode = "sys";
            single_version_file = true;
            external_libraries = [
              "GLib"
              "GObject"
              "Gdk"
              "GdkPixbuf"
              "Gtk"
            ];
          };

          fixup = ''
            sed -i $out/Cargo.toml \
              -e '/\[dependencies\]/adbusmenu = { package = "dbusmenu-sys", path = "../libdbusmenu-sys" }' \
              -e 's/^\(dox = \[\)\(.*\]\)$/\1"dbusmenu\/dox", \2/'
          '';
        };

        packages.default = pkgs.runCommand "dbusmenu-crates" {} ''
          mkdir $out
          ln -s ${packages.libdbusmenu-sys} $out/libdbusmenu-sys
          ln -s ${packages.libdbusmenu-gtk3-sys} $out/libdbusmenu-gtk3-sys
        '';

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            atk
            gcc
            glib
            gtk3
            libdbusmenu-gtk3
            pkgconfig
          ];
        };
      });
}
