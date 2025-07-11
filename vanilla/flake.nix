{
  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "nixpkgs/nixos-unstable";

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
      nixpkgs,
      treefmt-nix,
      pre-commit-hooks,
      ...
    }:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs (import systems) (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );

      # `wrapper` is a wrapped `treefmt` derivation
      # that will use a generated config file and the
      # needed formatters.
      wrappedTreefmt = eachSystem (
        { pkgs, ... }:
        (treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
          };
        }).config.build.wrapper
      );

      preCommitHooks = eachSystem (
        { system, ... }:
        rec {
          check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks.treefmt = {
              enable = true;
              package = wrappedTreefmt.${system};
            };
          };
          installationScript = check.shellHook;
        }
      );
    in
    {
      formatter = eachSystem ({ system, ... }: wrappedTreefmt.${system});
      checks = eachSystem (
        { system, ... }:
        {
          pre-commit = preCommitHooks.${system}.check;
        }
      );
      devShells = eachSystem (
        { pkgs, system }:
        {
          default = pkgs.mkShellNoCC {
            shellHook = preCommitHooks.${system}.installationScript;
            packages = with pkgs; [
              git
              nil
              deadnix
              statix
            ];
          };
        }
      );
    };
}
