# std/cli

`std/cli` parses `main(args: string[])` with a small schema and returns a
flat `SerialValue` object that can be decoded with Doof JSON serialization.

## Documentation

- [Guide and API reference](docs/API.md) explains schema construction, argv parsing rules, JSON output, errors, and typed decoding.
- Tests can be run with `doof test cli`.

## Usage

```doof
import { CliSpec } from "std/cli"

class Options {
  readonly verbose: bool = false
  readonly output: string = "out.txt"
  readonly tag: string[] = []
  readonly input: string
}

function main(args: string[]): int {
  spec := CliSpec.create("tool", "Process an input file.")
    .flag("verbose", "v", "Print more detail")
    .option("output", "o", "PATH", "Output path", false, "out.txt")
    .option("tag", "t", "TAG", "Attach a tag", false, null, true)
    .positional("input", "Input file")

  parsed := spec.parse(args) else error {
    println(error.message)
    println(error.usage)
    return 1
  }

  options := Options.fromSerialValue(parsed.value, true) else error {
    println("Invalid options: ${error}")
    return 1
  }

  if options.verbose {
    println("Writing ${options.input} to ${options.output}")
  }
  return 0
}
```

## API

#### `CliSpec.create(program: string, description: string = ""): CliSpec`

Create a parser schema. Methods mutate and return the same `CliSpec`, so calls
can be chained.

#### `flag(name, short, description, defaultValue): CliSpec`

Declare a boolean flag. Long flags use `--name`; short flags use `-n`.
Declared flags also support `--no-name`.

#### `option(name, short, valueName, description, required, defaultValue, multiple): CliSpec`

Declare a string option. Long options accept `--name value` and
`--name=value`. Short options accept `-n value` and `-nvalue`.

Repeatable options produce a string array. Non-repeatable options produce a
string and fail when repeated.

#### `positional(name, description, required, multiple): CliSpec`

Declare a positional argument. Named positionals are written to the top-level
JSON object. Only the final positional may be `multiple`.

#### `parse(args: string[]): Result<CliArgs, CliError>`

Parse argv tokens. `--` stops option parsing; single `-` is treated as a
positional argument. Unknown options, invalid specs, missing required options,
missing values, duplicate non-repeatable values, and missing required
positionals return `CliError`.

#### `usage(): string`

Render a compact usage string with options and positional arguments.

## JSON Output

`CliArgs.value` is a flat `SerialObject`.

- Flags produce boolean fields.
- Non-repeatable options produce string fields.
- Repeatable options produce string array fields.
- Named positionals produce top-level fields.
- Extra/free positionals are stored in `_` as a string array.
- Optional options are absent unless they have defaults.

`CliArgs` also exposes:

- `has(name: string): bool`
- `flag(name: string): bool`
- `string(name: string): string | null`
- `strings(name: string): readonly string[]`
- `positionals: readonly string[]`

## Notes

`std/cli` does not perform scalar conversion itself. Decode with
`.fromSerialValue(parsed.value, true)` for string, boolean, and string-array
configuration fields. Convert numeric fields in application code after parsing.
