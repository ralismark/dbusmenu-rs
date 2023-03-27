{ lib, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "gir";
  version = "0.17.1";

  src = fetchFromGitHub {
    owner = "gtk-rs";
    repo = "gir";
    rev = "0.17.1";
    sha256 = "sha256-WpTyT62bykq/uwzBFQXeJ1HxR1a2vKmtid8YAzk7J+Q=";
  };

  cargoSha256 = "sha256-c4CcoiAotWUqqb7lflO/IqSv84JdaM2oJUvBYOVTMcs=";

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
