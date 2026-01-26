// Step definitions for MonadConcurrent demo app BDD tests
//
// These steps test the demo app against both JavaScript (Aff) and
// Erlang (Effect) backends, verifying identical observable behavior.
//
// Supported commands:
//   - parallel-timing: Two 200ms delays in parallel
//   - parallel-write: Write two files concurrently
//   - cancel-fiber: Fork and cancel a long computation
//   - error-propagation: Fork a failing computation and capture error
//   - gather-results: Collect results from multiple fibers

import { Given, When, Then, Before, After } from '@cucumber/cucumber';
import { mkdir, rm, readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';

// Store the output directory for parallel-write tests
const TEST_OUTPUT_DIR = resolve(process.cwd(), 'out/test/bdd-demo/parallel-write');

// Clean up test output directory before scenarios that need it
Before({ tags: '@parallel-write' }, async function () {
  await this.removePath(TEST_OUTPUT_DIR);
  await this.ensureDirectory(TEST_OUTPUT_DIR);
});

// Given steps

Given('I have the demo app built for {string}', async function (backend) {
  if (backend !== 'js' && backend !== 'erl') {
    throw new Error(`Unknown backend: ${backend}. Expected 'js' or 'erl'`);
  }
  this.currentBackend = backend;
});

Given('the output directory {string} is empty', async function (dirPath) {
  const fullPath = resolve(process.cwd(), dirPath);
  await this.removePath(fullPath);
  await this.ensureDirectory(fullPath);
  this.outputDir = fullPath;
});

// When steps

When('I run the {string} command', async function (command) {
  this.lastResult = await this.runDemoApp(this.currentBackend, command);
});

When('I run the {string} command with argument {string}', async function (command, arg) {
  this.lastResult = await this.runDemoApp(this.currentBackend, command, [arg]);
});

When('I run the {string} command with arguments {string}', async function (command, argsStr) {
  const args = argsStr.split(/\s+/).filter(a => a.length > 0);
  this.lastResult = await this.runDemoApp(this.currentBackend, command, args);
});

// Then steps - Timing assertions

Then('the execution should complete in less than {int} milliseconds', function (maxMs) {
  const reportedElapsed = this.parseElapsedTime(this.lastResult.stdout);
  if (reportedElapsed !== null) {
    this.assertLessThan(reportedElapsed, maxMs, 'Reported elapsed time');
  } else {
    this.assertLessThan(this.lastResult.elapsedMs, maxMs, 'Wall-clock time');
  }
});

Then('the reported elapsed time should be less than {int} milliseconds', function (maxMs) {
  const reportedElapsed = this.parseElapsedTime(this.lastResult.stdout);
  if (reportedElapsed === null) {
    throw new Error(`Could not find "Elapsed: Xms" in stdout:\n${this.lastResult.stdout}`);
  }
  this.assertLessThan(reportedElapsed, maxMs, 'Reported elapsed time');
});

Then('the reported elapsed time should be at least {int} milliseconds', function (minMs) {
  const reportedElapsed = this.parseElapsedTime(this.lastResult.stdout);
  if (reportedElapsed === null) {
    throw new Error(`Could not find "Elapsed: Xms" in stdout:\n${this.lastResult.stdout}`);
  }
  this.assertGreaterOrEqual(reportedElapsed, minMs, 'Reported elapsed time');
});

// Then steps - Output assertions

Then('stdout should contain {string}', function (expected) {
  this.assertContains(this.lastResult.stdout, expected);
});

Then('stdout should not contain {string}', function (unexpected) {
  if (this.lastResult.stdout.includes(unexpected)) {
    throw new Error(`Expected stdout NOT to contain "${unexpected}", but it did:\n${this.lastResult.stdout}`);
  }
});

Then('stderr should contain {string}', function (expected) {
  this.assertContains(this.lastResult.stderr, expected);
});

Then('stderr should be empty', function () {
  if (this.lastResult.stderr.trim() !== '') {
    throw new Error(`Expected stderr to be empty, but got:\n${this.lastResult.stderr}`);
  }
});

// Then steps - Exit code assertions

Then('the exit code should be {int}', function (expectedCode) {
  if (this.lastResult.exitCode !== expectedCode) {
    throw new Error(
      `Expected exit code ${expectedCode}, but got ${this.lastResult.exitCode}\n` +
      `stdout:\n${this.lastResult.stdout}\n` +
      `stderr:\n${this.lastResult.stderr}`
    );
  }
});

Then('the command should succeed', function () {
  if (this.lastResult.exitCode !== 0) {
    throw new Error(
      `Expected command to succeed (exit code 0), but got ${this.lastResult.exitCode}\n` +
      `stdout:\n${this.lastResult.stdout}\n` +
      `stderr:\n${this.lastResult.stderr}`
    );
  }
});

Then('the command should fail', function () {
  if (this.lastResult.exitCode === 0) {
    throw new Error(
      `Expected command to fail (non-zero exit code), but got 0\n` +
      `stdout:\n${this.lastResult.stdout}`
    );
  }
});

// Then steps - File assertions (for parallel-write tests)

Then('{string} should exist', async function (filePath) {
  const fullPath = resolve(process.cwd(), filePath);
  await this.assertFileExists(fullPath);
});

Then('{string} should not exist', async function (filePath) {
  const fullPath = resolve(process.cwd(), filePath);
  await this.assertFileNotExists(fullPath);
});

Then('{string} should contain {string}', async function (filePath, expected) {
  const fullPath = resolve(process.cwd(), filePath);
  const content = await readFile(fullPath, 'utf-8');
  if (!content.includes(expected)) {
    throw new Error(`Expected file ${filePath} to contain "${expected}", but got:\n${content}`);
  }
});

Then('both files should have timestamps within {int}ms of each other', async function (toleranceMs) {
  if (!this.outputDir) {
    throw new Error('No output directory set. Use "Given the output directory ... is empty" first');
  }
  const file1 = join(this.outputDir, 'file1.txt');
  const file2 = join(this.outputDir, 'file2.txt');
  const ts1 = await this.getFileTimestamp(file1);
  const ts2 = await this.getFileTimestamp(file2);
  this.assertTimestampsClose(ts1, ts2, toleranceMs);
});

// Then steps - Specific demo command assertions

Then('the parallel timing demo should show parallelism', function () {
  const elapsed = this.parseElapsedTime(this.lastResult.stdout);
  if (elapsed === null) {
    throw new Error('Could not parse elapsed time from output');
  }
  if (elapsed >= 350) {
    throw new Error(
      `Expected parallel execution (~200ms for two 200ms delays), but got ${elapsed}ms. ` +
      `This suggests sequential execution.`
    );
  }
  this.assertContains(this.lastResult.stdout, 'Result A:');
  this.assertContains(this.lastResult.stdout, 'Result B:');
});

Then('the cancel fiber demo should complete quickly', function () {
  const elapsed = this.parseElapsedTime(this.lastResult.stdout);
  if (elapsed === null) {
    throw new Error('Could not parse elapsed time from output');
  }
  if (elapsed >= 500) {
    throw new Error(
      `Expected quick cancellation (<500ms for a 2000ms computation), but got ${elapsed}ms. ` +
      `This suggests cancellation did not work.`
    );
  }
  this.assertContains(this.lastResult.stdout, 'Cancelled: true');
});

Then('the error should be captured', function () {
  this.assertContains(this.lastResult.stdout, 'Error captured: true');
  this.assertContains(this.lastResult.stdout, 'Error message:');
});

Then('the error message should contain {string}', function (expected) {
  if (!this.lastResult.stdout.includes(expected)) {
    throw new Error(`Expected error message to contain "${expected}", but stdout was:\n${this.lastResult.stdout}`);
  }
});

Then('the gather results demo should show parallelism', function () {
  const elapsed = this.parseElapsedTime(this.lastResult.stdout);
  if (elapsed === null) {
    throw new Error('Could not parse elapsed time from output');
  }
  if (elapsed >= 400) {
    throw new Error(
      `Expected parallel execution (~100ms for five 100ms delays), but got ${elapsed}ms. ` +
      `This suggests sequential execution.`
    );
  }
  this.assertContains(this.lastResult.stdout, 'Values:');
  this.assertContains(this.lastResult.stdout, '[10,20,30,40,50]');
});

Then('the values should be {string}', function (expected) {
  const valuesMatch = this.lastResult.stdout.match(/Values:\s*(\[[^\]]+\])/);
  if (!valuesMatch) {
    throw new Error(`Could not find "Values: [...]" in stdout:\n${this.lastResult.stdout}`);
  }
  const normalizedActual = valuesMatch[1].replace(/\s/g, '');
  const normalizedExpected = expected.replace(/\s/g, '');
  if (normalizedActual !== normalizedExpected) {
    throw new Error(`Expected values ${expected}, but got ${valuesMatch[1]}`);
  }
});
