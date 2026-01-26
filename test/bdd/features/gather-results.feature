Feature: Gather Results
  As a developer using MonadConcurrent
  I want to collect results from multiple parallel fibers
  So I can process multiple computations concurrently and combine their outputs

  This feature verifies that the MonadConcurrent abstraction correctly
  supports gathering results from multiple parallel fibers on both
  JavaScript (Aff) and Erlang (Effect) backends, maintaining result
  order while executing concurrently.

  @demo @gather @js
  Scenario: Gather results returns all values (JavaScript)
    Given I have the demo app built for "js"
    When I run the "gather-results" command
    Then the command should succeed
    And stdout should contain "Values:"
    And the values should be "[10,20,30,40,50]"

  @demo @gather @erl
  Scenario: Gather results returns all values (Erlang)
    Given I have the demo app built for "erl"
    When I run the "gather-results" command
    Then the command should succeed
    And stdout should contain "Values:"
    And the values should be "[10,20,30,40,50]"

  @demo @gather @js
  Scenario: Gather results executes in parallel time (JavaScript)
    Given I have the demo app built for "js"
    When I run the "gather-results" command
    Then the command should succeed
    And the reported elapsed time should be less than 400 milliseconds

  @demo @gather @erl
  Scenario: Gather results executes in parallel time (Erlang)
    Given I have the demo app built for "erl"
    When I run the "gather-results" command
    Then the command should succeed
    And the reported elapsed time should be less than 400 milliseconds

  @demo @gather @js
  Scenario: Gather results takes at least one delay cycle (JavaScript)
    Given I have the demo app built for "js"
    When I run the "gather-results" command
    Then the command should succeed
    And the reported elapsed time should be at least 80 milliseconds

  @demo @gather @erl
  Scenario: Gather results takes at least one delay cycle (Erlang)
    Given I have the demo app built for "erl"
    When I run the "gather-results" command
    Then the command should succeed
    And the reported elapsed time should be at least 80 milliseconds

  @demo @gather @js
  Scenario: Gather results demo provides helpful output (JavaScript)
    Given I have the demo app built for "js"
    When I run the "gather-results" command
    Then the command should succeed
    And stdout should contain "Gather Results Demo"
    And stdout should contain "5x100ms computations ran in parallel"
    And stdout should contain "If parallel: ~100ms"

  @demo @gather @erl
  Scenario: Gather results demo provides helpful output (Erlang)
    Given I have the demo app built for "erl"
    When I run the "gather-results" command
    Then the command should succeed
    And stdout should contain "Gather Results Demo"
    And stdout should contain "5x100ms computations ran in parallel"
    And stdout should contain "If parallel: ~100ms"

  @demo @gather @js
  Scenario: Gather results demonstrates parallelism (JavaScript)
    Given I have the demo app built for "js"
    When I run the "gather-results" command
    Then the command should succeed
    And the gather results demo should show parallelism

  @demo @gather @erl
  Scenario: Gather results demonstrates parallelism (Erlang)
    Given I have the demo app built for "erl"
    When I run the "gather-results" command
    Then the command should succeed
    And the gather results demo should show parallelism
