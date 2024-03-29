{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    opam-nix.url = "github:tweag/opam-nix";
    flake-utils.url = "github:numtide/flake-utils";
    # we pin opam-nix's nixpkgs to follow the flakes, avoiding using two different instances
    opam-nix.inputs.nixpkgs.follows = "nixpkgs";

    # maintain a different opam-repository to those pinned upstream
    opam-repository = {
      url = "github:ocaml/opam-repository";
      flake = false;
    };
    opam-nix.inputs.opam-repository.follows = "opam-repository";

    # deduplicate flakes
    opam-nix.inputs.flake-utils.follows = "flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, opam-nix, ... }@inputs:
    # create outputs for each default system
    flake-utils.lib.eachDefaultSystem (system:
      let
        package = "oway";
        pkgs = nixpkgs.legacyPackages.${system};
        opam-nix-lib = opam-nix.lib.${system};
        devPackagesQuery = {
          ocaml-lsp-server = "*";
          ocamlformat = "*";
          utop = "*";
        };
        query = {
          ocaml-base-compiler = "*";
        };
        overlay = final: prev: {
          "xkbcommon" = prev."xkbcommon".overrideAttrs (_: {
            buildInputs = [ pkgs.libxkbcommon ];
          });
          ${package} = prev.${package}.overrideAttrs (_: {
            buildInputs = with pkgs; [
              wayland
              udev
              pixman
              wayland-protocols
              wlroots
              libxkbcommon
            ];
          });
        };
        resolved-scope =
          # recursive finds vendored dependancies in duniverse
          let scope = opam-nix-lib.buildOpamProject' { recursive = true; } ./. (query // devPackagesQuery); in
          scope.overrideScope' overlay;
        materialized-scope =
          let scope = opam-nix-lib.materializedDefsToScope { sourceMap.${package} = ./.; } ./package-defs.json; in
          scope.overrideScope' overlay;
      in rec {
        packages = rec {
          resolved = resolved-scope;
          materialized = materialized-scope;
          # to generate:
          #   cat $(nix eval .#package-defs --raw) > package-defs.json
          package-defs = opam-nix-lib.materializeOpamProject' { } ./. (query // devPackagesQuery);
        };
        defaultPackage = packages.resolved.${package};

        devShells =
          let
            mkDevShell = scope:
              let
                devPackages = builtins.attrValues
                  (pkgs.lib.getAttrs (builtins.attrNames devPackagesQuery) scope);
              in pkgs.mkShell {
                inputsFrom = [ scope.${package} ];
                buildInputs = devPackages;
              };
            dev-scope =
              # don't pick up duniverse deps
              # it can be slow to build vendored dependancies in a deriviation before getting an error
              let scope = opam-nix-lib.buildOpamProject' { } ./. (query // devPackagesQuery); in
              scope.overrideScope' overlay;
          in rec {
            resolved = mkDevShell resolved-scope;
            materialized = mkDevShell materialized-scope;
            # use for fast development as it doesn't building vendored sources in seperate derivations
            # however might not build the same result as `nix build .`,
            # like `nix develop .#devShells.x86_64-linux.resolved -c dune build` should do
            dev = mkDevShell dev-scope;
            default = dev;
          };
      }) // {
    nixosModules.default = {
      imports = [ ./module.nix ];
    };
  };
}
