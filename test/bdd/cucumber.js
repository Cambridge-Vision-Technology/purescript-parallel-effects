// Cucumber configuration for MonadConcurrent demo app BDD tests
//
// This configuration tells Cucumber where to find feature files and step definitions.
// The demo app tests run against both JavaScript (Aff) and Erlang (Effect) backends,
// verifying identical observable behavior across platforms.
//
// Usage:
//   npm test                  # Run all BDD scenarios
//   npm test -- --tags @js    # Run only JavaScript backend tests
//   npm test -- --tags @erl   # Run only Erlang backend tests
//
// Environment variables:
//   DEMO_JS_CMD   - Command to run the JS demo app (default: nix run .#demo-js --)
//   DEMO_ERL_CMD  - Command to run the Erlang demo app (default: nix run .#demo-erl --)

export default {
  // Feature files location
  paths: ['features/**/*.feature'],

  // Step definitions and support files
  import: [
    'support/**/*.js',
    'steps/**/*.js'
  ],

  // Report format
  format: [
    'progress-bar',
    'html:out/test/bdd-demo/report.html'
  ],

  // Fail fast on first failure (useful for CI)
  failFast: false,

  // Parallel execution disabled (tests may share filesystem state)
  parallel: 1,

  // Timeout for each step (30 seconds should be plenty)
  timeout: 30000,

  // World parameters (can be overridden via CLI)
  worldParameters: {
    // Demo app commands - set via environment or use defaults
    demoJsCmd: process.env.DEMO_JS_CMD || 'nix run .#demo-js --',
    demoErlCmd: process.env.DEMO_ERL_CMD || 'nix run .#demo-erl --'
  }
};
