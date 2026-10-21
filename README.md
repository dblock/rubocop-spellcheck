# rubocop-spellcheck

[![Tests](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/test.yml)
[![Lint](https://github.com/dblock/rubocop-spellcheck/actions/workflows/lint.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/lint.yml)
[![Package](https://github.com/dblock/rubocop-spellcheck/actions/workflows/package.yml/badge.svg)](https://github.com/dblock/rubocop-spellcheck/actions/workflows/package.yml)
[![Gem Version](https://badge.fury.io/rb/rubocop-spellcheck.svg)](https://rubygems.org/gems/rubocop-spellcheck)

Spellcheck Ruby comments, strings, identifiers, and documentation with [RuboCop](https://rubocop.org/) and [Kotoshu](https://github.com/kotoshu/kotoshu).

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Other languages](#other-languages)
- [Supported files](#supported-files)
  - [Ruby comments](#ruby-comments)
  - [Ruby strings and identifiers](#ruby-strings-and-identifiers)
  - [RDoc](#rdoc)
  - [Markdown](#markdown)
  - [YAML front matter](#yaml-front-matter)
  - [AsciiDoc](#asciidoc)
  - [Plain text](#plain-text)
- [Autocorrection](#autocorrection)
- [Configuration](#configuration)
  - [Front matter paths](#front-matter-paths)
  - [Dictionary files](#dictionary-files)
  - [Adding project vocabulary](#adding-project-vocabulary)
  - [Generating project vocabulary](#generating-project-vocabulary)
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

No dictionary setup or network access is needed.

## Usage

`Spellcheck/Spelling` is enabled by default and checks Ruby comments, strings, identifiers, Markdown, RDoc, AsciiDoc, and plain text:

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
example.rb:1:21: C: Spellcheck/Spelling: Misspelled word: jumsp. Did you mean jumps, jump, jumpy?
# The red brown fox jumsp over the lazy dog.
                    ^^^^^
```

Each offense highlights the misspelled word and includes up to three suggestions when available.

Fix typos, then generate an initial `.spellcheck.txt` for remaining project-specific words:

```sh
bundle exec rubocop --auto-gen-config --only Spellcheck/Spelling
```

The command adds both the bundled English dictionary and `.spellcheck.txt` to your configuration when no dictionaries are configured. Review the generated vocabulary: remaining typos are accepted too. See [Generating project vocabulary](#generating-project-vocabulary) for regeneration behavior.

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

The matching `.aff` file is required. Commit both files and their license, or provision them in CI. Review each dictionary's license before redistributing it; linting never downloads dictionaries.

## Supported files

### Ruby comments

Ruby comments, including trailing and block comments, are checked. Shebangs, magic comments, RuboCop/Standard directives, and Sorbet `typed:` declarations are skipped. URLs and email addresses are ignored.

Comments are parsed as RDoc, excluding indented examples and inline code.

### Ruby strings and identifiers

Strings include ordinary and percent literals, string arrays, heredocs, and literal text inside interpolation. Contents are checked literally, not as markup. Symbols, regular expression text, and shell-command text are excluded; Ruby expressions inside interpolation are still checked. Ruby code is never evaluated.

Every identifier occurrence is checked, including method calls, definitions, constants, arguments, and variables. Names such as `hello_world`, `helloWorld`, and `HTTPClient` are split at underscores, numbers, and case boundaries. Add intentional API names and abbreviations to your project vocabulary.

Disable either scope independently, or disable both to retain comment-only Ruby checks:

```yaml
Spellcheck/Spelling:
  Ruby:
    Strings: false
    Identifiers: false
```

Standard Ruby suppression directives apply to all three scopes. Identifier errors are report-only: renaming one occurrence could break references or external APIs. Strings support `rubocop -A`, but changing a string can change program behavior; review these edits carefully.

### RDoc

`.rdoc` files and Ruby comments use RDoc parsing. Headings, paragraphs, lists, and link labels are checked; code, link destinations, and documentation directives are skipped. Directives such as `:include:` are never executed.

### Markdown

The cop discovers `.md` and `.markdown` files and checks their prose:

```markdown
# The red brown fox jumsp over the lazy dog.

Check [the spelling](https://example.com) but not `code_identifiers`.
```

Prose, headings, lists, tables, link labels, image descriptions, and footnotes are checked. Code, link destinations, HTML, Liquid expressions, URLs, and email addresses are skipped. No `rubocop-md` plugin is required.

### YAML front matter

String values are checked recursively, including multiline values and arrays. Keys, numbers, booleans, dates, and nulls are skipped. Layout names and slugs are strings too; use [front matter paths](#front-matter-paths) to select prose fields. Invalid YAML produces an error. To disable these checks:

```yaml
Spellcheck/Spelling:
  Markdown:
    FrontMatter:
      Enabled: false
```

### AsciiDoc

`.adoc` and `.asciidoc` files use [Asciidoctor](https://asciidoctor.org/) to check prose, headings, lists, tables, and link labels. Code, comments, attributes, link destinations, and macros are skipped. Includes and extensions are disabled; linting does not render documents or access external resources.

### Plain text

`.txt` files are checked literally, excluding URLs and email addresses. Configured dictionaries and bundled resources are excluded automatically. Use normal RuboCop exclusions for other files you do not want checked.

## Autocorrection

Dictionary suggestions may not match your intended meaning, so spelling corrections require `rubocop -A`; `rubocop -a` leaves spelling unchanged. To apply corrections, use:

```sh
bundle exec rubocop -A --only Spellcheck/Spelling
```

Only words with exactly one suggestion are corrected. Words with multiple suggestions, no suggestions, or mixed capitalization remain unchanged. Corrections preserve lowercase, title case, or uppercase and do not introduce multiple words or formatting characters. Review the resulting diff.

Corrections preserve surrounding markup and string delimiters; escaped letters may become literal letters. Unsafe replacements such as a heredoc terminator or a typed YAML value are withheld. Identifiers are never renamed.

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

Paths are case-sensitive, with dots separating nested keys. Selecting a parent includes its descendants; `authors.description` selects descriptions in every author mapping without array indices. Wildcards and literal dots in key names are not supported.

`Include: null` checks all paths; `Include: []` checks none. `Exclude` always takes precedence. These settings do not affect Markdown body prose.

### Dictionary files

`DictionaryFiles` maps language codes to lists of dictionary paths. When omitted or `null`, it selects packaged English, equivalent to:

```yaml
Spellcheck:
  DictionaryFiles:
    en:
      - gem:rubocop-spellcheck/data/en/en.dic
```

An explicit map replaces the defaults: retain the English path if you still want English. A word passes if any configured dictionary accepts it; there is no automatic language detection.

`gem:<gem-name>/` paths resolve inside the installed gem. Other paths are relative to the effective RuboCop configuration directory. Missing dictionaries and invalid settings produce errors rather than falling back to defaults.

Hunspell `.dic` files load their matching `.aff` file in the same directory with the same basename. Plain `.txt` files contain literal words, one per line, matched case-insensitively without automatic inflection. Blank lines and lines starting with `#` are ignored; phrases are rejected.

Normal RuboCop inheritance and cop-specific overrides apply. Dictionary changes invalidate cached results; Kotoshu's personal dictionary is not used.

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

Words match case-insensitively; list plural and other forms explicitly. Blank lines and `#` comments are ignored. To use only your own word list, omit the gem path.

### Generating project vocabulary

Use the RuboCop configuration generator to build an initial vocabulary:

```sh
bundle exec rubocop --auto-gen-config
```

Spelling offenses create or update `.spellcheck.txt`. To generate vocabulary without configuring other cops:

```sh
bundle exec rubocop --auto-gen-config --only Spellcheck/Spelling
```

Every reported misspelling becomes accepted vocabulary, including genuine typos and words with correction suggestions. **Review the generated list**, remove mistakes, and fix them in the source. Generation does not correct source files.

Rerunning rebuilds `.spellcheck.txt` from current violations without accepting its existing words during checking. Unneeded entries are removed, including manually added ones. Comments and capitalization of retained words are preserved; new words are lowercase, sorted, and added without duplicates. The command adds the vocabulary to `DictionaryFiles` while retaining existing dictionaries, or bundled English when using defaults.

Vocabulary is written beside the effective configuration, including nested configurations. Exclusions and suppression still apply. **Run against the full intended file set:** words needed only in omitted files will be removed. Clean runs clear obsolete entries but do not create a new vocabulary file.

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

Ruby directives apply to comments, strings, and identifiers. In Markdown, use HTML comments:

```markdown
<!-- rubocop:disable Spellcheck/Spelling -->
Intentional project vocabulary.
<!-- rubocop:enable Spellcheck/Spelling -->
```

A trailing `disable` or any `todo` applies only to its own line. Directives accept `all`, cop lists, and reasons after ` -- `. Directives inside code, Liquid, or front matter are ignored. Suppression prevents diagnostics and autocorrection.

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

Other dictionaries have their own licenses regardless of the dictionary repository's license. The German example is [`GPL-2.0 OR GPL-3.0`](https://github.com/kotoshu/dictionaries/blob/v1/de/spelling/license) and is not bundled. Review each dictionary's notices before redistributing it.
