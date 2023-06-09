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
        rustdoc-stripper = self.callPackage ./nix/rustdoc-stripper.nix {};

        gir-files = self.fetchFromGitHub {
          owner = "gtk-rs";
          repo = "gir-files";
          rev = "0.17.2";
          hash = "sha256-p7XvEHxRRUntmKx+KLHUqRxARHNGq3GdTVpTL22fhU8=";
        };

        buildGir = self.callPackage ./nix/buildGir.nix {
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

      # version for us
      ourVersion = "0.1.0";

      # gtkrs version we target
      gtkrsVersion = ">=0.15";

      # crates.io metadata
      metadata = {
        license = "LGPL-3.0-only";
        homepage = "https://github.com/ralismark/dbusmenu-rs";
        repository = "https://github.com/ralismark/dbusmenu-rs";
        readme = "${./README.md}";
        keywords = ["gtk-rs"];
        categories = ["api-bindings" "gui"];
      };

      writeToml = (pkgs.formats.toml {}).generate;

      buildGir = args:
        pkgs.buildGir (lib.recursiveUpdate args {
          girToml.crate_name_overrides = {
            dbusmenu = "dbusmenu_glib";
          };
          fixupPhase = lib.concatLines [
            (args.fixupPhase or "")
            (lib.optionalString (args.girWorkMode == "sys") ''
              sed -i $out/Cargo.toml \
                -e 's/git = ".*"/version = "${gtkrsVersion}"/'
            '')
          ];
        });
    in rec {
      formatter = pkgs.alejandra;

      packages.gir-rs = pkgs.gir-rs;
      packages.rustdoc-stripper = pkgs.rustdoc-stripper;

      packages.dbusmenu-glib-sys = buildGir {
        pname = "dbusmenu-glib-sys";
        version = ourVersion;

        girWorkMode = "sys";
        girToml.options = {
          library = "Dbusmenu";
          version = "0.4";

          min_cfg_version = "16";
          single_version_file = true;
          external_libraries = [
            "GLib"
            "GObject"
          ];
        };

        fixupPhase = let
          packageExtra = writeToml "Cargo.toml-package" (metadata
            // {
              description = "FFI bindings to dbusmenu-glib";
              links = "dbusmenu-glib";
            });
        in ''
          sed -i $out/Cargo.toml \
            -e '/^\[package\]$/r${packageExtra}'

          sed -e '/icon_paths/s/c_char/glib::GStrv/g' -i $out/src/lib.rs
        '';
      };

      packages.dbusmenu-gtk3-sys = buildGir {
        pname = "dbusmenu-gtk3-sys";
        version = ourVersion;

        girWorkMode = "sys";
        girToml.options = {
          library = "DbusmenuGtk3";
          version = "0.4";

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

        fixupPhase = let
          packageExtra = writeToml "Cargo.toml-package" (metadata
            // {
              description = "FFI bindings to dbusmenu-gtk3";
              links = "dbusmenu-gtk3";
            });
        in ''
          sed -i $out/Cargo.toml \
            -e '/^\[package\]$/r${packageExtra}'

          sed -i $out/Cargo.toml \
            -e '/\[dependencies\]/adbusmenu-glib = { package = "dbusmenu-glib-sys", version = "${packages.dbusmenu-glib-sys.version}", path = "../dbusmenu-glib-sys" }' \
            -e 's/^\(dox = \[\)\(.*\]\)$/\1"dbusmenu-glib\/dox", \2/'
        '';
      };

      packages.dbusmenu-glib = let
        pname = "dbusmenu-glib";
        version = ourVersion;
      in
        buildGir {
          inherit pname version;

          girWorkMode = "normal";
          girToml.options = {
            library = "Dbusmenu";
            version = "0.4";

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
            package =
              metadata
              // {
                name = pname;
                description = "Rust bindings to dbusmenu-glib";
                version = version;
                edition = "2021";

                metadata.docs.rs.features = ["dox"];
              };

            lib.name = "dbusmenu_glib";
            dependencies = {
              libc = "0.2";
              ffi = {
                package = "dbusmenu-glib-sys";
                version = packages.dbusmenu-glib-sys.version;
                path = "../dbusmenu-glib-sys";
              };
              glib = gtkrsVersion;
            };

            features.dox = ["ffi/dox" "glib/dox"];
          };

          fixupPhase = let
            crateDocs = builtins.toFile "lib.rs" ''
              //! # bindings for glib part of libdbusmenu
              //!
              //! Rust bindings for the glib part of [libdbusmenu] that work with the [gtk-rs ecosystem].
              //!
              //! By using [`Server`], you can use this crate in desktop applications to expose a menu over DBus.
              //! For more information, including code examples, see [libdbusmenu].
              //!
              //! This crate also provides a UI-framework-independent interface to read them by using [`Client`].
              //! However, if you are using GTK, it is recommended that you use `dbusmenu-gtk3`, which handles most of the GTK glue required to show it.
              //!
              //! [libdbusmenu]: https://github.com/AyatanaIndicators/libdbusmenu
              //! [gtk-rs ecosystem]: https://gtk-rs.org
            '';
          in ''
            sed -i $out/src/lib.rs -e '0r${crateDocs}'

            sed -i $out/src/auto/menuitem.rs \
              -e '/property_set_byte_array/s/value: u8, nelements: usize/values: \&[u8]/' \
              -e '/ffi::dbusmenu_menuitem_property_set_byte_array/s/value, nelements/values.as_ptr(), values.len()/'
          '';
        };

      packages.dbusmenu-gtk3 = let
        pname = "dbusmenu-gtk3";
        version = ourVersion;
      in
        buildGir {
          inherit pname version;

          girWorkMode = "normal";
          girToml.options = {
            library = "DbusmenuGtk3";
            version = "0.4";

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
            package =
              metadata
              // {
                name = pname;
                description = "Rust bindings to dbusmenu-gtk3";
                version = version;
                edition = "2021";

                metadata.docs.rs.features = ["dox"];
              };

            lib.name = "dbusmenu_gtk3";
            dependencies = {
              libc = "0.2";
              ffi = {
                package = "dbusmenu-gtk3-sys";
                version = packages.dbusmenu-gtk3-sys.version;
                path = "../dbusmenu-gtk3-sys";
              };
              dbusmenu-glib = {
                version = packages.dbusmenu-glib.version;
                path = "../dbusmenu-glib";
              };
              glib = gtkrsVersion;
              gtk = gtkrsVersion;
              atk = gtkrsVersion;
            };

            features.dox = ["ffi/dox" "dbusmenu-glib/dox" "glib/dox" "gtk/dox" "atk/dox"];
          };

          fixupPhase = let
            crateDocs = builtins.toFile "lib.rs" ''
              //! # bindings for gtk part of libdbusmenu
              //!
              //! Rust bindings for the gtk part of [libdbusmenu] that work with the [gtk-rs ecosystem].
              //!
              //! If you are looking to expose a menu over DBus (e.g. for a system tray icon), see [`mod@dbusmenu_glib`].
              //! This crate provides [`Menu`], a GTK widget which will show the contents of a menu exposed over DBus.
              //!
              //! [libdbusmenu]: https://github.com/AyatanaIndicators/libdbusmenu
              //! [gtk-rs ecosystem]: https://gtk-rs.org

              // for links in docs
              #[allow(unused)] use dbusmenu_glib;
              #[allow(unused)] use gtk;
            '';
          in ''
            sed -i $out/src/lib.rs -e '0r${crateDocs}'

            sed -i $out/src/auto/menu.rs -e 's/gobject/glib::object/g'

            # interface does not exist
            sed -i $out/src/auto/menu.rs -e 's/atk::ImplementorIface, //'
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
