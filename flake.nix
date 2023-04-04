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
          workMode,
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
              work_mode = workMode;
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

          ifMode = mode: s: if mode == workMode then s else "";

          src = pkgs.runCommand "${pname}-${version}-${workMode}" attrs' ''
            mkdir $out
            ${pkgs.gir-rs}/bin/gir -c ${girToml} -o $out

            # fixup
            shopt -s globstar

            ${ifMode "sys" ''
              sed -i $out/src/**/*.rs \
                -e '/^#\[link/d'

              sed -i $out/Cargo.toml \
                -e 's/git = ".*"/version = "0.15"/'
            ''}

            ${ifMode "normal" ''
              cat ${builtins.toFile "lib.rs" ''
                /// No-op.
                #[allow(unused_macros)]
                macro_rules! skip_assert_initialized {
                    () => {};
                }

                /// Asserts that this is the main thread and either `gdk::init` or `gtk::init` has been called.
                #[allow(unused_macros)]
                macro_rules! assert_initialized_main_thread {
                    () => {
                        if !::gtk::is_initialized_main_thread() {
                            if ::gtk::is_initialized() {
                                panic!("GTK may only be used from the main thread.");
                            } else {
                                panic!("GTK has not been initialized. Call `gtk::init` first.");
                            }
                        }
                    };
                }

                mod auto;
                pub use auto::*;
              ''} > $out/src/lib.rs

                sed -i $out/src/auto/mod.rs -e '/doc(hidden)/d'

                mkdir -p $out/tests
                echo "fn main() {}" > $out/tests/it_compiles.rs
            ''}

            ${fixup}
          '';
        in src;
      in
      rec {
        packages.gir-rs = pkgs.gir-rs;

        packages.dbusmenu-sys = mkGir {
          pname = "Dbusmenu";
          version = "0.4";
          workMode = "sys";

          options = {
            min_cfg_version = "16";
            single_version_file = true;
            external_libraries = [
              "GLib"
              "GObject"
            ];
          };

          fixup = ''
            sed -e '/icon_paths/s/c_char/glib::GStrv/g' -i $out/src/lib.rs
          '';
        };

        packages.dbusmenu-gtk3-sys = mkGir {
          pname = "DbusmenuGtk3";
          version = "0.4";
          workMode = "sys";

          options = {
            min_cfg_version = "16";
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
              -e '/\[dependencies\]/adbusmenu = { package = "dbusmenu-sys", path = "../dbusmenu-sys" }' \
              -e 's/^\(dox = \[\)\(.*\]\)$/\1"dbusmenu\/dox", \2/'
          '';
        };

        packages.dbusmenu = mkGir {
          pname = "Dbusmenu";
          version = "0.4";
          workMode = "normal";

          options = {
            min_cfg_version = "16";
            single_version_file = true;
            generate_safety_asserts = true;
            deprecate_by_min_version = true;
            generate = [
              "Dbusmenu.Client"
              "Dbusmenu.ClientTypeHandler"
              "Dbusmenu.Menuitem"
              "Dbusmenu.Status"
              "Dbusmenu.TextDirection"
              "Dbusmenu.menuitem_buildvariant_slot_t"
              "Dbusmenu.menuitem_about_to_show_cb"
              "Dbusmenu.MenuitemProxy"
              "Dbusmenu.Server"
            ];
            manual = [
              "GLib.DestroyNotify"
              "GLib.Variant"
            ];

            object = [ {
              name = "Dbusmenu.Client";
              status = "generate";
              function = [ {
                # GStrv is not generated correctly
                pattern = ".*";
                ignore = true;
              } ];
            }  ];
          };

          fixup = ''
            cat ${(pkgs.formats.toml {}).generate "Cargo.toml" {
              package = {
                name = "dbusmenu";
                version = "0.0.1";
                edition = "2021";

                metadata.docs.rs.features = ["dox"];
              };

              lib.name = "dbusmenu";
              dependencies = {
                libc = "0.2";
                ffi = { package = "dbusmenu-sys"; path = "../dbusmenu-sys"; };
                glib = "0.15";
                gtk = "0.15";
              };

              features.dox = ["ffi/dox" "glib/dox"];
            }} > $out/Cargo.toml

            sed -i $out/src/auto/menuitem.rs \
              -e '/property_set_byte_array/s/value: u8, nelements: usize/values: \&[u8]/' \
              -e '/ffi::dbusmenu_menuitem_property_set_byte_array/s/value, nelements/values.as_ptr(), values.len()/'
          '';
        };

        packages.dbusmenu-gtk3 = mkGir {
          pname = "DbusmenuGtk3";
          version = "0.4";
          workMode = "normal";

          options = {
            min_cfg_version = "16";
            single_version_file = true;
            generate_safety_asserts = true;
            deprecate_by_min_version = true;
            generate = [
              "DbusmenuGtk3.Client"
              "DbusmenuGtk3.Menu"
            ];
            manual = [
              "Atk.ImplementorIface"
              "Dbusmenu.Client"
              "Dbusmenu.Menuitem"
              "GObject.InitiallyUnowned"
              "Gdk.ModifierType"
              "GdkPixbuf.Pixbuf"
              "Gtk.AccelGroup"
              "Gtk.Buildable"
              "Gtk.Container"
              "Gtk.Menu"
              "Gtk.MenuItem"
              "Gtk.MenuShell"
              "Gtk.Widget"
            ];
          };

          fixup = ''
            sed -i $out/src/**/menu.rs -e 's/gobject/glib::object/g'

            # interface does not exist
            sed -i $out/src/auto/menu.rs \
              -e 's/atk::ImplementorIface, //'

            cat >$out/Cargo.toml ${(pkgs.formats.toml {}).generate "Cargo.toml" {
              package = {
                name = "dbusmenu-gtk3";
                version = "0.0.1";
                edition = "2021";

                metadata.docs.rs.features = ["dox"];
              };

              lib.name = "dbusmenu_gtk3";
              dependencies = {
                libc = "0.2";
                ffi = { package = "dbusmenu-gtk3-sys"; path = "../dbusmenu-gtk3-sys"; };
                dbusmenu = { path = "../dbusmenu"; };
                glib = "0.15";
                gtk = "0.15";
                atk = "0.15";
              };

              features.dox = ["ffi/dox" "glib/dox"];
            }}
          '';
        };

        packages.default = pkgs.runCommand "dbusmenu-crates" {} ''
          mkdir $out
          ln -s ${packages.dbusmenu-sys} $out/dbusmenu-sys
          ln -s ${packages.dbusmenu-gtk3-sys} $out/dbusmenu-gtk3-sys
          ln -s ${packages.dbusmenu} $out/dbusmenu
          ln -s ${packages.dbusmenu-gtk3} $out/dbusmenu-gtk3
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
