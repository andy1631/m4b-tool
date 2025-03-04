{
  pkgs ? import <nixpkgs> { },
  lib,
  useLibfdk ? false,
}:

let
  # Override the mp4v2 package to use the repository from GitHub.
  customMp4v2 = pkgs.mp4v2.overrideAttrs (old: rec {
    src = pkgs.fetchFromGitHub {
      owner = "sandreas";
      repo = "mp4v2";
      rev = "master";
      sha256 = "sha256-AOkFObeANF5Vg2vAY4x7aluFJsNlAKJTQXvV3ZJgatE=";
    };
  });

  m4bToolFfmpeg =
    if useLibfdk then
      pkgs.ffmpeg-headless.overrideAttrs (prev: rec {
        configureFlags = prev.configureFlags ++ [
          "--enable-libfdk-aac"
          "--enable-nonfree"
        ];
        buildInputs = prev.buildInputs ++ [
          pkgs.fdk_aac
        ];
      })
    else
      pkgs.ffmpeg-headless;

  m4bToolPhp = pkgs.php82.buildEnv {
    extensions = (
      { enabled, all }:
      enabled
      ++ (with all; [
        dom
        mbstring
        tokenizer
        xmlwriter
        openssl
      ])
    );
    extraConfig = ''
      date.timezone = UTC
      error_reporting = E_ALL & ~E_STRICT & ~E_NOTICE & ~E_DEPRECATED
    '';
  };

in
m4bToolPhp.buildComposerProject rec {
  pname = "m4b-tool";
  version = "v0.5.2";
  src = ./.;
  vendorHash = "sha256-Ycl1PLa2v00qBVbNEBBYtOVFuJoXEWN2DuxgIdB/CA8=";
  meta.mainProgram = "m4b-tool";
  composerNoDev = false; # Enable dev dependencies (phpunit etc.)
  buildInputs = with pkgs; [
    m4bToolPhp
    m4bToolFfmpeg
    customMp4v2
    fdk-aac-encoder
  ];
  postInstall = ''
        mkdir -p $out/bin
        # Version injection: replace the @package_version@ placeholder with the actual version.
        sed -i 's!@package_version@!${version}!g' $out/share/php/m4b-tool/bin/m4b-tool.php

        # Create a wrapper script that sets PATH to include our chosen ffmpeg-headless and mp4v2.
        cat > $out/bin/m4b-tool <<EOF
    #!/bin/sh
    export PATH=${lib.makeBinPath buildInputs}
    exec ${m4bToolPhp}/bin/php $out/share/php/m4b-tool/bin/m4b-tool.php "\$@"
    EOF
        chmod +x $out/bin/m4b-tool
  '';
  doInstallCheck = true;
  installCheckPhase =
    let
      exampleAudiobook = pkgs.fetchurl {
        name = "audiobook";
        url = "https://archive.org/download/M4bCollectionOfLibrivoxAudiobooks/ArtOfWar-64kb.m4b";
        sha256 = "00cvbk2a4iyswfmsblx2h9fcww2mvb4vnlf22gqgi1ldkw67b5w7";
      };
    in
    ''
      ${m4bToolPhp}/bin/php vendor/bin/phpunit tests

      # Check that the audiobook splitting works.
      mkdir -p audiobook
      cd audiobook
      cp ${exampleAudiobook} audiobook.m4b
      $out/bin/m4b-tool split -vvv -o . audiobook.m4b
      if ! grep -q 'The Nine Situations' audiobook.chapters.txt; then
        echo "Chapter split test failed!"
        exit 1
      fi
      if [ ! -f '006-11 The Nine Situations.m4b' ]; then
        echo "Expected output file not found!"
        exit 1
      fi
      cd ..
      rm -rf audiobook
    '';
  passthru = {
    dependencies = buildInputs;
  };
}
