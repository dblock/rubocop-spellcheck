# rubocop-spellcheck

[![Ruby](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml)
[![Gem Version](https://badge.fury.io/rb/rubocop-spellcheck.svg)](https://rubygems.org/gems/rubocop-spellcheck)

Spellcheck Ruby comments with [RuboCop](https://rubocop.org/) and [Kotoshu](https://github.com/kotoshu/kotoshu).

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
  - [Language](#language)
  - [Project dictionaries](#project-dictionaries)
  - [Exclusions and suppression](#exclusions-and-suppression)
- [Scope and limitations](#scope-and-limitations)
- [Contributing](#contributing)
- [Copyright and License](#copyright-and-license)

## Installation

Requires Ruby 3.2 or newer and RuboCop 1.72.1 or newer (1.x). Kotoshu 1.0.x declares a Rust extension build; a working Rust toolchain may be required to install it. The extension uses Kotoshu's Ruby spelling backend, without ONNX models or a system Hunspell executable.

Add to your `Gemfile`:

```ruby
group :development do
  gem 'rubocop-spellcheck', require: false
end
```

Enable the plugin in `.rubocop.yml`:

```yaml
plugins:
  - rubocop-spellcheck
```

Prepare the spelling dictionary once, before running RuboCop:

```sh
bundle install
bundle exec kotoshu setup en --want spelling
```

This explicit setup step downloads dictionary resources, not source code. Linting reads cached dictionaries and never initiates downloads. Missing resources produce an error with setup instructions.

For offline provisioning, register local Hunspell files instead:

```sh
bundle exec kotoshu setup en --aff /path/to/en.aff --dic /path/to/en.dic
```

Run the same setup in CI. Kotoshu's `KOTOSHU_CACHE_PATH`, `KOTOSHU_CONFIG_PATH`, and `KOTOSHU_DATA_PATH` control resource locations. For reproducible results across machines, provision identical `.aff` and `.dic` files rather than independently downloading changing upstream dictionaries.

## Usage

`Spellcheck/Comments` is enabled by default:

```ruby
# bad
# Return the resutl.

# good
# Return the result.
```

```sh
bundle exec rubocop
bundle exec rubocop --only Spellcheck/Comments
```

Each offense highlights the misspelled word and includes up to three suggestions when available. Spelling is ambiguous, so there is no autocorrection.

## Configuration

### Language

Choose one explicit Kotoshu language, defaulting to `en`. There is no automatic language detection. Prepare the corresponding resources before linting.

```yaml
Spellcheck:
  Language: en
```

Settings can also be overridden for `Spellcheck/Comments` using normal RuboCop department/cop configuration.

### Project dictionaries

Use version-controlled word lists for project vocabulary, product names, and domain terms. No separate `AllowedWords` list is needed.

```yaml
Spellcheck:
  DictionaryFiles:
    - .spellcheck.txt
```

```text
# Project vocabulary
Kotoshu
RuboCop
```

Each file contains one word per line. Blank lines and lines beginning with `#` are ignored; phrases are rejected. Project vocabulary is matched case-insensitively and literally, without automatic inflection. List additional forms explicitly when needed.

`DictionaryFiles` defaults to an empty array. Paths are relative to the effective RuboCop configuration directory (or the working directory without a configuration file). RuboCop replaces arrays rather than merging them unless you configure `inherit_mode`. Kotoshu's personal dictionary is not consulted, keeping local and CI results consistent.

Changes to project dictionaries or the resolved Hunspell dictionary/affix files invalidate RuboCop's cached results.

### Exclusions and suppression

Use standard RuboCop exclusions and inline directives:

```yaml
Spellcheck/Comments:
  Exclude:
    - spec/fixtures/**/*
```

```ruby
# rubocop:disable Spellcheck/Comments
# Deliberately misspelled example: resutl.
# rubocop:enable Spellcheck/Comments
```

## Scope and limitations

The first release checks Ruby comments only, including trailing comments. It skips shebangs, Ruby magic comments, RuboCop/Standard directives, Sorbet `typed:` declarations, HTTP(S)/`www` URLs, and email addresses. It does not inspect strings, identifiers, symbols, regular expressions, or Markdown files.

Other comment content, including embedded code and documentation tags, is treated as text. Use a project dictionary or standard suppression for intentional non-prose. Word boundaries and spelling follow Kotoshu's selected language; this extension does not add language detection or grammar checking.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and [RELEASING.md](RELEASING.md) for releases.

## Copyright and License

Copyright (c) 2026 Daniel (dB.) Doubrovkine. MIT License; see [LICENSE.txt](LICENSE.txt).

Kotoshu is a separate BSD-2-Clause dependency. Dictionary resources carry their own licenses; preserve their notices when redistributing them.
