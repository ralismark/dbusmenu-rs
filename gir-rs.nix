{ lib, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "gir_0_15";
  version = "2022-03-14-unstable";

  src = fetchFromGitHub {
    owner = "gtk-rs";
    repo = "gir";
    rev = "c8a7a13d2c4d3a57ae646e38a821d57243cf7983";
    sha256 = "sha256-WpTyT62bykq/uwzBFQXeJ1HxR1a2vKmtid8YAzk7J+Q=";
  };

  cargoSha256 = "sha256-+GewKlrVchUhN0nkSmRlzSU/zT5poFPTNrpBM41HmZw=";

  postPatch = ''
    rm build.rs
    sed -i '/build = "build\.rs"/d' Cargo.toml
    echo "pub const VERSION: &str = \"$version\";" > src/gir_version.rs
  '';

  meta = with lib; {
    description = "Tool to generate rust bindings and user API for glib-based libraries";
    homepage = "https://github.com/gtk-rs/gir/";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ ekleog ];
    mainProgram = "gir";
  };
}
