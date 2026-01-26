# Feature: Except effect for exception handling

## Scenario: throw converts to Left when run with runExcept
When I run a program that throws "error message"

Then the result is Left "error message"

## Scenario: successful computation converts to Right
When I run a program that returns 42 without throwing

Then the result is Right 42

## Scenario: rethrow converts Either to exception flow
When I run a program that rethrows Left "rethrown error"

Then the result is Left "rethrown error"

## Scenario: note converts Nothing to exception
When I run a program that notes Nothing with error "value missing"

Then the result is Left "value missing"

## Scenario: exception in parallel batch cancels siblings
When I run two operations in parallel where one throws immediately and one delays

Then the result is Left with the exception

And the delayed operation is canceled

And the total elapsed time is less than 600 milliseconds

## Scenario: exception in one sequential step stops execution
When I run a sequential program that throws after first step

Then the result is Left "step failed"

And the second step does not execute
