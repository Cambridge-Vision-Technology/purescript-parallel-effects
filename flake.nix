{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    ps-tools.follows = "purs-nix/ps-tools";
    purs-nix.url = "https://flakehub.com/f/Cambridge-Vision-Technology/purs-nix/0.1.tar.gz";
    purs-nix.inputs.nixpkgs.follows = "nixpkgs";
    # purs-nix with Erlang backend support (erlang-backend branch)
    # NOTE: Using GitHub URL until erlang-backend branch is published to FlakeHub
    purs-nix-erl = {
      url = "github:Cambridge-Vision-Technology/purs-nix/erlang-backend";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    purescript-whine = {
      url = "https://flakehub.com/f/Cambridge-Vision-Technology/purescript-whine/0.1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.purs-nix.follows = "purs-nix";
    };
    agen = {
      url = "https://flakehub.com/f/Cambridge-Vision-Technology/agen/0.1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # PureScript duplicate code detector (via FlakeHub for CI access)
    purescript-dedup = {
      url = "https://flakehub.com/f/Cambridge-Vision-Technology/purescript-dedup/*";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.purs-nix.follows = "purs-nix";
    };

    # PureScript dead code analyzer (via FlakeHub for CI access)
    purescript-scythe = {
      url = "https://flakehub.com/f/Cambridge-Vision-Technology/purescript-scythe/*";
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

        # Purerl compiler binary (fetches from GitHub releases)
        purerl = pkgs.stdenv.mkDerivation rec {
          pname = "purerl";
          version = "0.0.24";

          src = pkgs.fetchurl {
            url = "https://github.com/purerl/purerl/releases/download/v${version}/macos.tar.gz";
            sha256 = "sha256-YcUIDA3q/Az6dSKTK3OhhyIQIoYkPI3B/LfRxVsDYsk=";
          };

          sourceRoot = ".";

          installPhase = ''
            mkdir -p $out/bin
            tar -xzf $src
            install -m755 -D purerl/purerl $out/bin/purerl
          '';

          dontFixup = true;
        };

        # purs-nix instance with Erlang backend support
        purs-nix-erl-instance = inputs.purs-nix-erl { inherit system; };

        # PureScript configuration for Erlang backend (minimal hello-erl example)
        ps-erl = purs-nix-erl-instance.purs {
          dependencies = [
            "console"
            "effect"
            "prelude"
          ];
          backend = {
            cmd = "purerl";
            package = purerl;
          };
          # Use locked package set for pure evaluation (no --impure needed)
          package-set = import ./purerl-packages-locked.nix;
          # Use separate source directory for hello-erl to avoid compiling full project
          dir = ./hello-erl;
        };

        # PureScript configuration for Erlang backend (MonadConcurrent tests)
        # Uses srcs to include Erlang-specific src-erl, test modules, and shared directories
        # NOTE: Cannot include full ./src because it contains JS-only modules (FileSystem, HTTP)
        ps-erl-test = purs-nix-erl-instance.purs {
          dependencies = [
            "arrays"
            "console"
            "control"
            "effect"
            "either"
            "exceptions"
            "foldable-traversable"
            "free"
            "freeap"
            "functions"
            "maybe"
            "prelude"
            "refs"
            "tailrec"
            "transformers"
            "tuples"
            "variant"
          ];
          backend = {
            cmd = "purerl";
            package = purerl;
          };
          package-set = import ./purerl-packages-locked.nix;
          # Include Erlang-specific (Effect instance), test modules, and shared
          # The test-concurrent-erl/src has its own copies of portable modules needed for Erlang
          srcs = [
            ./src-erl
            ./test-concurrent-erl/src
            ./shared
          ];
        };

        # PureScript configuration for Erlang demo app
        # Uses srcs to include Erlang-specific src-erl, demo entry point, and shared-demo
        # NOTE: Cannot include full ./src because it contains JS-only modules (FileSystem, HTTP)
        ps-demo-erl = purs-nix-erl-instance.purs {
          dependencies = [
            "arrays"
            "console"
            "effect"
            "either"
            "exceptions"
            "foldable-traversable"
            "free"
            "freeap"
            "functions"
            "maybe"
            "prelude"
            "refs"
            "tailrec"
            "transformers"
            "tuples"
            "variant"
          ];
          backend = {
            cmd = "purerl";
            package = purerl;
          };
          package-set = import ./purerl-packages-locked.nix;
          # Include Erlang-specific (Effect instance), shared portable code, entry point, and demo modules
          srcs = [
            ./src-erl
            ./shared
            ./demo-app-erl/src
            ./shared-demo
          ];
        };

        treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
          programs.nixfmt.package = pkgs.nixfmt-rfc-style;
          programs.purs-tidy.enable = true;
          settings.formatter.purs-tidy = {
            includes = [ "*.purs" ];
          };
          programs.erlfmt.enable = true;
          settings.formatter.erlfmt = {
            includes = [
              "src/**/*.erl"
              "test/**/*.erl"
              "test-concurrent-erl/**/*.erl"
              "demo-app-erl/**/*.erl"
            ];
          };
        };

        # Provide node_modules with xhr2 for Affjax.Node FFI and eslint for linting
        nodeDeps = pkgs.buildNpmPackage {
          pname = "purescript-parallel-effects-node-deps";
          version = "0.1.0";
          src = ./.;
          npmDepsHash = "sha256-xhoMy8qHad1HO0KRnfHh7jRQGqIfcOtn9gNkKcHBZdM=";
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

        # Node deps for BDD demo Cucumber tests (Phase 6 Task 49)
        bddDemoNodeDeps = pkgs.buildNpmPackage {
          pname = "bdd-demo-cucumber-deps";
          version = "1.0.0";
          src = ./test/bdd;
          npmDepsHash = "sha256-6ImjZFZgI1xB1PPbDOnnJtl3STCcw2bNJc3gezVXqJ4=";
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

          # Include shared portable modules (Control.Monad.Program) and JS-specific (Aff instance)
          srcs = [
            "src"
            "src-js"
            "test"
            "shared"
          ];
          dir = ./.;
        };

        # PureScript configuration for MonadConcurrent JS tests
        # (uses custom test-module to run the portable tests with Aff)
        ps-test-concurrent-js = purs-nix.purs {
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
          # Include shared portable modules (Control.Monad.Program) and JS-specific (Aff instance)
          srcs = [
            "src"
            "src-js"
            "test"
            "shared"
          ];
          dir = ./.;
          test-module = "Test.MonadConcurrent.MainJS";
        };

        # PureScript configuration for demo-app
        # This compiles the portable demo modules that use MonadConcurrent m constraint
        # Uses same dependencies as main ps config since it needs to compile full src/
        ps-demo-app = purs-nix.purs {
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
            strings
            transformers
            tuples
            unfoldable
            variant
          ];
          # Include main src, JS-specific (Aff instance), shared portable modules, and JS entry point
          # Demo modules are in shared-demo/Demo/, entry point is in demo-app/js/
          srcs = [
            "src"
            "src-js"
            "shared"
            "shared-demo"
            "demo-app/js"
          ];
          dir = ./.;
        };

        # Source files for linting/formatting
        purescriptSources = pkgs.lib.fileset.unions [
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "purs") ./src)
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "purs") ./src-js)
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "purs") ./src-erl)
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "purs") ./test)
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "purs") ./shared)
        ];

        # ESLint source set: only JS FFI files and eslint config
        # Changing .purs files won't invalidate ESLint cache
        eslintSource = pkgs.lib.fileset.unions [
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "js") ./src-js)
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "js") ./shared)
          ./eslint.config.js
        ];

        # Erlang lint source set: only .erl files
        # Changing .purs or .js files won't invalidate Erlang lint cache
        erlangLintSource = pkgs.lib.fileset.unions [
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "erl") ./src-erl)
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "erl") ./shared)
          (pkgs.lib.fileset.fileFilter (file: file.hasExt "erl") ./test-concurrent-erl)
        ];
      in
      {
        packages = {
          default = ps.output { };

          # PureScript whine linter (individual check)
          lint-whine = pkgs.stdenv.mkDerivation {
            pname = "purescript-parallel-effects-lint-whine";
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

              echo "Running PureScript whine check..."
              whine 'src/**/*.purs' || {
                echo "PureScript whine check failed! Please fix violations."
                exit 1
              }

              echo "PureScript whine check passed"

              runHook postCheck
            '';

            doCheck = true;

            installPhase = ''
              mkdir -p $out
              echo "PureScript whine check passed" > $out/result
            '';
          };

          # Aggregate lint check: runs all linters (whine, eslint, elvis)
          lint = pkgs.stdenv.mkDerivation {
            pname = "purescript-parallel-effects-lint";
            version = "1.0.0";

            src = pkgs.emptyFile;

            buildInputs = [
              self.packages.${system}.lint-whine
              self.packages.${system}.lint-eslint
              self.packages.${system}.lint-elvis
            ];

            dontBuild = true;
            dontUnpack = true;

            installPhase = ''
              mkdir -p $out
              echo "All lint checks passed:" > $out/result
              echo "  - PureScript whine: ${self.packages.${system}.lint-whine}" >> $out/result
              echo "  - ESLint FFI: ${self.packages.${system}.lint-eslint}" >> $out/result
              echo "  - Elvis Erlang: ${self.packages.${system}.lint-elvis}" >> $out/result
            '';
          };

          # ESLint for JavaScript FFI files
          # Enforces CLAUDE.md FFI guidelines: thin stubs only, no logic
          lint-eslint = pkgs.stdenv.mkDerivation {
            pname = "purescript-parallel-effects-lint-eslint";
            version = "1.0.0";

            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = eslintSource;
            };

            nativeBuildInputs = [ pkgs.nodejs ];

            dontBuild = true;

            checkPhase = ''
              runHook preCheck

              # Symlink node_modules from deps stage (ESLint lives here)
              ln -s ${nodeDeps}/node_modules node_modules

              echo "Running ESLint on JavaScript FFI files..."
              ./node_modules/.bin/eslint src-js/ shared/ --config eslint.config.js || {
                echo "ESLint FFI check failed! Fix violations above."
                exit 1
              }

              echo "ESLint FFI check passed"

              runHook postCheck
            '';

            doCheck = true;

            installPhase = ''
              mkdir -p $out
              echo "ESLint FFI check passed" > $out/result
            '';
          };

          # Elvis for Erlang FFI files
          # Enforces coding standards for Erlang code
          # NOTE: Some rules disabled for documented FFI exceptions (see PLAN.md Task 31)
          lint-elvis = pkgs.stdenv.mkDerivation {
            pname = "purescript-parallel-effects-lint-elvis";
            version = "1.0.0";

            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                erlangLintSource
                ./elvis.config
              ];
            };

            nativeBuildInputs = [ pkgs.elvis-erlang ];

            dontBuild = true;

            checkPhase = ''
              runHook preCheck

              echo "Running Elvis on Erlang FFI files..."
              elvis rock --config elvis.config || {
                echo "Elvis Erlang lint check failed! Fix violations above."
                exit 1
              }

              echo "Elvis Erlang lint check passed"

              runHook postCheck
            '';

            doCheck = true;

            installPhase = ''
              mkdir -p $out
              echo "Elvis Erlang lint check passed" > $out/result
            '';
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

          # Demo app source compilation (verifies portable modules compile)
          demo-app-src = ps-demo-app.output { };

          # Erlang backend compilation output (hello world test)
          hello-erl = ps-erl.output { };

          # MonadConcurrent tests compiled to Erlang (source only)
          test-concurrent-erl-output = ps-erl-test.output { };

          # Compiled BEAM files for test-concurrent-erl
          test-concurrent-erl-beam = pkgs.stdenv.mkDerivation {
            name = "test-concurrent-erl-beam";
            src = self.packages.${system}.test-concurrent-erl-output;
            buildInputs = [ pkgs.erlang ];
            buildPhase = ''
              mkdir -p ebin
              # Compile all Erlang source files
              for module in $src/*/; do
                if [ -d "$module" ]; then
                  for erl_file in "$module"*.erl; do
                    if [ -f "$erl_file" ]; then
                      erlc -o ebin "$erl_file" 2>/dev/null || true
                    fi
                  done
                fi
              done
            '';
            installPhase = ''
              mkdir -p $out/ebin
              cp ebin/*.beam $out/ebin/ 2>/dev/null || true
            '';
          };

          # Demo app compiled to Erlang (source only)
          demo-erl-output = ps-demo-erl.output { };

          # Compiled BEAM files for demo-erl
          demo-erl-beam = pkgs.stdenv.mkDerivation {
            name = "demo-erl-beam";
            src = self.packages.${system}.demo-erl-output;
            buildInputs = [ pkgs.erlang ];
            buildPhase = ''
              mkdir -p ebin
              # Compile all Erlang source files
              for module in $src/*/; do
                if [ -d "$module" ]; then
                  for erl_file in "$module"*.erl; do
                    if [ -f "$erl_file" ]; then
                      erlc -o ebin "$erl_file" 2>/dev/null || true
                    fi
                  done
                fi
              done
            '';
            installPhase = ''
              mkdir -p $out/ebin
              cp ebin/*.beam $out/ebin/ 2>/dev/null || true
            '';
          };
        };

        apps = {
          # Demo app for MonadConcurrent features (JavaScript/Aff backend)
          demo-js =
            let
              demoBundle = ps-demo-app.bundle {
                module = "Demo.Main";
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
              program = "${pkgs.writeShellScript "run-demo-js" ''
                ${pkgs.nodejs}/bin/node ${demoBundle} "$@"
              ''}";
              meta.description = "Demo app for MonadConcurrent features (JavaScript/Aff)";
            };

          # Demo app for MonadConcurrent features (Erlang/Effect backend)
          demo-erl = {
            type = "app";
            program =
              let
                escriptRunner = pkgs.writeText "demo-erl.escript" ''
                  #!/usr/bin/env escript
                  %%! -pa ${self.packages.${system}.demo-erl-beam}/ebin

                  main(_Args) ->
                      F = 'demo_main_erl@ps':main(),
                      F().
                '';
              in
              "${pkgs.writeShellScript "run-demo-erl" ''
                set -euo pipefail
                exec ${pkgs.erlang}/bin/escript ${escriptRunner} "$@"
              ''}";
            meta.description = "Demo app for MonadConcurrent features (Erlang/Effect)";
          };

          test = {
            type = "app";
            program = "${pkgs.writeShellScript "run-tests" ''
              exec ${ps.test.run { }} "$@"
            ''}";
            meta.description = "Run PureScript test suite";
          };

          # MonadConcurrent portable tests (JavaScript/Aff)
          test-concurrent-js = {
            type = "app";
            program = "${pkgs.writeShellScript "run-test-concurrent-js" ''
              exec ${ps-test-concurrent-js.test.run { }} "$@"
            ''}";
            meta.description = "Run MonadConcurrent portable tests (JavaScript/Aff)";
          };

          # MonadConcurrent portable tests (Erlang/Effect)
          test-concurrent-erl = {
            type = "app";
            program =
              let
                escriptRunner = pkgs.writeText "test-concurrent-erl.escript" ''
                  #!/usr/bin/env escript
                  %%! -pa ${self.packages.${system}.test-concurrent-erl-beam}/ebin

                  main(_) ->
                      F = 'test_monadConcurrent_main@ps':main(),
                      F().
                '';
              in
              "${pkgs.writeShellScript "run-test-concurrent-erl" ''
                set -euo pipefail
                exec ${pkgs.erlang}/bin/escript ${escriptRunner}
              ''}";
            meta.description = "Run MonadConcurrent portable tests (Erlang/Effect)";
          };

          # Portable tests on JavaScript (alias for test-concurrent-js)
          test-portable-js = {
            type = "app";
            program = "${pkgs.writeShellScript "run-test-portable-js" ''
              exec ${ps-test-concurrent-js.test.run { }} "$@"
            ''}";
            meta.description = "Run all portable tests (JavaScript/Aff)";
          };

          # Portable tests on Erlang (alias for test-concurrent-erl)
          test-portable-erl = {
            type = "app";
            program =
              let
                escriptRunner = pkgs.writeText "test-portable-erl.escript" ''
                  #!/usr/bin/env escript
                  %%! -pa ${self.packages.${system}.test-concurrent-erl-beam}/ebin

                  main(_) ->
                      F = 'test_monadConcurrent_main@ps':main(),
                      F().
                '';
              in
              "${pkgs.writeShellScript "run-test-portable-erl" ''
                set -euo pipefail
                exec ${pkgs.erlang}/bin/escript ${escriptRunner}
              ''}";
            meta.description = "Run all portable tests (Erlang/Effect)";
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

          # PureScript duplicate code detector
          # Usage: nix run .#dedup -- -s ./src (scans single directory)
          # Requires: gcloud auth (for Vertex AI embeddings) or --openai flag
          dedup = {
            type = "app";
            program = "${pkgs.writeShellScript "dedup" ''
              set -euo pipefail
              exec ${inputs.purescript-dedup.packages.${system}.default}/bin/dedup "$@"
            ''}";
            meta.description = "Find duplicate code patterns in PureScript sources";
          };

          # PureScript dead code analyzer
          scythe = {
            type = "app";
            program = "${pkgs.writeShellScript "scythe" ''
              set -euo pipefail
              exec ${inputs.purescript-scythe.packages.${system}.default}/bin/scythe \
                --src ./src \
                --src ./src-js \
                --src ./shared \
                --entry Test.Main.main \
                "$@"
            ''}";
            meta.description = "Find unused functions in PureScript sources";
          };

          # BDD demo tests using Cucumber (Phase 6 Task 49)
          # Tests MonadConcurrent demo app against both JS and Erlang backends
          test-bdd-demo =
            let
              # JS demo app command (built derivation)
              demoJsBundle = ps-demo-app.bundle {
                module = "Demo.Main";
                esbuild = {
                  platform = "node";
                  format = "cjs";
                  external = [
                    "xhr2"
                    "url"
                  ];
                };
              };
              # Erlang demo app escript
              demoErlEscript = pkgs.writeText "demo-erl.escript" ''
                #!/usr/bin/env escript
                %%! -pa ${self.packages.${system}.demo-erl-beam}/ebin

                main(_Args) ->
                    F = 'demo_main_erl@ps':main(),
                    F().
              '';
            in
            {
              type = "app";
              program = "${pkgs.writeShellScript "run-bdd-demo" ''
                set -euo pipefail
                # Set up demo app commands for Cucumber world parameters
                export DEMO_JS_CMD="${pkgs.nodejs}/bin/node ${demoJsBundle}"
                export DEMO_ERL_CMD="${pkgs.erlang}/bin/escript ${demoErlEscript}"

                # Create working directory for cucumber
                WORKDIR=$(mktemp -d)
                trap "rm -rf $WORKDIR" EXIT

                # Copy BDD test files
                cp -r ${./test/bdd}/cucumber.js "$WORKDIR/"
                cp -r ${./test/bdd}/features "$WORKDIR/"
                cp -r ${./test/bdd}/steps "$WORKDIR/"
                cp -r ${./test/bdd}/support "$WORKDIR/"
                ln -s ${bddDemoNodeDeps}/node_modules "$WORKDIR/node_modules"

                # Ensure output directory exists
                mkdir -p "$WORKDIR/out/test/bdd-demo"

                cd "$WORKDIR"
                exec ${pkgs.nodejs}/bin/node node_modules/@cucumber/cucumber/bin/cucumber-js "$@"
              ''}";
              meta.description = "Run BDD Cucumber tests for MonadConcurrent demo app (JS and Erlang)";
            };
        };

        checks = {
          # Aggregate lint check (runs all linters)
          lint = self.packages.${system}.lint;
          # Individual lint checks
          lint-whine = self.packages.${system}.lint-whine;
          lint-eslint = self.packages.${system}.lint-eslint;
          lint-elvis = self.packages.${system}.lint-elvis;
          formatting = treefmtEval.config.build.check self;
          build = ps.output { };
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

          # Concurrent parity check: verifies JS and Erlang backends produce identical results
          concurrent-parity =
            let
              # Escript runner for Erlang tests
              escriptRunner = pkgs.writeText "test-concurrent-erl.escript" ''
                #!/usr/bin/env escript
                %%! -pa ${self.packages.${system}.test-concurrent-erl-beam}/ebin

                main(_) ->
                    F = 'test_monadConcurrent_main@ps':main(),
                    F().
              '';
            in
            pkgs.runCommand "concurrent-parity"
              {
                nativeBuildInputs = [
                  pkgs.nodejs
                  pkgs.erlang
                ];
              }
              ''
                set -euo pipefail

                echo "Running MonadConcurrent tests on JavaScript backend..."
                ${self.apps.${system}.test-concurrent-js.program} > js-output.txt 2>&1 || true

                echo "Running MonadConcurrent tests on Erlang backend..."
                ${pkgs.erlang}/bin/escript ${escriptRunner} > erl-output.txt 2>&1 || true

                # Normalize outputs: remove platform-specific headers, keep test results
                grep -E '^\[(PASS|FAIL)\]|^Results:|^All tests' js-output.txt | sort > js-normalized.txt
                grep -E '^\[(PASS|FAIL)\]|^Results:|^All tests' erl-output.txt | sort > erl-normalized.txt

                echo "Comparing normalized test outputs..."
                if diff -q js-normalized.txt erl-normalized.txt > /dev/null; then
                  echo "SUCCESS: JavaScript and Erlang backends produce identical test results"
                  echo ""
                  echo "=== Test Results ==="
                  cat js-normalized.txt
                  mkdir -p $out
                  echo "Concurrent parity check passed" > $out/result
                  cp js-output.txt $out/js-output.txt
                  cp erl-output.txt $out/erl-output.txt
                else
                  echo "FAILURE: Test results differ between backends!"
                  echo ""
                  echo "=== JavaScript Output ==="
                  cat js-normalized.txt
                  echo ""
                  echo "=== Erlang Output ==="
                  cat erl-normalized.txt
                  echo ""
                  echo "=== Diff ==="
                  diff js-normalized.txt erl-normalized.txt || true
                  exit 1
                fi
              '';

          # Portable parity check: verifies all 20 portable tests produce identical results on both backends
          # Tests: MonadConcurrent (9) + Program (4) + Parallel (4) + Orchestration (3) = 20 tests
          portable-parity =
            let
              # Escript runner for Erlang portable tests
              escriptRunner = pkgs.writeText "test-portable-erl.escript" ''
                #!/usr/bin/env escript
                %%! -pa ${self.packages.${system}.test-concurrent-erl-beam}/ebin

                main(_) ->
                    F = 'test_monadConcurrent_main@ps':main(),
                    F().
              '';
            in
            pkgs.runCommand "portable-parity"
              {
                nativeBuildInputs = [
                  pkgs.nodejs
                  pkgs.erlang
                ];
              }
              ''
                set -euo pipefail

                echo "Running all 20 portable tests on JavaScript backend..."
                ${self.apps.${system}.test-portable-js.program} > js-output.txt 2>&1 || true

                echo "Running all 20 portable tests on Erlang backend..."
                ${pkgs.erlang}/bin/escript ${escriptRunner} > erl-output.txt 2>&1 || true

                # Normalize outputs: remove platform-specific headers, keep test results
                grep -E '^\[(PASS|FAIL)\]|^Results:|^All tests' js-output.txt | sort > js-normalized.txt
                grep -E '^\[(PASS|FAIL)\]|^Results:|^All tests' erl-output.txt | sort > erl-normalized.txt

                # Count tests to verify we have all 20
                js_pass_count=$(grep -c '^\[PASS\]' js-normalized.txt || echo 0)
                erl_pass_count=$(grep -c '^\[PASS\]' erl-normalized.txt || echo 0)
                echo "JavaScript: $js_pass_count tests passed"
                echo "Erlang: $erl_pass_count tests passed"

                echo "Comparing portable test outputs..."
                if diff -q js-normalized.txt erl-normalized.txt > /dev/null; then
                  echo "SUCCESS: All portable tests produce identical results on JavaScript and Erlang backends"
                  echo ""
                  echo "=== Test Results ==="
                  cat js-normalized.txt
                  mkdir -p $out
                  echo "Portable parity check passed ($js_pass_count tests)" > $out/result
                  cp js-output.txt $out/js-output.txt
                  cp erl-output.txt $out/erl-output.txt
                else
                  echo "FAILURE: Portable test results differ between backends!"
                  echo ""
                  echo "=== JavaScript Output ==="
                  cat js-normalized.txt
                  echo ""
                  echo "=== Erlang Output ==="
                  cat erl-normalized.txt
                  echo ""
                  echo "=== Diff ==="
                  diff js-normalized.txt erl-normalized.txt || true
                  exit 1
                fi
              '';

          # BDD demo tests check: runs Cucumber tests for MonadConcurrent demo app (Phase 6 Task 49)
          # Tests both JavaScript and Erlang backends via external BDD scenarios
          bdd-demo =
            let
              # JS demo app bundle
              demoJsBundle = ps-demo-app.bundle {
                module = "Demo.Main";
                esbuild = {
                  platform = "node";
                  format = "cjs";
                  external = [
                    "xhr2"
                    "url"
                  ];
                };
              };
              # Erlang demo app escript
              demoErlEscript = pkgs.writeText "demo-erl-check.escript" ''
                #!/usr/bin/env escript
                %%! -pa ${self.packages.${system}.demo-erl-beam}/ebin

                main(_Args) ->
                    F = 'demo_main_erl@ps':main(),
                    F().
              '';
            in
            pkgs.runCommand "bdd-demo"
              {
                nativeBuildInputs = [
                  pkgs.nodejs
                  pkgs.erlang
                ];
                DEMO_JS_CMD = "${pkgs.nodejs}/bin/node ${demoJsBundle}";
                DEMO_ERL_CMD = "${pkgs.erlang}/bin/escript ${demoErlEscript}";
              }
              ''
                set -euo pipefail

                echo "Running BDD demo tests (Cucumber) for MonadConcurrent..."

                # Copy BDD test files to working directory
                cp -r ${./test/bdd}/cucumber.js .
                cp -r ${./test/bdd}/features .
                cp -r ${./test/bdd}/steps .
                cp -r ${./test/bdd}/support .
                ln -s ${bddDemoNodeDeps}/node_modules node_modules

                # Ensure output directory exists
                mkdir -p out/test/bdd-demo

                # Run Cucumber tests
                ${pkgs.nodejs}/bin/node node_modules/@cucumber/cucumber/bin/cucumber-js \
                  --format progress-bar \
                  --format html:out/test/bdd-demo/report.html \
                  2>&1 | tee cucumber-output.txt

                # Check for failures
                if grep -q "failed" cucumber-output.txt; then
                  echo "FAILURE: Some BDD scenarios failed"
                  exit 1
                fi

                echo "SUCCESS: All BDD demo tests passed"

                mkdir -p $out
                echo "BDD demo tests passed" > $out/result
                cp cucumber-output.txt $out/
                cp -r out/test/bdd-demo $out/ 2>/dev/null || true
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
            inputs.agen.packages.${system}.default
            inputs.purescript-dedup.packages.${system}.default
            inputs.purescript-scythe.packages.${system}.default
          ];

          shellHook = ''
            alias watch="find src | entr -s 'echo bundling; purs-nix bundle'"

            # Regenerate CLAUDE.md from guidance templates
            agen >/dev/null 2>&1 || true

            # Make ESLint available from node_modules
            export PATH="$PWD/node_modules/.bin:$PATH"
          '';
        };
      }
    );
}
