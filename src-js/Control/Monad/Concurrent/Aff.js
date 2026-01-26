// FFI for Control.Monad.Concurrent.Aff (JavaScript backend)
//
// These functions convert between Aff.Fiber and our abstract Fiber type.
// At runtime, both are the same object - these are identity functions
// that exist purely to satisfy PureScript's type system without using unsafeCoerce.

// Convert an Aff.Fiber to our abstract Fiber type.
// This is an identity function at runtime.
export const toFiber = (affFiber) => affFiber;

// Convert our abstract Fiber type back to Aff.Fiber.
// This is an identity function at runtime.
export const fromFiber = (fiber) => fiber;

// Suppress the "rethrow on unjoined error" behavior for a fiber.
// Aff fibers by default will rethrow errors if they complete with an error
// before being joined. We suppress this because we want errors to be
// delivered through join() as Left values, not thrown as exceptions.
export const suppressRethrow = (fiber) => () => {
  fiber.onComplete({
    rethrow: false,
    handler: (_) => () => {}  // No-op handler
  })();  // Execute the Effect returned by onComplete
};
