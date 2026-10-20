# rubocop-spellcheck

[![Tests](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml)
[![Lint](https://github.com/dblock/rubocop-spellcheck/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/lint.yml)
[![Package](https://github.com/dblock/rubocop-spellcheck/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/package.yml)
[![Gem Version](https://badge.fury.io/rb/rubocop-spellcheck.svg)](https://rubygems.org/gems/rubocop-spellcheck)

Spellcheck Ruby comments and Markdown prose with [RuboCop](https://rubocop.org/) and [Kotoshu](https://github.com/kotoshu/kotoshu).

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

Requires Ruby 3.2 or newer and RuboCop 1.72.1 or newer (1.x).

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

`Spellcheck/Spelling` is enabled by default:

```ruby
# bad
# The red brown fox jumsp over the lazy dog.

# good
# The red brown fox jumps over the lazy dog.
```

```sh
bundle exec rubocop
bundle exec rubocop --only Spellcheck/Spelling
```

For example, given `example.rb`:

```ruby
# The red brown fox jumsp over the lazy dog.
```

Running `bundle exec rubocop --only Spellcheck/Spelling example.rb` reports:

```text
Inspecting 1 file
C

Offenses:

example.rb:1:21: C: Spellcheck/Spelling: Misspelled word: jumsp. Did you mean jumps, jump, jumpy?
# The red brown fox jumsp over the lazy dog.
                    ^^^^^

1 file inspected, 1 offense detected
```

Each offense highlights the misspelled word and includes up to three suggestions when available. Spelling is ambiguous, so there is no autocorrection.

The same cop discovers `.md` and `.markdown` files and checks their prose:

```markdown
# The red brown fox jumsp over the lazy dog.

Check [the spelling](https://example.com) but not `code_identifiers`.
```

Markdown headings, paragraphs, lists, blockquotes, table cells, link labels, image descriptions, and footnote text are checked. Code blocks and inline code, link destinations and reference identifiers, and HTML tags/comments and HTML blocks are skipped. URLs and email addresses are ignored in both formats. HTML entities and escaped punctuation are decoded with offenses mapped back to the original source. No `rubocop-md` plugin is required; Ruby code inside Markdown blocks is not inspected.

YAML front matter checks string values recursively, including values inside mappings and arrays. Keys and strongly typed values such as numbers, booleans, dates, timestamps, and nulls are skipped. Quoted values are strings even when their contents resemble another type. Anchored strings are checked at their definition, not repeated through aliases; explicit string tags are supported, while other tags are ignored. YAML is parsed without constructing application objects. Plain and quoted values and multiline literal/folded values retain their original diagnostic locations, including quoted escape sequences. Invalid YAML produces an explicit error. Strings such as layout names and slugs are checked too; add intentional vocabulary to your dictionary. To disable front matter checks:

```yaml
Spellcheck/Spelling:
  Markdown:
    FrontMatter:
      Enabled: false
```

Before the first release, `Spellcheck/Comments` was renamed to `Spellcheck/Spelling`. Update any existing cop-specific configuration, `--only` arguments, or Ruby suppression directives to use the new name.

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

Settings can also be overridden for `Spellcheck/Spelling` using normal RuboCop department/cop configuration. RuboCop merges explicitly inherited hashes by its normal configuration rules; within an explicit map, arrays replace inherited arrays unless `inherit_mode` says otherwise. Kotoshu's personal dictionary is not consulted. Changes to any selected dictionary or affix file invalidate cached results.

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
Spellcheck/Spelling:
  Exclude:
    - spec/fixtures/**/*
```

```ruby
# rubocop:disable Spellcheck/Spelling
# Deliberately misspelled example: resutl.
# rubocop:enable Spellcheck/Spelling
```

Ruby inline directives apply to comments; Markdown HTML comments are ignored, not interpreted as suppression directives. To check only one format, use standard file inclusion:

```yaml
Spellcheck/Spelling:
  Include:
    - "**/*.rb"
```

## Scope and limitations

The first release checks Ruby comments, including trailing comments, and Markdown prose. Ruby checks skip shebangs, magic comments, RuboCop/Standard directives, and Sorbet `typed:` declarations. It does not inspect Ruby strings, identifiers, symbols, or regular expressions.

Other comment content, including embedded code and documentation tags, is treated as text. Use a project dictionary or standard suppression for intentional non-prose. Word boundaries and spelling follow Kotoshu's selected language; this extension does not add language detection or grammar checking.

Kotoshu ships precompiled gems for macOS, Linux, and Windows. Building native dependencies from source on other platforms may require a Rust toolchain.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and [RELEASING.md](RELEASING.md) for releases.

## Copyright and License

Copyright (c) 2026 Daniel (dB.) Doubrovkine. MIT License; see [LICENSE.txt](LICENSE.txt).

Kotoshu is a separate BSD-2-Clause dependency. The bundled SCOWL-derived American English dictionary carries its own copyright and redistribution terms; see [its full license](data/en/LICENSE) and [pinned provenance](data/en/README.md). Dictionary files and notices are included in the packaged gem.

As of October 20, 2026, `kotoshu/dictionaries` describes its repository as MIT-licensed, but individual dictionaries retain their own licenses. The English package declares [`MIT AND BSD`](https://github.com/kotoshu/dictionaries/blob/v1/en/spelling/package.json); its [full notice](data/en/LICENSE) includes SCOWL's permissive redistribution grant, Ispell's BSD-style terms, and constituent word-list notices. The German dictionary used in the download example is [`GPL-2.0 OR GPL-3.0`](https://github.com/kotoshu/dictionaries/blob/v1/de/spelling/package.json), confirmed by its [license notice](https://github.com/kotoshu/dictionaries/blob/v1/de/spelling/license). German is not bundled with this gem. Other languages vary: inspect each dictionary's own license before using or redistributing it; the repository's MIT label does not relicense those files.
