// FFI for Control.Monad.Program

// -----------------------------------------------------------------------------
// CONSTRUCTOR INTROSPECTION WARNING
// -----------------------------------------------------------------------------
//
// This module inspects JavaScript constructor names at runtime to pattern match
// on the internal structure of FreeAp values from purescript-free. This is a
// form of structural introspection that has inherent fragility.
//
// WHY WE INSPECT CONSTRUCTOR NAMES
// --------------------------------
// PureScript's FreeAp type (from Control.Applicative.Free) is opaque - it
// doesn't export its constructors. However, to implement parallel execution
// we need to detect when we have an Ap node (applicative composition) so we
// can fork both branches and run them concurrently.
//
// The FreeAp data type has three constructors:
//   - Pure a           : A pure value wrapped in FreeAp
//   - Lift (f a)       : A single lifted effect
//   - Ap (FreeAp f (x -> a)) (FreeAp f x) : Applicative composition
//
// In JavaScript, these become constructor functions, and we can identify
// them by checking constructor.name.
//
// MINIFICATION PATTERNS HANDLED
// -----------------------------
// When code is bundled with tools like esbuild, webpack, or rollup, constructor
// function names may be renamed to avoid naming conflicts with other modules:
//
//   Original    | esbuild (typical)  | Description
//   ------------|-------------------|------------------------------------
//   Pure        | Pure2, Pure$1     | Pure value constructor
//   Lift        | Lift2, Lift$1     | Lifted effect constructor
//   Ap          | Ap2, Ap$1         | Applicative composition constructor
//
// We handle this by checking for both the original names AND common suffixed
// variants. The current implementation checks:
//   - Pure, Pure2
//   - Lift, Lift2
//   - Ap, Ap2
//
// WHAT COULD BREAK THIS
// ---------------------
// 1. PROPERTY MANGLING: If a minifier mangles property names (not just
//    function names), constructor.name could become something like "a" or "b".
//    Most minifiers don't do this by default because it breaks instanceof.
//
// 2. DIFFERENT SUFFIX PATTERNS: Some bundlers might use different naming
//    conventions like Pure$1, Pure_1, or _Pure. We only handle the "2" suffix.
//
// 3. OBFUSCATORS: Code obfuscators that deliberately obscure structure
//    (e.g., renaming to random strings) will break this approach.
//
// 4. TERSER WITH mangle.properties: If terser is configured with aggressive
//    property mangling, constructor names could be affected.
//
// 5. FUTURE BUNDLER CHANGES: Bundler naming conventions could change in
//    future versions.
//
// ALTERNATIVE APPROACHES CONSIDERED
// ---------------------------------
// 1. TYPE TAGS: Add a Symbol or string tag property to each constructor.
//    Rejected because FreeAp is from an external library we don't control.
//
// 2. STRUCTURAL CHECKS: Detect constructors by checking which properties
//    exist (e.g., Ap has value0 and value1, Lift has only value0).
//    Rejected because Pure and Lift both have value0, making them ambiguous.
//
// 3. WRAPPER TYPE: Create our own FreeAp-like type with explicit tags.
//    Rejected because it would require duplicating significant code from
//    purescript-free and would break interop with existing code.
//
// 4. FORK PURESCRIPT-FREE: Modify the library to export constructors or
//    add pattern matching helpers. This is the most robust solution but
//    adds maintenance burden.
//
// RUNTIME VALIDATION
// ------------------
// To catch minification issues early, we validate constructor names on first
// use. If validation fails, the code throws an informative error explaining
// the issue and potential fixes. See validateFreeApConstructors below.
//
// REMEDIATION
// -----------
// If minification breaks this code:
// 1. Configure the bundler to preserve constructor names for the freeap module
//    (e.g., esbuild: { keepNames: true } or terser: { keep_fnames: true })
// 2. Add the new constructor name patterns to the checks below
// 3. Consider forking purescript-free to add explicit pattern matching support
//
// -----------------------------------------------------------------------------

// Track whether we've validated constructor names
let constructorNamesValidated = false;

// Validate that FreeAp constructor names are what we expect
// This runs once on first use and throws an informative error if broken
function validateFreeApConstructors(freeAp) {
  if (constructorNamesValidated) return;

  const name = freeAp.constructor.name;
  const validNames = ["Pure", "Pure2", "Lift", "Lift2", "Ap", "Ap2"];

  if (!validNames.includes(name)) {
    throw new Error(
      "FreeAp constructor introspection failed!\n\n" +
      // eslint-disable-next-line no-restricted-syntax -- Error message formatting is acceptable
      "Expected constructor name to be one of: " + validNames.join(", ") + "\n" +
      "Actual constructor name: " + JSON.stringify(name) + "\n\n" +
      "This usually means your JavaScript bundler has mangled constructor names.\n\n" +
      "Fixes:\n" +
      "1. Configure your bundler to preserve function names:\n" +
      "   - esbuild: { keepNames: true }\n" +
      "   - terser: { keep_fnames: true }\n" +
      "   - webpack: optimization.minimize: false (for debugging)\n" +
      "2. Or add the new constructor name pattern to Program.js\n\n" +
      "See the CONSTRUCTOR INTROSPECTION WARNING comment in Program.js for details."
    );
  }

  constructorNamesValidated = true;
}

// Pattern match on FreeAp structure using continuation-passing style
// FreeAp has three constructors: Pure, Lift, and Ap
// This approach avoids needing explicit existential types in PureScript
//
// LINT EXCEPTION: This function requires:
// - complexity > 5 (multiple constructor cases)
// - nested conditionals (else-if chain for pattern matching)
// See CONSTRUCTOR INTROSPECTION WARNING comment above for full justification.
/* eslint-disable complexity, no-restricted-syntax */
export const matchFreeApView = function(onPure) {
  return function(onLift) {
    return function(onAp) {
      return function(freeAp) {
        // Validate constructor names on first use (fail-fast if minified incorrectly)
        validateFreeApConstructors(freeAp);

        // Get constructor name - esbuild may rename inner functions
        const name = freeAp.constructor.name;

        // Check constructor by name (handles both original and bundler-renamed versions)
        if (name === "Pure" || name === "Pure2") {
          // Pure has value0 = the pure value
          return onPure(freeAp.value0);
        } else if (name === "Lift" || name === "Lift2") {
          // Lift has value0 = the lifted functor value
          return onLift(freeAp.value0);
        } else if (name === "Ap" || name === "Ap2") {
          // Ap has value0 = FreeAp f (x -> a), value1 = FreeAp f x
          return onAp(freeAp.value0)(freeAp.value1);
        } else {
          // Should never happen
          throw new Error("Unknown FreeAp constructor: " + name);
        }
      };
    };
  };
};
/* eslint-enable complexity, no-restricted-syntax */
