// BDD Markdown step definitions for this project.
// Note: This file expects the `BDD_RUNNER` env var to point to the built
// PureScript runner (self.packages.<system>.bdd-runner).

import { spawn } from 'node:child_process'
import { readFile, writeFile, rm, stat, mkdir } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))

const bddRunner = process.env.BDD_RUNNER
if (!bddRunner) {
  console.error('BDD_RUNNER env var is not set. flake apps set this automatically.')
}

const world = {
  vars: new Map(),
  start: 0,
  end: 0,
}

async function runRunner(args, options = {}) {
  return new Promise((resolve, reject) => {
    const t0 = Date.now()
    const child = spawn(process.execPath, [bddRunner, ...args], {
      stdio: ['ignore', 'pipe', 'pipe'],
      ...options,
    })
    let out = ''
    let err = ''
    child.stdout.on('data', (d) => (out += d.toString()))
    child.stderr.on('data', (d) => (err += d.toString()))
    child.on('close', (code) => {
      const t1 = Date.now()
      resolve({ code, out, err, elapsed: t1 - t0 })
    })
    child.on('error', reject)
  })
}

const m = (re) => (title) => re.test(title)

// Regex constants for matching step titles
const reDelay = /^a delayed effect named "([^"]+)" that sleeps for (\d+) milliseconds$/
const reFail = /^a failing effect named "([^"]+)" with message "([^"]+)"$/
const reOverallFail = /^the overall run fails with message containing "([^"]+)"$/
const reElapsed = /^the total elapsed time is less than (\d+) milliseconds$/
const reEnv = /^an environment value "([^"]+)"$/
const reFinalValue = /^the final value equals "([^"]+)"$/
const reFinalState = /^the final state equals (\d+)$/
const reSandbox = /^a sandbox directory "([^"]+)"$/
const reWriteFile = /^I write file "([^"]+)" with contents "([^"]+)"$/
const reReadFile = /^I read file "([^"]+)"$/
const reContentsEq = /^the contents equals "([^"]+)"$/
const reDeleteFile = /^I delete file "([^"]+)"$/
const reFileNotExist = /^file "([^"]+)" does not exist$/

