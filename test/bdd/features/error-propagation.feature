Feature: Error Propagation
  As a developer using MonadConcurrent
  I want errors in forked fibers to be captured
  So I can handle failures gracefully without crashing my program

  This feature verifies that the MonadConcurrent abstraction correctly
  propagates errors from forked computations on both JavaScript (Aff)
  and Erlang (Effect) backends, returning them via join rather than
  crashing the entire program.

  @demo @error @js
  Scenario: Error in fiber is captured via join (JavaScript)
    Given I have the demo app built for "js"
    When I run the "error-propagation" command
    Then the command should succeed
    And stdout should contain "Error captured: true"
    And stdout should contain "Error message:"

  @demo @error @erl
  Scenario: Error in fiber is captured via join (Erlang)
    Given I have the demo app built for "erl"
    When I run the "error-propagation" command
    Then the command should succeed
    And stdout should contain "Error captured: true"
    And stdout should contain "Error message:"

  @demo @error @js
  Scenario: Error message contains original error text (JavaScript)
    Given I have the demo app built for "js"
    When I run the "error-propagation" command
    Then the command should succeed
    And the error should be captured
    And the error message should contain "Intentional failure"

  @demo @error @erl
  Scenario: Error message contains original error text (Erlang)
    Given I have the demo app built for "erl"
    When I run the "error-propagation" command
    Then the command should succeed
    And the error should be captured
    And the error message should contain "Intentional failure"

  @demo @error @js
  Scenario: Error propagation demo provides helpful output (JavaScript)
    Given I have the demo app built for "js"
    When I run the "error-propagation" command
    Then the command should succeed
    And stdout should contain "Error Propagation Demo"
    And stdout should contain "Fiber errors are captured and returned via join"

  @demo @error @erl
  Scenario: Error propagation demo provides helpful output (Erlang)
    Given I have the demo app built for "erl"
    When I run the "error-propagation" command
    Then the command should succeed
    And stdout should contain "Error Propagation Demo"
    And stdout should contain "Fiber errors are captured and returned via join"

  @demo @error @js
  Scenario: Error propagation completes quickly (JavaScript)
    Given I have the demo app built for "js"
    When I run the "error-propagation" command
    Then the command should succeed
    And the reported elapsed time should be less than 200 milliseconds

  @demo @error @erl
  Scenario: Error propagation completes quickly (Erlang)
    Given I have the demo app built for "erl"
    When I run the "error-propagation" command
    Then the command should succeed
    And the reported elapsed time should be less than 200 milliseconds
