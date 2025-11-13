{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    ps-tools.follows = "purs-nix/ps-tools";
    purs-nix.url = "path:/Volumes/Git/purs-nix";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, utils, ... }@inputs:
    utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ]
      (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        ps-tools = inputs.ps-tools.legacyPackages.${system};
        purs-nix = inputs.purs-nix { inherit system; };

        ps = purs-nix.purs {
          dependencies = [
            "aff"
            "affjax"
            "affjax-node"
            "affjax-web"
            "arrays"
            "avar"
            "console"
            "datetime"
            "effect"
            "either"
            "free"
            "freeap"
            "maybe"
            "now"
            "parallel"
            "partial"
            "prelude"
            "strings"
            "transformers"
            "tuples"
            "unfoldable"
            "unsafe-coerce"
            "variant"
          ];

          dir = ./.;
        };
      in
      {
        packages = {
          default = ps.bundle { };
          demo = ps.bundle {
            module = "Demo";
            esbuild = {
              platform = "node";
              format = "cjs";
              external = [ "xhr2" "url" ];
            };
          };
          demo-composition = ps.bundle {
            module = "DemoComposition";
            esbuild = {
              platform = "node";
              format = "cjs";
              external = [ "xhr2" "url" ];
            };
          };
        };

        apps = {
          default = {
            type = "app";
            program = "${ps.bundle { }}/bin/index.js";
          };

          demo =
            let
              demoBundle = ps.bundle {
                module = "Demo";
                esbuild = {
                  platform = "node";
                  format = "cjs";
                  external = [ "xhr2" "url" ];
                };
              };
            in {
              type = "app";
              program = "${pkgs.writeShellScript "run-demo" ''
                ${pkgs.nodejs}/bin/node ${demoBundle}
              ''}";
            };

          demo-composition =
            let
              demoBundle = ps.bundle {
                module = "DemoComposition";
                esbuild = {
                  platform = "node";
                  format = "cjs";
                  external = [ "xhr2" "url" ];
                };
              };
            in {
              type = "app";
              program = "${pkgs.writeShellScript "run-demo-composition" ''
                ${pkgs.nodejs}/bin/node ${demoBundle}
              ''}";
            };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            entr
            nodejs
            (ps.command { })
            ps-tools.for-0_15.purescript-language-server
            purs-nix.esbuild
            purs-nix.purescript
          ];

          shellHook = ''
            alias watch="find src | entr -s 'echo bundling; purs-nix bundle'"
          '';
        };
      });
}
