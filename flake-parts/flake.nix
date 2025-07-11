{
  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      systems,
      flake-parts,
      treefmt-nix,
      pre-commit-hooks,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      imports = [
        treefmt-nix.flakeModule
        pre-commit-hooks.flakeModule
      ];

      perSystem =
        { config, pkgs, ... }:
        {
          treefmt = {
            # Whether to set `formatter` to the wrapped `treefmt`
            # derivation that will use a generated config file and
            # the needed formatters.
            flakeFormatter = true;
            # Whether to add the formatting check `checks.treefmt`.
            # This concern is handled by `checks.pre-commit` when
            # `hooks.treefmt.enable` is set as it runs `flakeFormatter`
            # already. Having both is redundant.
            flakeCheck = !(config.pre-commit.check.enable && config.pre-commit.settings.hooks.treefmt.enable);
            programs = {
              nixfmt.enable = true;
            };
          };

          pre-commit = {
            # Whether to add the check `checks.pre-commit` that will
            # run the hook checks.
            check.enable = true;
            settings.hooks = {
              treefmt = {
                enable = true;
                # The flake-module already does this, but ensuring
                # doesn't hurt.
                package = config.treefmt.build.wrapper;
              };
            };
          };

          devShells.default = pkgs.mkShellNoCC {
            shellHook = config.pre-commit.installationScript;
            packages = with pkgs; [
              git
              nil
              deadnix
              statix
            ];
          };
        };
    };
}
