// ESLint configuration for PureScript FFI files
//
// This configuration enforces the FFI guidelines from CLAUDE.md:
// - FFI should be "thin stubs only" - just calling external libs or performing I/O
// - No business logic, data transforms, or string manipulation
// - Forbidden: local imports, format/map operations, string templates, validation logic

export default [
  {
    files: ["src/**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
    },
    rules: {
      // Disallow local/relative imports - FFI should only call into external libs
      // This catches patterns like: import { helper } from "../../js/tool.js"
      "no-restricted-syntax": [
        "error",
        {
          selector: "ImportDeclaration[source.value=/^\\.\\.?\\//]",
          message: "FFI files must not use relative imports. Move logic to PureScript."
        },
        // Disallow Array.prototype.map - indicates data transformation
        {
          selector: "CallExpression[callee.property.name='map']",
          message: "FFI files should not transform data with .map(). Move logic to PureScript."
        },
        // Disallow Array.prototype.filter - indicates data transformation
        {
          selector: "CallExpression[callee.property.name='filter']",
          message: "FFI files should not transform data with .filter(). Move logic to PureScript."
        },
        // Disallow Array.prototype.reduce - indicates data transformation
        {
          selector: "CallExpression[callee.property.name='reduce']",
          message: "FFI files should not transform data with .reduce(). Move logic to PureScript."
        },
        // Disallow Array.prototype.join - indicates string formatting
        {
          selector: "CallExpression[callee.property.name='join']",
          message: "FFI files should not format strings with .join(). Move logic to PureScript."
        },
        // Disallow string split - indicates parsing/transformation
        {
          selector: "CallExpression[callee.property.name='split']",
          message: "FFI files should not parse strings with .split(). Move logic to PureScript."
        },
        // Disallow regex test/match - indicates validation logic
        {
          selector: "CallExpression[callee.property.name='test'][callee.object.type='Literal']",
          message: "FFI files should not use regex validation. Move logic to PureScript."
        },
        // Disallow if statements with more than trivial nesting (allows single if for error checks)
        {
          selector: "IfStatement IfStatement IfStatement",
          message: "FFI files should not contain nested conditionals. Move logic to PureScript."
        },
        // Disallow for loops - indicates iteration logic
        {
          selector: "ForStatement",
          message: "FFI files should not use for loops. Move logic to PureScript."
        },
        // Disallow for...of loops - indicates iteration logic
        {
          selector: "ForOfStatement",
          message: "FFI files should not use for...of loops. Move logic to PureScript."
        },
        // Disallow for...in loops - indicates object iteration
        {
          selector: "ForInStatement",
          message: "FFI files should not use for...in loops. Move logic to PureScript."
        },
        // Disallow while loops - indicates iterative logic
        {
          selector: "WhileStatement",
          message: "FFI files should not use while loops. Move logic to PureScript."
        },
        // Disallow switch statements - indicates complex branching
        {
          selector: "SwitchStatement",
          message: "FFI files should not use switch statements. Move logic to PureScript."
        },
      ],

      // Disallow template literals (string interpolation is string formatting)
      // Exception: error messages are OK
      "no-template-curly-in-string": "off",

      // Warn on functions longer than ~15 lines (FFI should be simple stubs)
      "max-lines-per-function": ["warn", {
        max: 25,
        skipBlankLines: true,
        skipComments: true,
        IIFEs: true
      }],

      // Limit cyclomatic complexity (FFI should have simple control flow)
      "complexity": ["warn", { max: 5 }],

      // Limit nesting depth
      "max-depth": ["warn", { max: 2 }],

      // Standard good practices
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "no-undef": "error",
      "no-eval": "error",
      "no-implied-eval": "error",
      "no-new-func": "error",
    },

    linterOptions: {
      reportUnusedDisableDirectives: true,
    },
  },
];
