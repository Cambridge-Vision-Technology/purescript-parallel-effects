Feature: Parallel Execution
  As a developer using MonadConcurrent
  I want operations to execute in parallel
  So my program completes faster than sequential execution

  This feature verifies that the MonadConcurrent abstraction correctly
  executes operations concurrently on both JavaScript (Aff) and Erlang (Effect)
  backends, demonstrated through timing measurements and file I/O.

  Background:
    Given the output directory "out/test/bdd-demo/parallel-write" is empty

  @demo @parallel @timing @js
  Scenario: Parallel timing demonstrates concurrency (JavaScript)
    Given I have the demo app built for "js"
    When I run the "parallel-timing" command
    Then the command should succeed
    And stdout should contain "Result A: 42"
    And stdout should contain "Result B: hello"
    And the reported elapsed time should be less than 350 milliseconds
    And stdout should contain "If parallel: ~200ms"

  @demo @parallel @timing @erl
  Scenario: Parallel timing demonstrates concurrency (Erlang)
    Given I have the demo app built for "erl"
    When I run the "parallel-timing" command
    Then the command should succeed
    And stdout should contain "Result A: 42"
    And stdout should contain "Result B: hello"
    And the reported elapsed time should be less than 350 milliseconds
    And stdout should contain "If parallel: ~200ms"

  @demo @parallel @timing @js
  Scenario: Parallel timing takes longer than single delay (JavaScript)
    Given I have the demo app built for "js"
    When I run the "parallel-timing" command
    Then the command should succeed
    And the reported elapsed time should be at least 150 milliseconds

  @demo @parallel @timing @erl
  Scenario: Parallel timing takes longer than single delay (Erlang)
    Given I have the demo app built for "erl"
    When I run the "parallel-timing" command
    Then the command should succeed
    And the reported elapsed time should be at least 150 milliseconds

  @demo @parallel @write @parallel-write @js
  Scenario: Parallel file writes create both files (JavaScript)
    Given I have the demo app built for "js"
    When I run the "parallel-write" command with argument "out/test/bdd-demo/parallel-write"
    Then the command should succeed
    And "out/test/bdd-demo/parallel-write/file1.txt" should exist
    And "out/test/bdd-demo/parallel-write/file2.txt" should exist
    And stdout should contain "File 1:"
    And stdout should contain "File 2:"
    And stdout should contain "Both files written concurrently"

  @demo @parallel @write @parallel-write @erl
  Scenario: Parallel file writes create both files (Erlang)
    Given I have the demo app built for "erl"
    When I run the "parallel-write" command with argument "out/test/bdd-demo/parallel-write"
    Then the command should succeed
    And "out/test/bdd-demo/parallel-write/file1.txt" should exist
    And "out/test/bdd-demo/parallel-write/file2.txt" should exist
    And stdout should contain "File 1:"
    And stdout should contain "File 2:"
    And stdout should contain "Both files written concurrently"

  @demo @parallel @write @parallel-write @js
  Scenario: Parallel file writes have close timestamps (JavaScript)
    Given I have the demo app built for "js"
    When I run the "parallel-write" command with argument "out/test/bdd-demo/parallel-write"
    Then the command should succeed
    And both files should have timestamps within 1000ms of each other

  @demo @parallel @write @parallel-write @erl
  Scenario: Parallel file writes have close timestamps (Erlang)
    Given I have the demo app built for "erl"
    When I run the "parallel-write" command with argument "out/test/bdd-demo/parallel-write"
    Then the command should succeed
    And both files should have timestamps within 1000ms of each other

  @demo @parallel @write @parallel-write @js
  Scenario: Parallel write files contain expected content (JavaScript)
    Given I have the demo app built for "js"
    When I run the "parallel-write" command with argument "out/test/bdd-demo/parallel-write"
    Then the command should succeed
    And "out/test/bdd-demo/parallel-write/file1.txt" should contain "Content written to file 1"
    And "out/test/bdd-demo/parallel-write/file2.txt" should contain "Content written to file 2"

  @demo @parallel @write @parallel-write @erl
  Scenario: Parallel write files contain expected content (Erlang)
    Given I have the demo app built for "erl"
    When I run the "parallel-write" command with argument "out/test/bdd-demo/parallel-write"
    Then the command should succeed
    And "out/test/bdd-demo/parallel-write/file1.txt" should contain "Content written to file 1"
    And "out/test/bdd-demo/parallel-write/file2.txt" should contain "Content written to file 2"
