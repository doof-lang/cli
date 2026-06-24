class CliOptionSpec {
  readonly name: string
  readonly short: string | null
  readonly description: string
  readonly valueName: string
  readonly flag: bool
  readonly required: bool
  readonly defaultFlag: bool
  readonly defaultValue: string | null
  readonly multiple: bool
}

class CliPositionalSpec {
  readonly name: string
  readonly description: string
  readonly required: bool
  readonly multiple: bool
}

export class CliError {
  readonly kind: string
  readonly index: int
  readonly name: string | null
  readonly message: string
  readonly usage: string
}

export class CliArgs {
  readonly value: JsonValue
  private objectValue: Map<string, JsonValue>
  readonly positionals: readonly string[]

  private object(): Map<string, JsonValue> {
    return this.objectValue
  }

  has(name: string): bool {
    return this.object().has(name)
  }

  flag(name: string): bool {
    raw := this.object().get(name) else {
      return false
    }
    value := raw as bool else {
      return false
    }
    return value
  }

  string(name: string): string | null {
    raw := this.object().get(name) else {
      return null
    }
    value := raw as string else {
      return null
    }
    return value
  }

  strings(name: string): readonly string[] {
    raw := this.object().get(name) else {
      return readonly []
    }
    values := raw as readonly JsonValue[] else {
      return readonly []
    }

    result: string[] := []
    for item of values {
      value := item as string else {
        continue
      }
      result.push(value)
    }
    return result.buildReadonly()
  }
}

export class CliSpec {
  private readonly program: string
  private readonly description: string
  private options: CliOptionSpec[] = []
  private positionals: CliPositionalSpec[] = []

  static create(program: string, description: string = ""): CliSpec {
    return CliSpec {
      program,
      description,
    }
  }

  flag(
    name: string,
    short: string | null = null,
    description: string = "",
    defaultValue: bool = false,
  ): CliSpec {
    this.options.push(CliOptionSpec {
      name,
      short,
      description,
      valueName: "",
      flag: true,
      required: false,
      defaultFlag: defaultValue,
      defaultValue: null,
      multiple: false,
    })
    return this
  }

  option(
    name: string,
    short: string | null = null,
    valueName: string = "VALUE",
    description: string = "",
    required: bool = false,
    defaultValue: string | null = null,
    multiple: bool = false,
  ): CliSpec {
    this.options.push(CliOptionSpec {
      name,
      short,
      description,
      valueName,
      flag: false,
      required,
      defaultFlag: false,
      defaultValue,
      multiple,
    })
    return this
  }

  positional(
    name: string,
    description: string = "",
    required: bool = true,
    multiple: bool = false,
  ): CliSpec {
    this.positionals.push(CliPositionalSpec {
      name,
      description,
      required,
      multiple,
    })
    return this
  }

  parse(args: string[]): Result<CliArgs, CliError> {
    validation := this.validate()
    case validation {
      f: Failure -> return Failure(f.error)
      _: Success -> {}
    }

    values: Map<string, JsonValue> := {}
    seenOptions: string[] := []
    collectedPositionals: string[] := []

    for option of this.options {
      if option.flag {
        values[option.name] = option.defaultFlag
      } else if option.multiple {
        values[option.name] = []
      } else if option.defaultValue != null {
        values[option.name] = option.defaultValue!
      }
    }

    let index = 0
    let optionsEnded = false
    while index < args.length {
      token := args[index]

      if optionsEnded || token == "-" || !token.startsWith("-") {
        collectedPositionals.push(token)
        index += 1
        continue
      }

      if token == "--" {
        optionsEnded = true
        index += 1
        continue
      }

      if token.startsWith("--") {
        parsed := this.parseLongOption(args, index, values, seenOptions) else error {
          return Failure(error)
        }
        index = parsed
        continue
      }

      parsed := this.parseShortOptions(args, index, values, seenOptions) else error {
        return Failure(error)
      }
      index = parsed
    }

    assigned := this.assignPositionals(collectedPositionals, values) else error {
      return Failure(error)
    }

    for option of this.options {
      if option.required && !values.has(option.name) {
        return Failure { error: this.makeError("missing-required", args.length, option.name, "Missing required option --${option.name}") }
      }
    }

    values["_"] = assigned
    return Success {
      value: CliArgs {
        value: values,
        objectValue: values,
        positionals: collectedPositionals.buildReadonly(),
      }
    }
  }

