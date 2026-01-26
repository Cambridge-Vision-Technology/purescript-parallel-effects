// Test helpers for MonadConcurrent demo app BDD tests
//
// This module provides platform-agnostic test utilities that work with
// both the JavaScript (Aff) and Erlang (Effect) backends of the demo app.

import { setWorldConstructor, World } from '@cucumber/cucumber';
import { spawn } from 'node:child_process';
import { access, stat, mkdir, rm } from 'node:fs/promises';
import { constants } from 'node:fs';
import { dirname } from 'node:path';

class DemoAppWorld extends World {
  constructor(options) {
    super(options);

    // Commands for running demo apps (from cucumber.js worldParameters)
    this.demoJsCmd = options.parameters.demoJsCmd;
    this.demoErlCmd = options.parameters.demoErlCmd;

    // State for current scenario
    this.lastResult = null;
    this.currentBackend = null;
  }

  /**
   * Run the demo app for a specific backend with the given command and arguments.
   *
   * @param {string} backend - 'js' or 'erl'
   * @param {string} command - The demo app command (e.g., 'parallel-timing')
   * @param {string[]} args - Additional arguments for the command
   * @returns {Promise<{stdout: string, stderr: string, exitCode: number, elapsedMs: number}>}
   */
  async runDemoApp(backend, command, args = []) {
    const cmdLine = backend === 'js' ? this.demoJsCmd : this.demoErlCmd;
    const cmdParts = cmdLine.split(/\s+/);
    const executable = cmdParts[0];
    const baseArgs = cmdParts.slice(1);
    const fullArgs = [...baseArgs, command, ...args];

    return measureExecutionTime(async () => {
      return new Promise((resolve, reject) => {
        const proc = spawn(executable, fullArgs, {
          stdio: ['pipe', 'pipe', 'pipe'],
          shell: false,
          env: { ...process.env }
        });

        let stdout = '';
        let stderr = '';

        proc.stdout.on('data', (data) => {
          stdout += data.toString();
        });

        proc.stderr.on('data', (data) => {
          stderr += data.toString();
        });

        proc.on('close', (exitCode) => {
          resolve({
            stdout,
            stderr,
            exitCode: exitCode ?? 0
          });
        });

        proc.on('error', (err) => {
          reject(new Error(`Failed to spawn ${executable}: ${err.message}`));
        });
      });
    });
  }

  /**
   * Assert that a file exists at the given path.
   *
   * @param {string} filePath - Path to the file
   * @throws {Error} If file does not exist
   */
  async assertFileExists(filePath) {
    try {
      await access(filePath, constants.F_OK);
    } catch {
      throw new Error(`Expected file to exist: ${filePath}`);
    }
  }

  /**
   * Assert that a file does NOT exist at the given path.
   *
   * @param {string} filePath - Path to the file
   * @throws {Error} If file exists
   */
  async assertFileNotExists(filePath) {
    try {
      await access(filePath, constants.F_OK);
      throw new Error(`Expected file NOT to exist: ${filePath}`);
    } catch (err) {
      if (err.code !== 'ENOENT') {
        throw err;
      }
    }
  }

  /**
   * Get the modification timestamp of a file in milliseconds.
   *
   * @param {string} filePath - Path to the file
   * @returns {Promise<number>} Modification time in milliseconds since epoch
   */
  async getFileTimestamp(filePath) {
    const stats = await stat(filePath);
    return stats.mtimeMs;
  }

  /**
   * Ensure a directory exists, creating it if necessary.
   *
   * @param {string} dirPath - Path to the directory
   */
  async ensureDirectory(dirPath) {
    await mkdir(dirPath, { recursive: true });
  }

  /**
   * Remove a file or directory recursively.
   *
   * @param {string} path - Path to remove
   */
  async removePath(path) {
    try {
      await rm(path, { recursive: true, force: true });
    } catch {
      // Ignore errors - path may not exist
    }
  }

  /**
   * Parse the elapsed time from demo app output.
   * Demo apps output lines like "Elapsed: 207ms" or "Elapsed: 2.07e+02ms" (scientific notation from Erlang)
   *
   * @param {string} stdout - The stdout from the demo app
   * @returns {number|null} Elapsed time in ms, or null if not found
   */
  parseElapsedTime(stdout) {
    const match = stdout.match(/Elapsed:\s*([\d.]+(?:e[+-]?\d+)?)\s*ms/i);
    return match ? parseFloat(match[1]) : null;
  }

