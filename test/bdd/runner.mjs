// Lightweight BDD runner using the bdd-markdown library programmatically.
// - Loads step definitions from ./steps.mjs
// - Parses all features under test/features
// - Prints console report and exits non-zero on failure

import { join } from 'node:path'
import { steps } from './steps.mjs'

async function loadBddMarkdown() {
  const nodePath = process.env.NODE_PATH
  if (nodePath) {
    const deps = nodePath.split(':')[0]
    const runFolder = (await import('file://' + join(deps, '@bifravst/bdd-markdown/dist/runner/runFolder.js'))).runFolder
    const consoleReporter = (await import('file://' + join(deps, '@bifravst/bdd-markdown/dist/reporter/consoleReporter.js'))).consoleReporter
    return { runFolder, consoleReporter }
  }
  // Fallback: try bare spec-resolved import (dev)
  const { runFolder } = await import('@bifravst/bdd-markdown/dist/runner/runFolder.js')
  const { consoleReporter } = await import('@bifravst/bdd-markdown/dist/reporter/consoleReporter.js')
  return { runFolder, consoleReporter }
}

let folder = 'test/features'
const arg = process.argv[2]
if (arg) {
  // Accept a folder or a single feature file path
  if (arg.endsWith('.feature.md')) {
    folder = join(process.cwd(), arg.replace(/[^/]+$/, ''))
  } else {
    folder = arg
  }
}

async function main() {
  const { runFolder, consoleReporter } = await loadBddMarkdown()
  let runner
  const fileArg = process.argv[2]
  if (fileArg && fileArg.endsWith('.feature.md')) {
    const nodePath = process.env.NODE_PATH?.split(':')[0]
    if (!nodePath) throw new Error('NODE_PATH not set')
    const { loadFeatureFile } = await import('file://' + join(nodePath, '@bifravst/bdd-markdown/dist/runner/parseFeaturesInFolder.js'))
    const { runSuite } = await import('file://' + join(nodePath, '@bifravst/bdd-markdown/dist/runner/runSuite.js'))
    const suite = [await loadFeatureFile(fileArg)]
    runner = runSuite(suite, 'bdd')
  } else {
    runner = await runFolder({ folder, name: 'bdd' })
  }
  runner.addStepRunners(...steps)
  const report = await runner.run({})
  consoleReporter(report, console.log, { onlyFailed: false, withTimestamps: false })
  if (report.ok !== true) process.exit(1)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
