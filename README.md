# rubocop-spellcheck

[![Tests](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml)
[![Lint](https://github.com/dblock/rubocop-spellcheck/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/lint.yml)
[![Package](https://github.com/dblock/rubocop-spellcheck/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/package.yml)
[![Gem Version](https://badge.fury.io/rb/rubocop-spellcheck.svg)](https://rubygems.org/gems/rubocop-spellcheck)

Spellcheck Ruby comments, Markdown prose, and plain text with [RuboCop](https://rubocop.org/) and [Kotoshu](https://github.com/kotoshu/kotoshu).

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Other languages](#other-languages)
- [Supported files](#supported-files)
  - [Ruby comments](#ruby-comments)
  - [RDoc](#rdoc)
  - [Markdown](#markdown)
  - [YAML front matter](#yaml-front-matter)
  - [Plain text](#plain-text)
- [Autocorrection](#autocorrection)
- [Configuration](#configuration)
  - [Front matter paths](#front-matter-paths)
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

## Usage

`Spellcheck/Spelling` is enabled by default and checks Ruby comments, Markdown prose, and plain text:

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

Each offense highlights the misspelled word and includes up to three suggestions when available.

## Other languages

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

## Supported files

### Ruby comments

Ruby comments, including trailing and block comments, are checked. Shebangs, magic comments, RuboCop/Standard directives, and Sorbet `typed:` declarations are skipped. Ruby strings, identifiers, symbols, and regular expressions are not inspected. URLs and email addresses are ignored.

Adjacent comment lines are parsed together as RDoc, so indented examples and inline code are excluded rather than treated as prose. One conventional space after `#` is removed before parsing; additional indentation is retained. This also applies to block comments.

### RDoc

Standalone `.rdoc` files are discovered automatically and parsed with RDoc. Headings, paragraphs, and list descriptions are checked, including emphasis and link labels. Indented verbatim examples, inline code (`+code+`, backticks, `<tt>`, and `<code>`), link destinations, and colon-style documentation directive lines are skipped. Directives such as `:include:` are never executed. Diagnostics and autocorrection retain original source locations and markup, including in Ruby comments.

### Markdown

The cop discovers `.md` and `.markdown` files and checks their prose:

```markdown
# The red brown fox jumsp over the lazy dog.

Check [the spelling](https://example.com) but not `code_identifiers`.
```

Markdown headings, paragraphs, lists, blockquotes, table cells, link labels, image descriptions, and footnote text are checked. Code blocks and inline code, link destinations and reference identifiers, and HTML tags/comments and HTML blocks are skipped. URLs and email addresses are ignored. HTML entities and escaped punctuation are decoded with offenses mapped back to the original source. No `rubocop-md` plugin is required; Ruby code inside Markdown blocks is not inspected.

Liquid output expressions and tags are ignored, including expressions inside link destinations.

### YAML front matter

YAML front matter checks string values recursively, including values inside mappings and arrays. Keys and strongly typed values such as numbers, booleans, dates, timestamps, and nulls are skipped. Quoted values are strings even when their contents resemble another type. Anchored strings are checked at their definition, not repeated through aliases; explicit string tags are supported, while other tags are ignored. YAML is parsed without constructing application objects. Plain and quoted values and multiline literal/folded values retain their original diagnostic locations, including quoted escape sequences. Invalid YAML produces an explicit error. Strings such as layout names and slugs are checked too; add intentional vocabulary to your dictionary. To disable front matter checks:

```yaml
Spellcheck/Spelling:
  Markdown:
    FrontMatter:
      Enabled: false
```

### Plain text

Plain `.txt` files are discovered by default. Their entire contents are checked literally, including text that looks like Markdown code or headings; URLs and email addresses are ignored. Configured dictionary files (including symbolic links to them) and this gem's bundled `data/` resources are excluded from spelling checks, so dictionary words and license/provenance files are not treated as prose. Hunspell `.dic` and `.aff` files are not included by default. Other text files, including project license files, can be excluded with normal `Spellcheck/Spelling` configuration.

## Autocorrection

Dictionary suggestions may not match your intended meaning, so spelling corrections require `rubocop -A`; `rubocop -a` leaves spelling unchanged. To apply corrections, use:

```sh
bundle exec rubocop -A --only Spellcheck/Spelling
```

Only words with exactly one suggestion are corrected. Words with multiple suggestions, no suggestions, or mixed capitalization remain unchanged. Corrections preserve lowercase, title case, or uppercase and do not introduce multiple words or formatting characters. Review the resulting diff.

Corrections apply to Ruby comments, Markdown prose, YAML front matter strings, and plain text. Surrounding punctuation, Markdown formatting, YAML quotes, and excluded content remain unchanged. Escaped letters inside a corrected word may become literal letters; YAML apostrophes are escaped where required. A plain YAML value is not corrected into a boolean, null, or other typed value.

## Configuration

### Front matter paths

By default, all front matter string values are checked. Use dotted paths under `Markdown.FrontMatter` to select which values participate:

```yaml
Spellcheck/Spelling:
  Markdown:
    FrontMatter:
      Enabled: true
      Include:
        - title
        - description
        - metadata
        - authors.description
      Exclude:
        - metadata.slug
        - metadata.internal
```

Paths match exact, case-sensitive key names from the root; dots separate nested keys. Selecting a parent such as `metadata` includes its descendants. Array items use the same path without numeric indices, so `authors.description` selects descriptions in every author mapping. Dots in literal key names and complex YAML keys cannot be addressed by these selectors; wildcards are not supported.

`Include: null` checks all paths; `Include: []` checks none. `Exclude` defaults to an empty list and always takes precedence, including for entire nested mappings. Filtering applies to both diagnostics and autocorrection, without affecting Markdown body prose. `Enabled: false` still disables all front matter checking.

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

Ruby inline directives apply to comments. In Markdown, use HTML comments to disable spelling for a block:

```markdown
<!-- rubocop:disable Spellcheck/Spelling -->
Intentional project vocabulary.
<!-- rubocop:enable Spellcheck/Spelling -->
```

A trailing `<!-- rubocop:disable Spellcheck/Spelling -->` or `<!-- rubocop:todo Spellcheck/Spelling -->` suppresses only its own line. A standalone `todo` also applies only to its own line. Directives accept `all` or comma-separated cop names and an optional reason after ` -- `. Directives inside code, Liquid expressions, or YAML front matter are not interpreted. Suppression prevents both diagnostics and autocorrection.

To check only one format, use standard file inclusion:

```yaml
Spellcheck/Spelling:
  Include:
    - "**/*.rb"
```

## Scope and limitations

English words retain accented letters and internal apostrophes; surrounding quotation marks and numeric identifiers such as commit hashes and ordinals are not checked.

Ruby comments use RDoc markup, not YARD or other documentation syntaxes. Other documentation tags are treated as text. Use a project dictionary or standard suppression for intentional non-prose. Word boundaries and spelling follow Kotoshu's selected language; this extension does not add language detection or grammar checking.

Kotoshu ships precompiled gems for macOS, Linux, and Windows. Building native dependencies from source on other platforms may require a Rust toolchain.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and [RELEASING.md](RELEASING.md) for releases.

## Copyright and License

Copyright (c) 2026 Daniel (dB.) Doubrovkine. MIT License; see [LICENSE.txt](LICENSE.txt).

Kotoshu is a separate BSD-2-Clause dependency. The bundled SCOWL-derived American English dictionary carries its own copyright and redistribution terms; see [its full license](data/en/LICENSE) and [pinned provenance](data/en/README.md). Dictionary files and notices are included in the packaged gem.

As of October 20, 2026, `kotoshu/dictionaries` describes its repository as MIT-licensed, but individual dictionaries retain their own licenses. The English package declares [`MIT AND BSD`](https://github.com/kotoshu/dictionaries/blob/v1/en/spelling/package.json); its [full notice](data/en/LICENSE) includes SCOWL's permissive redistribution grant, Ispell's BSD-style terms, and constituent word-list notices. The German dictionary used in the download example is [`GPL-2.0 OR GPL-3.0`](https://github.com/kotoshu/dictionaries/blob/v1/de/spelling/package.json), confirmed by its [license notice](https://github.com/kotoshu/dictionaries/blob/v1/de/spelling/license). German is not bundled with this gem. Other languages vary: inspect each dictionary's own license before using or redistributing it; the repository's MIT label does not relicense those files.
