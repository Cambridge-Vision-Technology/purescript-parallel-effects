# Feature: Parallel cancellation/propagation

## Scenario: Failing branch cancels siblings quickly
Given a delayed effect named "sleep500" that sleeps for 500 milliseconds

And a failing effect named "failNow" with message "boom"

When I run both effects in parallel in a single batch

Then the overall run fails with message containing "boom"

And the total elapsed time is less than 300 milliseconds

And the delayed effect "sleep500" was canceled before completion
