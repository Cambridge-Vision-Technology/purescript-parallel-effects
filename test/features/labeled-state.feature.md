# Feature: Labeled state instances

## Scenario: two different state instances can coexist
When I run a program with counter state and name state

Then the counter state final value equals 1

And the name state final value equals "Hello!"

And the returned result equals "Hello! (1)"

## Scenario: labeled states work correctly in parallel
When I run a program that modifies both states in parallel

Then the counter state final value equals 2

And the name state final value equals "AB"