  usage(): string {
    let text = "Usage: " + this.program

    if this.options.length > 0 {
      text += " [options]"
    }

    for positional of this.positionals {
      let rendered = "<" + positional.name + ">"
      if positional.multiple {
        rendered = rendered + "..."
      }
      if positional.required {
        text += " " + rendered
      } else {
        text += " [" + rendered + "]"
      }
    }

    text += "\n"
    if this.description.length > 0 {
      text += "\n" + this.description + "\n"
    }

    if this.options.length > 0 {
      text += "\nOptions:\n"
      for option of this.options {
        text += "  "
        if option.short != null {
          text += "-" + option.short! + ", "
        } else {
          text += "    "
        }
        text += "--" + option.name
        if !option.flag {
          text += " <" + option.valueName + ">"
        }
        if option.description.length > 0 {
          text += "  " + option.description
        }
        text += "\n"
      }
    }

    if this.positionals.length > 0 {
      text += "\nArguments:\n"
      for positional of this.positionals {
        text += "  " + positional.name
        if positional.multiple {
          text += "..."
        }
        if positional.description.length > 0 {
          text += "  " + positional.description
        }
        text += "\n"
      }
    }

    return text
  }

  private validate(): Result<void, CliError> {
    optionNames: string[] := []
    shorts: string[] := []
    positionalNames: string[] := []

    for index of 0..<this.options.length {
      option := this.options[index]
      if option.name.length == 0 {
        return Failure { error: this.makeError("invalid-spec", index, null, "Option name cannot be empty") }
      }
      if option.name == "_" {
        return Failure { error: this.makeError("invalid-spec", index, option.name, "Option name _ is reserved") }
      }
      if optionNames.contains(option.name) {
        return Failure { error: this.makeError("invalid-spec", index, option.name, "Duplicate option --${option.name}") }
      }
      optionNames.push(option.name)

      if option.short != null {
        short := option.short!
        if short.length != 1 {
          return Failure { error: this.makeError("invalid-spec", index, option.name, "Short option for --${option.name} must be one character") }
        }
        if shorts.contains(short) {
          return Failure { error: this.makeError("invalid-spec", index, option.name, "Duplicate short option -${short}") }
        }
        shorts.push(short)
      }
    }

    for index of 0..<this.positionals.length {
      positional := this.positionals[index]
      if positional.name.length == 0 {
        return Failure { error: this.makeError("invalid-spec", index, null, "Positional name cannot be empty") }
      }
      if positional.name == "_" {
        return Failure { error: this.makeError("invalid-spec", index, positional.name, "Positional name _ is reserved") }
      }
      if optionNames.contains(positional.name) || positionalNames.contains(positional.name) {
        return Failure { error: this.makeError("invalid-spec", index, positional.name, "Duplicate argument name ${positional.name}") }
      }
      if positional.multiple && index != this.positionals.length - 1 {
        return Failure { error: this.makeError("invalid-spec", index, positional.name, "Only the final positional can be multiple") }
      }
      positionalNames.push(positional.name)
    }

    return Success()
  }

  private parseLongOption(
    args: string[],
    index: int,
    values: Map<string, JsonValue>,
    seenOptions: string[],
  ): Result<int, CliError> {
    token := args[index]
    body := token.slice(2)
    separator := body.indexOf("=")
    let name = body
    let inlineValue: string | null = null
    if separator >= 0 {
      name = body.substring(0, separator)
      inlineValue = body.slice(separator + 1)
    }

    let negated = false
    if inlineValue == null && name.startsWith("no-") {
      maybeName := name.slice(3)
      negatedOption := this.optionByName(maybeName)
      if negatedOption != null && negatedOption!.flag {
        name = maybeName
        negated = true
      }
    }

    foundOption := this.optionByName(name)
    if foundOption == null {
      return Failure { error: this.makeError("unknown-option", index, name, "Unknown option --${name}") }
    }

    if foundOption!.flag {
      if inlineValue != null {
        return Failure { error: this.makeError("unexpected-value", index, name, "Flag --${name} does not take a value") }
      }
      values[name] = !negated
      return Success(index + 1)
    }

    let optionValue: string | null = inlineValue
    let nextIndex = index + 1
    if optionValue == null {
      if nextIndex >= args.length {
        return Failure { error: this.makeError("missing-value", index, name, "Option --${name} requires a value") }
      }
      optionValue = args[nextIndex]
      nextIndex += 1
    }

    this.addOptionValue(foundOption!, optionValue!, values, seenOptions, index) else error {
      return Failure(error)
    }
    return Success(nextIndex)
  }

