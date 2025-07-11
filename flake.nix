{
  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      systems,
      nixpkgs,
      flake-parts,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      flake.templates = {
        default = self.templates.flake-parts;
        vanilla = {
          path = ./vanilla;
          description = "Boilerplate development shell";
        };
        flake-parts = {
          path = ./flake-parts;
          description = "Boilerplate development shell using `flake-parts`";
        };
      };

      perSystem =
        { lib, pkgs, ... }:
        {
          packages.default =
            with lib;
            pkgs.writeShellApplication {
              name = "flake-init";
              meta.description = "Shell script wrapper around `nix flake init` to use my templates";
              text = ''
                # This script was dynamically generated here: ${__curPos.file}:${toString __curPos.line}

                # <https://github.com/sebaszv/nix-flake-templates>
                declare -r my_templates_flake_store_path=${self}

                if [[ $# -eq 0 ]]; then
                  nix flake init -t $my_templates_flake_store_path
                  exit
                fi

                # The actual value assigned doesn't matter here.
                # All we care about are the keys.
                declare -Ar my_templates=(
                  ${concatMapStringsSep "\n  " (t: ''["${t}"]="${t}"'') (attrNames self.templates)}
                )

                if [[ -v my_templates["$1"] ]]; then
                  nix flake init -t "$my_templates_flake_store_path#$1"
                else
                  nix flake init -t "$1"
                fi
              '';
            };
        };
    };
}
