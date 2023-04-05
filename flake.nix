{
  description = "Rust bindings for DBusMenu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    {
      overlays.default = self: super: {
        gir-rs = self.callPackage ./gir-rs.nix {};

        libdbusmenu-gtk3 = super.libdbusmenu-gtk3.overrideAttrs (prev: {
          patches =
            (prev.patches or [])
            ++ [
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

        gir-files = self.fetchFromGitHub {
          owner = "gtk-rs";
          repo = "gir-files";
          rev = "0.17.2";
          hash = "sha256-p7XvEHxRRUntmKx+KLHUqRxARHNGq3GdTVpTL22fhU8=";
        };

        buildGir = self.callPackage ./buildGir.nix {
          defaultGirDirs = [
            self.gir-files
            (let
              patch = builtins.toFile "fix-dbusmenu-gir.patch" ''
                --- a/Dbusmenu-0.4.gir
                +++ b/Dbusmenu-0.4.gir
                @@ -2857,7 +2857,7 @@
                         <doc xml:space="preserve"
                              filename="menuitem.h"
                              line="428">Virtual function that appends the strings required to represent this menu item in the menu variant.</doc>
                -        <type c:type="dbusmenu_menuitem_buildvariant_slot_t"/>
                +        <type name="menuitem_buildvariant_slot_t" c:type="dbusmenu_menuitem_buildvariant_slot_t"/>
                       </field>
                       <field name="handle_event">
                         <callback name="handle_event">
                @@ -2910,7 +2910,7 @@
                               <doc xml:space="preserve"
                                    filename="menuitem.c"
                                    line="1776">Callback to call when the call has returned.</doc>
                -              <type c:type="dbusmenu_menuitem_about_to_show_cb"/>
                +              <type name="menuitem_about_to_show_cb" c:type="dbusmenu_menuitem_about_to_show_cb"/>
                             </parameter>
                             <parameter name="cb_data"
                                        transfer-ownership="none"
              '';
            in
              self.runCommand "dbusmenu-gtk3-gir" {} ''
                cp --no-preserve=all -rL ${self.libdbusmenu-gtk3}/share/gir-1.0 $out
                patch -p1 -d $out <${patch}
              '')
          ];
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
      lib = pkgs.lib;

      buildGir = args:
        pkgs.buildGir (lib.recursiveUpdate args {
          girToml.crate_name_overrides = {
            dbusmenu = "dbusmenu_glib";
          };
          fixupPhase = lib.concatLines [
            (args.fixupPhase or "")
            (lib.optionalString (args.girWorkMode == "sys") ''
              sed -i $out/Cargo.toml \
                -e 's/git = ".*"/version = "0.15"/'
            '')
          ];
        });
    in rec {
      formatter = pkgs.alejandra;

      packages.gir-rs = pkgs.gir-rs;

      packages.dbusmenu-glib-sys = buildGir {
        pname = "Dbusmenu";
        version = "0.4";

        girWorkMode = "sys";
        girToml.options = {
          min_cfg_version = "16";
          single_version_file = true;
          external_libraries = [
            "GLib"
            "GObject"
          ];
        };

        fixupPhase = ''
          sed -e '/icon_paths/s/c_char/glib::GStrv/g' -i src/lib.rs
        '';
      };

      packages.dbusmenu-gtk3-sys = buildGir {
        pname = "DbusmenuGtk3";
        version = "0.4";

        girWorkMode = "sys";
        girToml.options = {
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

        fixupPhase = ''
          sed -i $out/Cargo.toml \
            -e '/\[dependencies\]/adbusmenu-glib = { package = "dbusmenu-glib-sys", path = "../dbusmenu-glib-sys" }' \
            -e 's/^\(dox = \[\)\(.*\]\)$/\1"dbusmenu-glib\/dox", \2/'
        '';
      };

      packages.dbusmenu-glib = buildGir {
        pname = "Dbusmenu";
        version = "0.4";

        girWorkMode = "normal";
        girToml.options = {
          min_cfg_version = "16";
          single_version_file = true;
          generate_safety_asserts = true;
          deprecate_by_min_version = true;
          generate = [
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
        };
        girToml.object = [
          {
            name = "Dbusmenu.Client";
            status = "generate";
            function = [
              {
                name = "add_type_handler";
                ignore = true; # takes a callback but no associated user data
              }
            ];
          }
        ];

        assertInitialized = false;

        cargoToml = {
          package = {
            name = "dbusmenu-glib";
            version = "0.0.1";
            edition = "2021";

            metadata.docs.rs.features = ["dox"];
          };

          lib.name = "dbusmenu_glib";
          dependencies = {
            libc = "0.2";
            ffi = {
              package = "dbusmenu-glib-sys";
              path = "../dbusmenu-glib-sys";
            };
            glib = "0.15";
          };

          features.dox = ["ffi/dox" "glib/dox"];
        };

        fixupPhase = ''
          sed -i src/auto/menuitem.rs \
            -e '/property_set_byte_array/s/value: u8, nelements: usize/values: \&[u8]/' \
            -e '/ffi::dbusmenu_menuitem_property_set_byte_array/s/value, nelements/values.as_ptr(), values.len()/'
        '';
      };

      packages.dbusmenu-gtk3 = buildGir {
        pname = "DbusmenuGtk3";
        version = "0.4";

        girWorkMode = "normal";
        girToml.options = {
          min_cfg_version = "16";
          single_version_file = true;
          generate_safety_asserts = true;
          deprecate_by_min_version = true;
          generate = [
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
        girToml.object = [
          {
            name = "DbusmenuGtk3.Client";
            status = "generate";
            function = [
              {
                name = "newitem_base";
                parameter = [
                  {
                    name = "parent";
                    nullable = true;
                  }
                ];
              }
            ];
          }
        ];

        cargoToml = {
          package = {
            name = "dbusmenu-gtk3";
            version = "0.0.1";
            edition = "2021";

            metadata.docs.rs.features = ["dox"];
          };

          lib.name = "dbusmenu_gtk3";
          dependencies = {
            libc = "0.2";
            ffi = {
              package = "dbusmenu-gtk3-sys";
              path = "../dbusmenu-gtk3-sys";
            };
            dbusmenu-glib = {path = "../dbusmenu-glib";};
            glib = "0.15";
            gtk = "0.15";
            atk = "0.15";
          };

          features.dox = ["ffi/dox" "dbusmenu-glib/dox" "glib/dox" "gtk/dox" "atk/dox"];
        };

        fixupPhase = ''
          sed -i src/auto/menu.rs -e 's/gobject/glib::object/g'

          # interface does not exist
          sed -i src/auto/menu.rs \
            -e 's/atk::ImplementorIface, //'
        '';
      };

      packages.default = pkgs.runCommand "dbusmenu-crates" {} ''
        mkdir $out
        ln -s ${packages.dbusmenu-glib-sys} $out/dbusmenu-glib-sys
        ln -s ${packages.dbusmenu-gtk3-sys} $out/dbusmenu-gtk3-sys
        ln -s ${packages.dbusmenu-glib} $out/dbusmenu-glib
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
