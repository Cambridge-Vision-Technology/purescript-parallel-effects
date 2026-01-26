Feature: Fiber Cancellation
  As a developer using MonadConcurrent
  I want to cancel running fibers
  So I can abort long-running computations when no longer needed

  This feature verifies that the MonadConcurrent abstraction correctly
  supports fiber cancellation on both JavaScript (Aff) and Erlang (Effect)
  backends, allowing computations to be terminated promptly.

  @demo @cancel @js
  Scenario: Cancel fiber terminates long-running computation (JavaScript)
    Given I have the demo app built for "js"
    When I run the "cancel-fiber" command
    Then the command should succeed
    And stdout should contain "Cancelled: true"
    And the reported elapsed time should be less than 500 milliseconds

  @demo @cancel @erl
  Scenario: Cancel fiber terminates long-running computation (Erlang)
    Given I have the demo app built for "erl"
    When I run the "cancel-fiber" command
    Then the command should succeed
    And stdout should contain "Cancelled: true"
    And the reported elapsed time should be less than 500 milliseconds

  @demo @cancel @js
  Scenario: Cancel fiber demo provides helpful output (JavaScript)
    Given I have the demo app built for "js"
    When I run the "cancel-fiber" command
    Then the command should succeed
    And stdout should contain "Cancel Fiber Demo"
    And stdout should contain "2000ms computation was cancelled"
    And stdout should contain "If cancellation works: <500ms"

  @demo @cancel @erl
  Scenario: Cancel fiber demo provides helpful output (Erlang)
    Given I have the demo app built for "erl"
    When I run the "cancel-fiber" command
    Then the command should succeed
    And stdout should contain "Cancel Fiber Demo"
    And stdout should contain "2000ms computation was cancelled"
    And stdout should contain "If cancellation works: <500ms"

  @demo @cancel @js
  Scenario: Cancellation is nearly instantaneous (JavaScript)
    Given I have the demo app built for "js"
    When I run the "cancel-fiber" command
    Then the command should succeed
    And the cancel fiber demo should complete quickly

  @demo @cancel @erl
  Scenario: Cancellation is nearly instantaneous (Erlang)
    Given I have the demo app built for "erl"
    When I run the "cancel-fiber" command
    Then the command should succeed
    And the cancel fiber demo should complete quickly
