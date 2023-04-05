{
  lib,
  fetchFromGitHub,
  rustPlatform,
}: let
  pname = "rustdoc-stripper";
  version = "0.1.18";
in
  rustPlatform.buildRustPackage {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "guillaumegomez";
      repo = "rustdoc-stripper";
      rev = "f6643dd300a71c876625260f190c63a5be41f331";
      sha256 = "sha256-eQxAS76kV01whXK21PN5U+nkpvpn6r4VOoe9/pkuAQY=";
    };

    cargoSha256 = "sha256-3pcNjNA2/N3sL92l8sX2t/0HUIuVsNZbGpWDjukwcp0=";

    meta = with lib; {
      description = "rustdoc-stripper is a tool used to remove rustdoc comments from your code and save them in a comments.cmts file if you want to regenerate them.";
      homepage = "https://github.com/guillaumegomez/rustdoc-stripper";
      license = with licenses; [asl20];
      maintainers = with maintainers; [ralismark];
      mainProgram = "rustdoc-stripper";
    };
  }
