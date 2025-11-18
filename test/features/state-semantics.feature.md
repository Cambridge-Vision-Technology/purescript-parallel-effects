# Feature: State semantics under batching

## Scenario: two parallel increments yield final state 2
Given an initial state 0

When I applicatively combine two operations that increment state by 1

Then the final state equals 2

And the order of intermediate updates is nondeterministic
