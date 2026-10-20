# rubocop-spellcheck

[![Ruby](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml)
[![Gem Version](https://badge.fury.io/rb/rubocop-spellcheck.svg)](https://rubygems.org/gems/rubocop-spellcheck)

Spellcheck Ruby comments with [RuboCop](https://rubocop.org/) and [Kotoshu](https://github.com/kotoshu/kotoshu).

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
  - [Dictionary files](#dictionary-files)
  - [Adding project vocabulary](#adding-project-vocabulary)
  - [Replacing dictionaries and adding languages](#replacing-dictionaries-and-adding-languages)
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

Install and run; the default American English dictionary is included in the gem:

```sh
bundle install
bundle exec rubocop
```

By default, the plugin uses the bundled American English dictionary. No dictionary setup, external cache, or network access is needed.

For another language, download a Hunspell dictionary and its license into your project. For example, download the [latest German resources](https://github.com/kotoshu/dictionaries/tree/v1/de/spelling):

```sh
mkdir -p dictionaries/de
curl -fL https://raw.githubusercontent.com/kotoshu/dictionaries/v1/de/spelling/index.dic -o dictionaries/de/de.dic
curl -fL https://raw.githubusercontent.com/kotoshu/dictionaries/v1/de/spelling/index.aff -o dictionaries/de/de.aff
curl -fL https://raw.githubusercontent.com/kotoshu/dictionaries/v1/de/spelling/license -o dictionaries/de/LICENSE
```

Then configure the locations explicitly:

```yaml
Spellcheck:
  DictionaryFiles:
    de:
      - dictionaries/de/de.dic
```

The matching `dictionaries/de/de.aff` is loaded alongside it. Review the downloaded license and preserve its notices when committing or redistributing dictionary files. Commit these files or provision the same files in CI for reproducible results. You can also point to Hunspell files supplied by your operating system. The plugin does not use Kotoshu's resource cache, registration, or setup command; linting never downloads anything.

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

### Dictionary files

`DictionaryFiles` maps language codes to lists of dictionary paths. When omitted or `null`, it selects packaged English, equivalent to:

```yaml
Spellcheck:
  DictionaryFiles:
    en:
      - gem:rubocop-spellcheck/data/en/en.dic
```

An explicit map replaces the default selection completely; no English dictionary is implicitly retained. Each language key determines Kotoshu's tokenization for its dictionaries. A word passes if any configured dictionary accepts it. This supports multilingual comments, but a typo that is valid in another active language will pass. There is no language detection or separate `Language` setting.

Paths beginning with `gem:<gem-name>/` resolve relative to that installed gem's root; for example, `gem:rubocop-spellcheck/data/en/en.dic`. Other paths are relative to the effective RuboCop configuration directory (or working directory without a configuration file). No ERB is needed. Missing gems, files, empty language lists, and unsupported file extensions produce explicit errors; there is no fallback.

Hunspell `.dic` files load their matching `.aff` file in the same directory with the same basename. Plain `.txt` files contain literal words, one per line, matched case-insensitively without automatic inflection. Blank lines and lines starting with `#` are ignored; phrases are rejected.

Settings can also be overridden for `Spellcheck/Comments` using normal RuboCop department/cop configuration. RuboCop merges explicitly inherited hashes by its normal configuration rules; within an explicit map, arrays replace inherited arrays unless `inherit_mode` says otherwise. Kotoshu's personal dictionary is not consulted. Changes to any selected dictionary or affix file invalidate cached results.

### Adding project vocabulary

Project vocabulary is just a plain `.txt` file with one word per line. Retain the gem dictionary path and append your version-controlled word list for product names and domain terms:

```yaml
Spellcheck:
  DictionaryFiles:
    en:
      - gem:rubocop-spellcheck/data/en/en.dic
      - .spellcheck.txt
```

```text
# Project vocabulary
Kotoshu
RuboCop
```

In `.spellcheck.txt`, blank lines and `#` comments are ignored. Words match case-insensitively, with no automatic inflection: list plural or other forms explicitly when needed. Unlike this literal word list, the bundled English dictionary uses Hunspell's `.dic` word list and `.aff` rules to recognize forms such as plurals and suffixes. Both formats can be combined in `DictionaryFiles`.

There is no separate `AllowedWords`, `DictionaryPath`, or additional-files option. To use only your own word list, omit the gem path.

### Replacing dictionaries and adding languages

List replacement dictionaries and any other active languages explicitly:

```yaml
Spellcheck:
  DictionaryFiles:
    en:
      - dictionaries/custom-en.dic
    de:
      - dictionaries/de/de.dic
```

Both dictionaries participate in spelling checks. To check only German, omit the `en` key. Download instructions above show how to obtain the latest German files and their license.

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

Kotoshu is a separate BSD-2-Clause dependency. The bundled SCOWL-derived American English dictionary carries its own copyright and redistribution terms; see [its full license](data/en/LICENSE) and [pinned provenance](data/en/README.md). Dictionary files and notices are included in the packaged gem.

As of October 20, 2026, `kotoshu/dictionaries` describes its repository as MIT-licensed, but individual dictionaries retain their own licenses. The English package declares [`MIT AND BSD`](https://github.com/kotoshu/dictionaries/blob/v1/en/spelling/package.json); its [full notice](data/en/LICENSE) includes SCOWL's permissive redistribution grant, Ispell's BSD-style terms, and constituent word-list notices. The German dictionary used in the download example is [`GPL-2.0 OR GPL-3.0`](https://github.com/kotoshu/dictionaries/blob/v1/de/spelling/package.json), confirmed by its [license notice](https://github.com/kotoshu/dictionaries/blob/v1/de/spelling/license). German is not bundled with this gem. Other languages vary: inspect each dictionary's own license before using or redistributing it; the repository's MIT label does not relicense those files.
