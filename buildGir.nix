{
  lib,
  runCommand,
  formats,
  gir-rs,
  gir-files,
  defaultGirDirs ? [gir-files], # directories to always search for .gir files in
}: {
  pname,
  version,
  girWorkMode,
  girToml,
  assertInitialized ? "gtk",
  cargoToml ? null,
  fixupPhase ? "",
  ...
} @ attrs: let
  writeToml = (formats.toml {}).generate;

  girToml' = writeToml "Gir.toml" (lib.foldl lib.recursiveUpdate {} [
    {
      options.library = pname;
      options.version = version;
    }
    girToml
    {
      options.girs_directories =
        (lib.attrByPath ["options" "girs_directories"] [] girToml)
        ++ (map builtins.toString defaultGirDirs);
    }
  ]);

  attrs' = builtins.removeAttrs attrs [
    "girWorkMode"
    "girToml"
    "assertInitialized"
    "cargoToml"
    "fixupPhase"
  ];

  assert_initialized_main_thread =
    if assertInitialized == null || assertInitialized == false
    then ""
    else if assertInitialized == "gtk"
    then ''
      if !::gtk::is_initialized_main_thread() {
          if ::gtk::is_initialized() {
              panic!("GTK may only be used from the main thread.");
          } else {
              panic!("GTK has not been initialized. Call `gtk::init` first.");
          }
      }
    ''
    else if assertInitialized == "gdk"
    then ''
      if !::gdk::is_initialized_main_thread() {
          if ::gdk::is_initialized() {
              panic!("GDK may only be used from the main thread.");
          } else {
              panic!("GDK has not been initialized. Call `gtk::init` or `gdk::init` first.");
          }
      }
    ''
    else throw ''assertInitialized must be one of null, "gtk", "gdk", was ${assertInitialized}'';

  normal-librs = builtins.toFile "lib.rs" ''
    #[allow(unused_macros)]
    #[doc(hidden)]
    macro_rules! skip_assert_initialized {
        () => {};
    }

    #[allow(unused_macros)]
    #[doc(hidden)]
    macro_rules! assert_initialized_main_thread {
        () => {
          ${assert_initialized_main_thread}
        };
    }

    mod auto;
    pub use auto::*;
    pub use ffi;
  '';

  src = runCommand "${pname}-${girWorkMode}-${version}" attrs' (lib.concatLines [
    # initial generation
    ''
      mkdir $out
      cd $out
      ${gir-rs}/bin/gir -c ${girToml'} -m ${girWorkMode} -o .
    ''

    # built-in fixups
    (lib.optionalString (girWorkMode == "sys") ''
      # delete #[link] attributes, since they point into /nix/store. use pkg-config instead
      sed -i src/lib.rs \
        -e '/^#\[link/d'
    '')

    (lib.optionalString (girWorkMode == "normal") ''
      cat ${normal-librs} > src/lib.rs

      # generate some default tests
      mkdir -p tests
      printf '%s\n' "#[test]" "fn it_compiles() {}" > tests/it_compiles.rs
    '')

    (lib.optionalString (cargoToml != null) ''
      cat ${writeToml "Cargo.toml" cargoToml} > Cargo.toml
    '')

    # invocation fixups
    fixupPhase
  ]);
in
  src
