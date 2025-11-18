# Feature: Reader semantics under batching

## Scenario: ask returns env in applicative combine
Given an environment value "X"

When I applicatively combine `ask` and `ask` and concatenate their results

Then the final value equals "XX"
