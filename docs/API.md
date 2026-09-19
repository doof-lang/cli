# std/cli Guide

`std/cli` turns `main(args: string[])` into a flat `SerialObject` using an
application-defined schema. It deliberately stops at strings, booleans, and
string arrays; decode the resulting JSON into an application type or perform
numeric conversion in application code.

## Quick Start

```doof
import { CliSpec } from "std/cli"

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
```

## Schema Model

`CliSpec.create(program, description)` creates a mutable schema. Builder methods
return the same `CliSpec`, so declarations can be chained.

- `flag` declares a boolean value. Long flags use `--name`, short flags use
  `-n`, and every flag also supports `--no-name`.
- `option` declares a string value. Repeatable options produce string arrays.
- `positional` declares positional arguments. Only the final positional may be
  `multiple`.

The parser validates the schema before parsing, so invalid specifications return
`CliError` through `parse`.

## Argv Rules

Long options accept `--name value` and `--name=value`. Short options accept
`-n value` and `-nvalue`. Short boolean flags may be grouped.

`--` stops option parsing. A single `-` is treated as a positional argument.

Unknown options, missing option values, duplicate non-repeatable values, missing
required values, and unassignable positionals return `CliError`.

## JSON Output

`CliArgs.value` is a flat `SerialObject`:

- flags produce boolean fields
- non-repeatable options produce string fields
- repeatable options produce string array fields
- named positionals produce top-level fields
- extra/free positionals are stored in `_`
- optional options are absent unless they have defaults

`CliArgs` also provides typed convenience accessors for common reads.

## API

### `CliError`

```doof
export class CliError
```

Fields:

- `kind: string`
- `index: int`
- `name: string | null`
- `message: string`
- `usage: string`

Defined in [index.do](../index.do).

### `CliArgs`

```doof
export class CliArgs
```

Fields and methods:

- `value: SerialValue`
- `positionals: readonly string[]`
- `has(name: string): bool`
- `flag(name: string): bool`
- `string(name: string): string | null`
- `strings(name: string): readonly string[]`

Defined in [index.do](../index.do).

### `CliSpec`

```doof
export class CliSpec
```

Schema methods:

- `static create(program: string, description: string = ""): CliSpec`
- `flag(name: string, short: string | null = null, description: string = "", defaultValue: bool = false): CliSpec`
- `option(name: string, short: string | null = null, valueName: string = "VALUE", description: string = "", required: bool = false, defaultValue: string | null = null, multiple: bool = false): CliSpec`
- `positional(name: string, description: string = "", required: bool = true, multiple: bool = false): CliSpec`

Runtime methods:

- `parse(args: string[]): Result<CliArgs, CliError>`
- `usage(): string`

Defined in [index.do](../index.do).
