# Feature: Applicative law sanity checks
## Scenario: identity
Given a program `u`

When I evaluate pure id applied to u

Then the result equals the result of `u`

## Scenario: homomorphism
Given a pure function `f` and a pure value `x`

When I evaluate pure f applied to pure x

Then the result equals the result of `pure (f x)`

## Scenario: interchange
Given a program `u` and a pure value `y`

When I evaluate u applied to pure y

Then the result equals the result of the interchange form

## Scenario: batch associativity (merge structure)
Given three independent effects `a`, `b`, and `c`

When I applicatively combine them using map and apply

Then the interpreter merges them into a single batch and executes them in parallel
