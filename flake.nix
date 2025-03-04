{
  description = "Example flake for PHP development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        m4b-tool = pkgs.callPackage ./default.nix { };
      in
      {
        packages = {
          m4b-tool = m4b-tool;
          m4b-tool-libfdk = m4b-tool.override {
            useLibfdk = true;
          };
        };

        devShells = {
          default = pkgs.mkShellNoCC {
            name = "php-devshell";
            buildInputs = [
              pkgs.php82Packages.composer
            ] ++ m4b-tool.dependencies;

          };
        };

        apps = { };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
