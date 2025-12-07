# Feature: Labeled Reader and Writer instances

## Scenario: two different reader instances can coexist
When I run a program with config reader and user reader

Then the result contains config value "production"

And the result contains user value "alice"

## Scenario: two different writer instances can coexist
When I run a program with log writer and audit writer

Then the log writer output equals "log1,log2"

And the audit writer output equals "audit1,audit2"

## Scenario: combination of labeled state, reader, and writer
When I run a program with state, reader, and writer

Then the final state equals 42

And the writer output equals "init,increment"

And the result contains reader value "config"