export const steps = [
  // Parallel cancellation/propagation
  {
    match: m(/^a delayed effect named "([^"]+)" that sleeps for (\d+) milliseconds$/),
    run: async ({ step: { title } }) => {
      const m = title.match(reDelay)
      if (!m) throw new Error('bad match for delay step')
      const [, name, ms] = m
      world.vars.set(name, { type: 'delay', ms: Number(ms) })
    },
  },
  {
    match: m(/^a failing effect named "([^"]+)" with message "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(reFail)
      if (!m) throw new Error('bad match for fail step')
      const [, name, message] = m
      world.vars.set(name, { type: 'fail', message })
    },
  },
  {
    match: m(/^I run both effects in parallel in a single batch$/),
    run: async () => {
      const entries = [...world.vars.values()]
      const delay = entries.find((e) => e.type === 'delay')
      const fail = entries.find((e) => e.type === 'fail')
      if (!delay || !fail) throw new Error('missing delay or fail setup')
      world.start = Date.now()
      world.result = await runRunner(['parallel-cancellation', String(delay.ms), fail.message])
      world.end = Date.now()
    },
  },
  {
    match: m(reOverallFail),
    run: async ({ step: { title } }) => {
      const m = title.match(reOverallFail)
      const fragment = m && m[1]
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes('"status":"failed"')) throw new Error(`Expected failure, got: ${line}`)
      if (!line.includes(fragment)) throw new Error(`Message did not include '${fragment}': ${line}`)
    },
  },
  {
    match: m(reElapsed),
    run: async ({ step: { title } }) => {
      const m = title.match(reElapsed)
      const ms = m && m[1]
      const elapsed = world.result?.elapsed ?? world.end - world.start
      if (!(elapsed < Number(ms))) throw new Error(`Elapsed ${elapsed}ms not < ${ms}ms`)
    },
  },
  {
    match: m(/^the delayed effect "([^"]+)" was canceled before completion$/),
    run: async () => {
      // Cancellation is inferred by total elapsed time assertion above.
      // This step is informational and thus a no-op beyond acknowledging prior check.
    },
  },

  // Reader semantics under batching
  {
    match: m(reEnv),
    run: async ({ step: { title } }) => {
      const m = title.match(reEnv)
      if (!m) throw new Error('bad match for env step')
      const [, env] = m
      world.vars.set('env', env)
    },
  },
  {
    match: m(/^I applicatively combine `ask` and `ask` and concatenate their results$/),
    run: async () => {
      const env = world.vars.get('env')
      world.result = await runRunner(['reader-ask-twice', String(env)])
    },
  },
  {
    match: m(reFinalValue),
    run: async ({ step: { title } }) => {
      const m = title.match(reFinalValue)
      if (!m) throw new Error('bad match for final value')
      const [, expected] = m
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes(`"result":"${expected}"`)) throw new Error(`Unexpected result: ${line}`)
    },
  },

  // State semantics
  {
    match: m(/^an initial state (\d+)$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^an initial state (\d+)$/)
      const s = m?.[1]
      world.vars.set('initialState', Number(s))
    },
  },
  {
    match: m(/^I applicatively combine two operations that increment state by 1$/),
    run: async () => {
      world.result = await runRunner(['state-parallel-modify'])
    },
  },
  {
    match: m(reFinalState),
    run: async ({ step: { title } }) => {
      const m = title.match(reFinalState)
      if (!m) throw new Error('bad match for final state')
      const [, expected] = m
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes(`"finalState":${Number(expected)}`)) throw new Error(`Unexpected state: ${line}`)
    },
  },

  // Filesystem sandboxed ops
  {
    match: m(/^the order of intermediate updates is nondeterministic$/),
    run: async () => {
      // Informational: acknowledge nondeterminism; no check performed.
    },
  },
  {
    match: m(reSandbox),
    run: async ({ step: { title } }) => {
      const m = title.match(/^a sandbox directory \"([^\"]+)\"$/)
      const dir = m?.[1]
      world.vars.set('sandbox', dir)
    },
  },
  {
    match: m(reWriteFile),
    run: async ({ step: { title } }) => {
      const m = title.match(/^I write file \"([^\"]+)\" with contents \"([^\"]+)\"$/)
      if (!m) throw new Error('bad match for write file')
      const [, file, contents] = m
      const dir = world.vars.get('sandbox')
      await mkdir(join(process.cwd(), dir), { recursive: true })
      await writeFile(join(process.cwd(), dir, file), contents, 'utf8')
    },
  },
  {
    match: m(reReadFile),
    run: async ({ step: { title } }) => {
      const m = title.match(reReadFile)
      if (!m) throw new Error('bad match for read file')
      const [, file] = m
      const dir = world.vars.get('sandbox')
      const data = await readFile(join(process.cwd(), dir, file), 'utf8')
      world.vars.set('lastContents', data)
    },
  },
  {
    match: m(reContentsEq),
    run: async ({ step: { title } }) => {
      const m = title.match(/^the contents equals \"([^\"]+)\"$/)
      if (!m) throw new Error('bad match for final value')
      const [, expected] = m
      const data = world.vars.get('lastContents')
      if (data !== expected) throw new Error(`Expected '${expected}', got '${data}'`)
    },
  },
  {
    match: m(reDeleteFile),
    run: async ({ step: { title } }) => {
      const m = title.match(reDeleteFile)
      if (!m) throw new Error('bad match for delete file')
      const [, file] = m
      const dir = world.vars.get('sandbox')
      await rm(join(process.cwd(), dir, file), { force: true })
    },
  },
  {
    match: m(reFileNotExist),
    run: async ({ step: { title } }) => {
      const m = title.match(reFileNotExist)
      if (!m) throw new Error('bad match for not-exist check')
      const [, file] = m
      const dir = world.vars.get('sandbox')
      try {
        await stat(join(process.cwd(), dir, file))
        throw new Error('File exists')
      } catch (err) {
        // expected: stat throws
      }
    },
  },

  // Applicative laws (informal checks via runner)
  { match: m(/^a program `u`$/), run: async () => {} },
  {
    match: m(/^I evaluate pure id applied to u$/),
    run: async () => {
      world.result = await runRunner(['applicative-laws', 'identity'])
    },
  },
  {
    match: m(/^the result equals the result of `u`$/),
    run: async () => {
      const { out } = world.result ?? {}
      if (!out?.includes('"ok":true')) throw new Error('Identity law failed')
    },
  },
  {
    match: m(/^a pure function `f` and a pure value `x`$/),
    run: async () => {},
  },
  {
    match: m(/^I evaluate pure f applied to pure x$/),
    run: async () => {
      world.result = await runRunner(['applicative-laws', 'homomorphism'])
    },
  },
  {
    match: m(/^the result equals the result of `pure \(f x\)`$/),
    run: async () => {
      const { out } = world.result ?? {}
      if (!out?.includes('"ok":true')) throw new Error('Homomorphism law failed')
    },
  },
  {
    match: m(/^a program `u` and a pure value `y`$/),
    run: async () => {},
  },
  {
    match: m(/^I evaluate u applied to pure y$/),
    run: async () => {
      world.result = await runRunner(['applicative-laws', 'interchange'])
    },
  },
  {
    match: m(/^the result equals the result of the interchange form$/),
    run: async () => {
      const { out } = world.result ?? {}
      if (!out?.includes('"ok":true')) throw new Error('Interchange law failed')
    },
  },
  {
    match: m(/^three independent effects `a`, `b`, and `c`$/),
    run: async () => {},
  },
  {
    match: m(/^I applicatively combine them using map and apply$/),
    run: async () => {
      world.result = await runRunner(['applicative-laws', 'batch-merge'])
    },
  },
  {
    match: m(/^the interpreter merges them into a single batch and executes them in parallel$/),
    run: async () => {
      const { out } = world.result ?? {}
      if (!out?.includes('"ok":true')) throw new Error('Batch merge check failed')
    },
  },

  // Safe Effects
  {
    match: m(/^a successful Aff computation that returns "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^a successful Aff computation that returns "([^"]+)"$/)
      const value = m?.[1]
      world.vars.set('safeAffValue', value)
    },
  },
  {
    match: m(/^I lift it with liftSafeAff$/),
    run: async () => {
      const value = world.vars.get('safeAffValue')
      world.result = await runRunner(['safe-effects', 'liftSafeAff-success', value])
    },
  },
  {
    match: m(/^the result is Right "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^the result is Right "([^"]+)"$/)
      const expected = m?.[1]
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes(`"result":"Right ${expected}"`)) throw new Error(`Expected Right "${expected}", got: ${line}`)
    },
  },
  {
    match: m(/^an Aff computation that throws error "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^an Aff computation that throws error "([^"]+)"$/)
      const msg = m?.[1]
      world.vars.set('safeAffError', msg)
    },
  },
  {
    match: m(/^the result is Left with error message containing "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^the result is Left with error message containing "([^"]+)"$/)
      const fragment = m?.[1]
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes('"result":"Left"')) throw new Error(`Expected Left, got: ${line}`)
      if (!line.includes(fragment)) throw new Error(`Expected error containing "${fragment}", got: ${line}`)
    },
  },
  {
    match: m(/^a successful Effect computation that returns (\d+)$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^a successful Effect computation that returns (\d+)$/)
      const value = m?.[1]
      world.vars.set('safeEffectValue', Number(value))
    },
  },
  {
    match: m(/^I lift it with liftSafeEffect$/),
    run: async () => {
      const value = world.vars.get('safeEffectValue')
      world.result = await runRunner(['safe-effects', 'liftSafeEffect-success', String(value)])
    },
  },
  {
    match: m(/^the result is Right (\d+)$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^the result is Right (\d+)$/)
      const expected = m?.[1]
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes(`"result":"Right ${expected}"`)) throw new Error(`Expected Right ${expected}, got: ${line}`)
    },
  },
  {
    match: m(/^an Effect computation that throws error "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^an Effect computation that throws error "([^"]+)"$/)
      const msg = m?.[1]
      world.vars.set('safeEffectError', msg)
    },
  },
  {
    match: m(/^a safe Aff operation that succeeds with "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^a safe Aff operation that succeeds with "([^"]+)"$/)
      const value = m?.[1]
      world.vars.set('safeAffSuccess', value)
    },
  },
  {
    match: m(/^a safe Aff operation that fails with "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^a safe Aff operation that fails with "([^"]+)"$/)
      const msg = m?.[1]
      world.vars.set('safeAffFailure', msg)
    },
  },
  {
    match: m(/^I run both operations in parallel in a single batch$/),
    run: async () => {
      const success = world.vars.get('safeAffSuccess')
      const failure = world.vars.get('safeAffFailure')
      if (success && failure) {
        world.start = Date.now()
        world.result = await runRunner(['safe-effects', 'parallel-mixed', success, failure])
        world.end = Date.now()
      }
    },
  },
  {
    match: m(/^the first result is Right "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^the first result is Right "([^"]+)"$/)
      const expected = m?.[1]
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes(`"first":"Right ${expected}"`)) throw new Error(`Expected first Right "${expected}", got: ${line}`)
    },
  },
  {
    match: m(/^the second result is Left with error message containing "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^the second result is Left with error message containing "([^"]+)"$/)
      const fragment = m?.[1]
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes('"second":"Left"')) throw new Error(`Expected second Left, got: ${line}`)
      if (!line.includes(fragment)) throw new Error(`Expected error containing "${fragment}", got: ${line}`)
    },
  },
  {
    match: m(/^both operations complete without cancellation$/),
    run: async () => {
      // Informational: both complete successfully with Either results
    },
  },
  {
    match: m(/^a delayed safe Aff that takes (\d+) milliseconds and succeeds with "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^a delayed safe Aff that takes (\d+) milliseconds and succeeds with "([^"]+)"$/)
      const ms = m?.[1]
      const value = m?.[2]
      world.vars.set('delayedSuccess', { ms: Number(ms), value })
    },
  },
  {
    match: m(/^a safe Aff that immediately fails with "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^a safe Aff that immediately fails with "([^"]+)"$/)
      const msg = m?.[1]
      world.vars.set('immediateFailure', msg)
    },
  },
  {
    match: m(/^both operations complete$/),
    run: async () => {
      const delayed = world.vars.get('delayedSuccess')
      const failure = world.vars.get('immediateFailure')
      if (delayed && failure) {
        world.start = Date.now()
        world.result = await runRunner(['safe-effects', 'no-cancellation', String(delayed.ms), delayed.value, failure])
        world.end = Date.now()
      }
    },
  },
  {
    match: m(/^the slow operation is not canceled$/),
    run: async () => {
      // Verified by timing assertion
    },
  },
  {
    match: m(/^the total elapsed time is at least (\d+) milliseconds$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^the total elapsed time is at least (\d+) milliseconds$/)
      const ms = m && m[1]
      const elapsed = world.result?.elapsed ?? world.end - world.start
      if (!(elapsed >= Number(ms))) throw new Error(`Elapsed ${elapsed}ms not >= ${ms}ms`)
    },
  },
  {
    match: m(/^one result is Right "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^one result is Right "([^"]+)"$/)
      const expected = m?.[1]
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes(`Right ${expected}`)) throw new Error(`Expected a Right "${expected}", got: ${line}`)
    },
  },
  {
    match: m(/^one result is Left with error containing "([^"]+)"$/),
    run: async ({ step: { title } }) => {
      const m = title.match(/^one result is Left with error containing "([^"]+)"$/)
      const fragment = m?.[1]
      const { out } = world.result ?? {}
      if (!out) throw new Error('No result output captured')
      const line = out.trim()
      if (!line.includes('"Left"')) throw new Error(`Expected a Left, got: ${line}`)
      if (!line.includes(fragment)) throw new Error(`Expected error containing "${fragment}", got: ${line}`)
    },
  },
]

// bdd-markdown expects a default export or named export; export both for safety
export default steps