  private parseShortOptions(
    args: string[],
    index: int,
    values: Map<string, JsonValue>,
    seenOptions: string[],
  ): Result<int, CliError> {
    token := args[index]
    body := token.slice(1)
    let offset = 0

    while offset < body.length {
      short := body.substring(offset, offset + 1)
      foundOption := this.optionByShort(short)
      if foundOption == null {
        return Failure { error: this.makeError("unknown-option", index, short, "Unknown option -${short}") }
      }

      if foundOption!.flag {
        values[foundOption!.name] = true
        offset += 1
        continue
      }

      let optionValue = ""
      let nextIndex = index + 1
      if offset + 1 < body.length {
        optionValue = body.slice(offset + 1)
      } else {
        if nextIndex >= args.length {
          return Failure { error: this.makeError("missing-value", index, foundOption!.name, "Option -${short} requires a value") }
        }
        optionValue = args[nextIndex]
        nextIndex += 1
      }

      this.addOptionValue(foundOption!, optionValue, values, seenOptions, index) else error {
        return Failure(error)
      }
      return Success(nextIndex)
    }

    return Success(index + 1)
  }

  private addOptionValue(
    option: CliOptionSpec,
    value: string,
    values: Map<string, JsonValue>,
    seenOptions: string[],
    index: int,
  ): Result<void, CliError> {
    if option.multiple {
      raw := values.get(option.name) else {
        values[option.name] = [value]
        return Success()
      }
      current := raw as JsonValue[] else {
        return Failure { error: this.makeError("invalid-state", index, option.name, "Expected repeatable option storage for --${option.name}") }
      }
      current.push(value)
      values[option.name] = current
      return Success()
    }

    if seenOptions.contains(option.name) {
      return Failure { error: this.makeError("duplicate-option", index, option.name, "Option --${option.name} cannot be repeated") }
    }

    values[option.name] = value
    seenOptions.push(option.name)
    return Success()
  }

  private assignPositionals(
    collected: string[],
    values: Map<string, JsonValue>,
  ): Result<JsonValue[], CliError> {
    extras: JsonValue[] := []

    if this.positionals.length == 0 {
      for value of collected {
        extras.push(value)
      }
      return Success(extras)
    }

    let collectedIndex = 0
    for specIndex of 0..<this.positionals.length {
      positional := this.positionals[specIndex]
      if positional.multiple {
        items: JsonValue[] := []
        while collectedIndex < collected.length {
          items.push(collected[collectedIndex])
          collectedIndex += 1
        }
        if positional.required && items.length == 0 {
          return Failure { error: this.makeError("missing-argument", collectedIndex, positional.name, "Missing required argument ${positional.name}") }
        }
        values[positional.name] = items
        return Success(extras)
      }

      if collectedIndex >= collected.length {
        if positional.required {
          return Failure { error: this.makeError("missing-argument", collectedIndex, positional.name, "Missing required argument ${positional.name}") }
        }
        continue
      }

      values[positional.name] = collected[collectedIndex]
      collectedIndex += 1
    }

    while collectedIndex < collected.length {
      extras.push(collected[collectedIndex])
      collectedIndex += 1
    }

    return Success(extras)
  }

  private optionByName(name: string): CliOptionSpec | null {
    for option of this.options {
      if option.name == name {
        return option
      }
    }
    return null
  }

  private optionByShort(short: string): CliOptionSpec | null {
    for option of this.options {
      if option.short == short {
        return option
      }
    }
    return null
  }

  private makeError(kind: string, index: int, name: string | null, message: string): CliError {
    return CliError {
      kind,
      index,
      name,
      message,
      usage: this.usage(),
    }
  }
}