  /**
   * Assert that a value is less than a threshold.
   *
   * @param {number} actual - The actual value
   * @param {number} threshold - The maximum allowed value
   * @param {string} message - Error message prefix
   */
  assertLessThan(actual, threshold, message = 'Value') {
    if (actual >= threshold) {
      throw new Error(`${message}: expected ${actual} to be less than ${threshold}`);
    }
  }

  /**
   * Assert that a value is greater than or equal to a threshold.
   *
   * @param {number} actual - The actual value
   * @param {number} threshold - The minimum allowed value
   * @param {string} message - Error message prefix
   */
  assertGreaterOrEqual(actual, threshold, message = 'Value') {
    if (actual < threshold) {
      throw new Error(`${message}: expected ${actual} to be >= ${threshold}`);
    }
  }

  /**
   * Assert that stdout contains the expected substring.
   *
   * @param {string} stdout - The stdout to search
   * @param {string} expected - The expected substring
   */
  assertContains(stdout, expected) {
    if (!stdout.includes(expected)) {
      throw new Error(`Expected stdout to contain "${expected}", but got:\n${stdout}`);
    }
  }

  /**
   * Assert that two file timestamps are within a tolerance of each other.
   *
   * @param {number} timestamp1 - First timestamp in ms
   * @param {number} timestamp2 - Second timestamp in ms
   * @param {number} toleranceMs - Maximum allowed difference in ms
   */
  assertTimestampsClose(timestamp1, timestamp2, toleranceMs) {
    const diff = Math.abs(timestamp1 - timestamp2);
    if (diff > toleranceMs) {
      throw new Error(
        `Expected timestamps to be within ${toleranceMs}ms, but difference was ${diff}ms`
      );
    }
  }
}

/**
 * Measure the execution time of an async function.
 *
 * @param {Function} fn - Async function to measure
 * @returns {Promise<{...result, elapsedMs: number}>} Result with elapsedMs added
 */
async function measureExecutionTime(fn) {
  const startTime = Date.now();
  const result = await fn();
  const endTime = Date.now();
  return {
    ...result,
    elapsedMs: endTime - startTime
  };
}

/**
 * Standalone helper: Run the demo app and measure execution time.
 * This is exported for use in step definitions that don't use the World.
 *
 * @param {string} backend - 'js' or 'erl'
 * @param {string} command - The demo app command
 * @param {string[]} args - Additional arguments
 * @param {object} options - Options including demoJsCmd and demoErlCmd
 * @returns {Promise<{stdout: string, stderr: string, exitCode: number, elapsedMs: number}>}
 */
export async function runDemoApp(backend, command, args = [], options = {}) {
  const demoJsCmd = options.demoJsCmd || process.env.DEMO_JS_CMD || 'nix run .#demo-js --';
  const demoErlCmd = options.demoErlCmd || process.env.DEMO_ERL_CMD || 'nix run .#demo-erl --';
  const cmdLine = backend === 'js' ? demoJsCmd : demoErlCmd;
  const cmdParts = cmdLine.split(/\s+/);
  const executable = cmdParts[0];
  const baseArgs = cmdParts.slice(1);
  const fullArgs = [...baseArgs, command, ...args];

  return measureExecutionTime(async () => {
    return new Promise((resolve, reject) => {
      const proc = spawn(executable, fullArgs, {
        stdio: ['pipe', 'pipe', 'pipe'],
        shell: false,
        env: { ...process.env }
      });

      let stdout = '';
      let stderr = '';

      proc.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      proc.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      proc.on('close', (exitCode) => {
        resolve({
          stdout,
          stderr,
          exitCode: exitCode ?? 0
        });
      });

      proc.on('error', (err) => {
        reject(new Error(`Failed to spawn ${executable}: ${err.message}`));
      });
    });
  });
}

/**
 * Standalone helper: Assert that a file exists.
 *
 * @param {string} filePath - Path to the file
 * @throws {Error} If file does not exist
 */
export async function assertFileExists(filePath) {
  try {
    await access(filePath, constants.F_OK);
  } catch {
    throw new Error(`Expected file to exist: ${filePath}`);
  }
}

/**
 * Standalone helper: Get file modification timestamp in milliseconds.
 *
 * @param {string} filePath - Path to the file
 * @returns {Promise<number>} Modification time in milliseconds since epoch
 */
export async function getFileTimestamp(filePath) {
  const stats = await stat(filePath);
  return stats.mtimeMs;
}

// Register the custom World with Cucumber
setWorldConstructor(DemoAppWorld);

// Export helpers for step definitions
export { measureExecutionTime, DemoAppWorld };
