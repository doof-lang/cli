import { Assert } from "std/assert"
import { formatJsonValue } from "std/json"
import { CliArgs, CliSpec } from "../index"

class DecodeOptions {
  readonly verbose: bool = false
  readonly count: string = "0"
  readonly output: string = "default.txt"
  readonly input: string
}

function parsedValue(spec: CliSpec, args: string[]): JsonValue {
  result := spec.parse(args)
  return case result {
    s: Success -> s.value.value,
    f: Failure -> {
      Assert.fail(f.error.message)
      panic(f.error.message)
      yield none
    }
  }
}

function parsedArgs(spec: CliSpec, args: string[]): CliArgs {
  result := spec.parse(args)
  return case result {
    s: Success -> s.value,
    f: Failure -> {
      Assert.fail(f.error.message)
      panic(f.error.message)
      empty := try! CliSpec.create("empty").parse([])
      yield empty
    }
  }
}

function failure(spec: CliSpec, args: string[]): string {
  result := spec.parse(args)
  return case result {
    s: Success -> {
      Assert.fail("expected parse failure")
      panic("expected parse failure")
      yield ""
    },
    f: Failure -> f.error.kind
  }
}

export function testParsesLongOptionsFlagsDefaultsAndPositionals() {
  spec := CliSpec.create("tool")
    .flag("verbose", "v")
    .flag("color", none, "", true)
    .option("output", "o", "PATH", "", false, "out.txt")
    .positional("input")

  args := parsedArgs(spec, ["--verbose", "--no-color", "--output=build.txt", "src.txt"])

  Assert.isTrue(args.flag("verbose"))
  Assert.isFalse(args.flag("color"))
  Assert.equal(args.string("output")!, "build.txt")
  Assert.equal(args.string("input")!, "src.txt")
  Assert.equal(formatJsonValue(args.value), "{\"verbose\":true,\"color\":false,\"output\":\"build.txt\",\"input\":\"src.txt\",\"_\":[]}")
}

export function testParsesSpaceSeparatedLongOptionValueStartingWithDash() {
  spec := CliSpec.create("tool").option("pattern")
  args := parsedArgs(spec, ["--pattern", "-value"])

  Assert.equal(args.string("pattern")!, "-value")
}

export function testParsesRepeatableOptionsAsArrays() {
  spec := CliSpec.create("tool")
    .option("tag", "t", "TAG", "", false, none, true)

  args := parsedArgs(spec, ["--tag", "doof", "-tstdlib", "-t", "cli"])

  tags := args.strings("tag")
  Assert.equal(tags.length, 3)
  Assert.equal(tags[0], "doof")
  Assert.equal(tags[1], "stdlib")
  Assert.equal(tags[2], "cli")
  Assert.equal(formatJsonValue(args.value), "{\"tag\":[\"doof\",\"stdlib\",\"cli\"],\"_\":[]}")
}

export function testParsesShortFlagBundlesAndShortOptionValues() {
  spec := CliSpec.create("tool")
    .flag("all", "a")
    .flag("verbose", "v")
    .option("output", "o")

  args := parsedArgs(spec, ["-avoresult.txt"])

  Assert.isTrue(args.flag("all"))
  Assert.isTrue(args.flag("verbose"))
  Assert.equal(args.string("output")!, "result.txt")
}

export function testDoubleDashAndSingleDashBecomePositionals() {
  spec := CliSpec.create("tool")
    .flag("verbose", "v")

  args := parsedArgs(spec, ["-", "--", "--verbose", "file"])

  Assert.isFalse(args.flag("verbose"))
  Assert.equal(args.positionals.length, 3)
  Assert.equal(args.positionals[0], "-")
  Assert.equal(args.positionals[1], "--verbose")
  Assert.equal(args.positionals[2], "file")
  Assert.equal(formatJsonValue(args.value), "{\"verbose\":false,\"_\":[\"-\",\"--verbose\",\"file\"]}")
}

export function testNamedAndMultiplePositionals() {
  spec := CliSpec.create("cp")
    .positional("source")
    .positional("destinations", "", true, true)

  args := parsedArgs(spec, ["a.txt", "b.txt", "c.txt"])
  destinations := args.strings("destinations")

  Assert.equal(args.string("source")!, "a.txt")
  Assert.equal(destinations.length, 2)
  Assert.equal(destinations[0], "b.txt")
  Assert.equal(destinations[1], "c.txt")
  Assert.equal(formatJsonValue(args.value), "{\"source\":\"a.txt\",\"destinations\":[\"b.txt\",\"c.txt\"],\"_\":[]}")
}

export function testExtraPositionalsGoInUnderscore() {
  spec := CliSpec.create("tool").positional("input", "", false)
  args := parsedArgs(spec, ["one", "two", "three"])
  extra := args.strings("_")

  Assert.equal(args.string("input")!, "one")
  Assert.equal(extra.length, 2)
  Assert.equal(extra[0], "two")
  Assert.equal(extra[1], "three")
}

export function testErrors() {
  Assert.equal(failure(CliSpec.create("tool").option("output"), ["--output"]), "missing-value")
  Assert.equal(failure(CliSpec.create("tool").option("output"), ["--output", "a", "--output", "b"]), "duplicate-option")
  Assert.equal(failure(CliSpec.create("tool").option("output", none, "PATH", "", true), []), "missing-required")
  Assert.equal(failure(CliSpec.create("tool").flag("verbose"), ["--missing"]), "unknown-option")
  Assert.equal(failure(CliSpec.create("tool").flag("verbose", "v"), ["-x"]), "unknown-option")
  Assert.equal(failure(CliSpec.create("tool").positional("input"), []), "missing-argument")
}

export function testInvalidSpecsReturnErrors() {
  Assert.equal(failure(CliSpec.create("tool").flag(""), []), "invalid-spec")
  Assert.equal(failure(CliSpec.create("tool").flag("one", "x").option("two", "x"), []), "invalid-spec")
  Assert.equal(failure(CliSpec.create("tool").option("_"), []), "invalid-spec")
  Assert.equal(failure(CliSpec.create("tool").positional("many", "", true, true).positional("later"), []), "invalid-spec")
}

export function testUsageMentionsProgramOptionsAndArguments() {
  usage := CliSpec.create("tool", "Does work.")
    .flag("verbose", "v", "Print detail")
    .option("output", "o", "PATH", "Output file")
    .positional("input", "Input file")
    .usage()

  Assert.stringContains(usage, "Usage: tool [options] <input>")
  Assert.stringContains(usage, "Does work.")
  Assert.stringContains(usage, "-v, --verbose")
  Assert.stringContains(usage, "-o, --output <PATH>")
  Assert.stringContains(usage, "input")
}

export function testJsonOutputDecodesWithSerdeLenientMode() {
  spec := CliSpec.create("tool")
    .flag("verbose")
    .option("count")
    .option("output", none, "PATH", "", false, "default.txt")
    .positional("input")

  value := parsedValue(spec, ["--verbose", "--count", "42", "in.txt"])
  options := try! DecodeOptions.fromJsonValue(value, true)

  Assert.isTrue(options.verbose)
  Assert.equal(options.count, "42")
  Assert.equal(options.output, "default.txt")
  Assert.equal(options.input, "in.txt")
}
