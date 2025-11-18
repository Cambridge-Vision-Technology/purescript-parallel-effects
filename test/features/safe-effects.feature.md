# Feature: Safe Effects with Typed Errors

## Scenario: liftSafeAff returns Right on success

Given a successful Aff computation that returns "success"

When I lift it with liftSafeAff

Then the result is Right "success"

## Scenario: liftSafeAff returns Left on Aff failure

Given an Aff computation that throws error "operation failed"

When I lift it with liftSafeAff

Then the result is Left with error message containing "operation failed"

## Scenario: liftSafeEffect returns Right on success

Given a successful Effect computation that returns 42

When I lift it with liftSafeEffect

Then the result is Right 42

## Scenario: liftSafeEffect returns Left on Effect failure

Given an Effect computation that throws error "effect error"

When I lift it with liftSafeEffect

Then the result is Left with error message containing "effect error"

## Scenario: Parallel safe effects with mixed success and failure

Given a safe Aff operation that succeeds with "success"

And a safe Aff operation that fails with "failure"

When I run both operations in parallel in a single batch

Then the first result is Right "success"

And the second result is Left with error message containing "failure"

And both operations complete without cancellation

## Scenario: Typed errors don't cancel sibling effects

Given a delayed safe Aff that takes 200 milliseconds and succeeds with "slow"

And a safe Aff that immediately fails with "immediate error"

When I run both operations in parallel in a single batch

Then both operations complete

And the slow operation is not canceled

And the total elapsed time is at least 150 milliseconds

And one result is Right "slow"

And one result is Left with error containing "immediate error"
