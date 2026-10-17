{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    ps-tools.follows = "purs-nix/ps-tools";
    purs-nix.url = "git+ssh://git@github.com/Cambridge-Vision-Technology/purs-nix?rev=12a7bcf1b002ac080c3187eec641332d64b5c2c7";
    purs-nix.inputs.nixpkgs.follows = "nixpkgs";
    utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    purescript-whine = {
      url = "https://flakehub.com/f/Cambridge-Vision-Technology/purescript-whine/0.1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.purs-nix.follows = "purs-nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      ...
    }@inputs:
    utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        ps-tools = inputs.ps-tools.legacyPackages.${system};
        purs-nix = inputs.purs-nix { inherit system; };
        purescript-whine = inputs.purescript-whine.packages.${system}.default;

        treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
          programs.nixfmt.package = pkgs.nixfmt-rfc-style;
          programs.purs-tidy.enable = true;
          settings.formatter.purs-tidy = {
            includes = [ "*.purs" ];
          };
        };

        # Provide node_modules with xhr2 for Affjax.Node FFI
        nodeDeps = pkgs.buildNpmPackage {
          pname = "purescript-parallel-effects-node-deps";
          version = "0.1.0";
          src = ./.;
          npmDepsHash = "sha256-nHD+UmtyicICZzcs2gMrt0qU2IapNr0lHFHcMzSmI1s=";
          dontBuild = true;
          installPhase = ''
            mkdir -p $out
            cp -r node_modules $out/
          '';
        };

        # Patch affjax-node to include xhr2 node_modules
        affjax-node-with-xhr2 = pkgs.lib.recursiveUpdate purs-nix.ps-pkgs.affjax-node {
          purs-nix-info.foreign."Affjax.Node".node_modules = "${nodeDeps}/node_modules";
        };

        # Node deps for bdd-markdown CLI (offline, reproducible)
        bddNodeDeps = pkgs.buildNpmPackage {
          pname = "bdd-markdown-deps";
          version = "8.0.0";
          src = ./tools/bdd;
          npmDepsHash = "sha256-h/2rZaK0smufuWCCpMcc1xHVOAIZywAHB+ORZYZKEiE=";
          dontBuild = true;
          installPhase = ''
            mkdir -p $out
            cp -r node_modules $out/
          '';
        };

        ps = purs-nix.purs {
          dependencies = with purs-nix.ps-pkgs; [
            aff
            affjax
            affjax-node-with-xhr2
            affjax-web
            arrays
            purs-nix.ps-pkgs."assert"
            avar
            console
            datetime
            effect
            either
            free
            freeap
            maybe
            node-buffer
            node-process
            node-fs
            now
            parallel
            prelude
            spec
            spec-node
            strings
            transformers
            tuples
            unfoldable
            variant
          ];

          dir = ./.;
        };

        programCoreSource = pkgs.lib.fileset.toSource {
          root = ./.;
          fileset = ./src/Control/Monad/Program/Core.purs;
        };
        programCore = purs-nix.purs {
          srcs = [ "${programCoreSource}/src" ];
          dependencies = [
            "prelude"
            "free"
            "freeap"
            "variant"
            "newtype"
            "tailrec"
          ];
        };

        # Source files for linting/formatting
        purescriptSources = pkgs.lib.fileset.unions [
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "purs") ./src)
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "purs") ./test)
        ];
      in
      {
        packages = {
          program-core-source = programCoreSource;
          program-core-node = programCore.output { };
          default = ps.bundle { };

          # Linting
          lint = pkgs.stdenv.mkDerivation {
            pname = "purescript-parallel-effects-lint";
            version = "1.0.0";

            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                purescriptSources
                (pkgs.lib.fileset.maybeMissing ./whine.yaml)
              ];
            };

            nativeBuildInputs = [
              purescript-whine
              pkgs.fd
            ];

            dontBuild = true;

            checkPhase = ''
              runHook preCheck

              echo "🔍 Running PureScript whine check..."
              whine 'src/**/*.purs' || {
                echo "❌ PureScript whine check failed! Please fix violations."
                exit 1
              }

              echo "✅ PureScript whine check passed"

              runHook postCheck
            '';

            doCheck = true;

            installPhase = ''
              mkdir -p $out
              echo "Lint checks passed" > $out/result
            '';
          };

          demo = ps.bundle {
            module = "Demo";
            esbuild = {
              platform = "node";
              format = "cjs";
              external = [
                "xhr2"
                "url"
              ];
            };
          };
          demo-composition = ps.bundle {
            module = "DemoComposition";
            esbuild = {
              platform = "node";
              format = "cjs";
              external = [
                "xhr2"
                "url"
              ];
            };
          };
          demo-multi-effect = ps.bundle {
            module = "DemoMultiEffect";
            esbuild = {
              platform = "node";
              format = "cjs";
              external = [
                "xhr2"
                "url"
              ];
            };
          };
          demo-composed = ps.bundle {
            module = "DemoComposed";
            esbuild = {
              platform = "node";
              format = "cjs";
              external = [
                "xhr2"
                "url"
              ];
            };
          };
          test = ps.test.run { };

          # BDD runner (PureScript CLI used by step definitions)
          bdd-runner = ps.bundle {
            module = "Test.BDD.Runner";
            esbuild = {
              platform = "node";
              format = "cjs";
              external = [
                "xhr2"
                "url"
              ];
            };
          };

          # No separate bdd-cli; use Node to run our script with NODE_PATH to deps
        };

        apps = {
          default = {
            type = "app";
            program = "${ps.bundle { }}/bin/index.js";
            meta.description = "Main application entry point";
          };

          demo =
            let
              demoBundle = ps.bundle {
                module = "Demo";
                esbuild = {
                  platform = "node";
                  format = "cjs";
                  external = [
                    "xhr2"
                    "url"
                  ];
                };
              };
            in
            {
              type = "app";
              program = "${pkgs.writeShellScript "run-demo" ''
                ${pkgs.nodejs}/bin/node ${demoBundle}
              ''}";
              meta.description = "Demo: parallel HTTP requests with Program";
            };

          demo-composition =
            let
              demoBundle = ps.bundle {
                module = "DemoComposition";
                esbuild = {
                  platform = "node";
                  format = "cjs";
                  external = [
                    "xhr2"
                    "url"
                  ];
                };
              };
            in
            {
              type = "app";
              program = "${pkgs.writeShellScript "run-demo-composition" ''
                ${pkgs.nodejs}/bin/node ${demoBundle}
              ''}";
              meta.description = "Demo: elegant effect composition with row polymorphism";
            };

          demo-multi-effect =
            let
              demoBundle = ps.bundle {
                module = "DemoMultiEffect";
                esbuild = {
                  platform = "node";
                  format = "cjs";
                  external = [
                    "xhr2"
                    "url"
                  ];
                };
              };
            in
            {
              type = "app";
              program = "${pkgs.writeShellScript "run-demo-multi-effect" ''
                ${pkgs.nodejs}/bin/node ${demoBundle}
              ''}";
              meta.description = "Demo: composing multiple effect types (HTTP + Logging + FileSystem)";
            };

          demo-composed =
            let
              demoBundle = ps.bundle {
                module = "DemoComposed";
                esbuild = {
                  platform = "node";
                  format = "cjs";
                  external = [
                    "xhr2"
                    "url"
                  ];
                };
              };
            in
            {
              type = "app";
              program = "${pkgs.writeShellScript "run-demo-composed" ''
                ${pkgs.nodejs}/bin/node ${demoBundle}
              ''}";
              meta.description = "Demo: composing effects with multiple handlers";
            };

          test = {
            type = "app";
            program = "${pkgs.writeShellScript "run-tests" ''
              exec ${ps.test.run { }} "$@"
            ''}";
            meta.description = "Run PureScript test suite";
          };

          format-fix = {
            type = "app";
            program = "${pkgs.writeShellScript "format-fix" ''
              echo "🎨 Formatting all files with treefmt (Nix + PureScript)..."
              exec ${treefmtEval.config.build.wrapper}/bin/treefmt "$@"
            ''}";
            meta.description = "Format all files (Nix + PureScript)";
          };

          # BDD markdown wrappers (use Node + packaged deps)
          test-playback = {
            type = "app";
            program = "${pkgs.writeShellScript "run-bdd-playback" ''
              set -euo pipefail
              export BDD_RUNNER="${self.packages.${system}.bdd-runner}"
              export NODE_PATH="${bddNodeDeps}/node_modules"
              exec ${pkgs.nodejs}/bin/node ./test/bdd/runner.mjs "$@"
            ''}";
            meta.description = "Run BDD Markdown specs in playback (offline) mode";
          };

          test-live = {
            type = "app";
            program = "${pkgs.writeShellScript "run-bdd-live" ''
              set -euo pipefail
              export BDD_RUNNER="${self.packages.${system}.bdd-runner}"
              export NODE_PATH="${bddNodeDeps}/node_modules"
              exec ${pkgs.nodejs}/bin/node ./test/bdd/runner.mjs "$@"
            ''}";
            meta.description = "Run BDD Markdown specs in live (impure) mode";
          };

          test-record = {
            type = "app";
            program = "${pkgs.writeShellScript "run-bdd-record" ''
              set -euo pipefail
              export BDD_RUNNER="${self.packages.${system}.bdd-runner}"
              export NODE_PATH="${bddNodeDeps}/node_modules"
              exec ${pkgs.nodejs}/bin/node ./test/bdd/runner.mjs "$@"
            ''}";
            meta.description = "Run BDD Markdown specs in record (impure) mode";
          };
        };

        checks = {
          build-program-core = programCore.output { };
          lint = self.packages.${system}.lint;
          formatting = treefmtEval.config.build.check self;
          build = ps.bundle { };
          test = ps.test.run { };
          bdd =
            pkgs.runCommand "bdd-specs"
              {
                BDD_RUNNER = "${self.packages.${system}.bdd-runner}";
                NODE_PATH = "${bddNodeDeps}/node_modules";
              }
              ''
                set -euo pipefail
                cp -r ${./test/bdd} ./bdd
                cp -r ${./test/features} ./features
                ${pkgs.nodejs}/bin/node ./bdd/runner.mjs ./features > report.txt
                mkdir -p $out
                cp report.txt $out/
              '';
        };

        formatter = treefmtEval.config.build.wrapper;

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
      }
    );
}
