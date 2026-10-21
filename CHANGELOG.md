## Changelog

### 0.2.0 (Next)

* [#27](https://github.com/dblock/rubocop-spellcheck/pull/27): Correct lowercase and title-case typos when the first suggestion is one edit away, even when multiple suggestions exist; require dictionary-accepted replacements to prevent correction loops and retain uppercase, mixed-case, and technical-token guards - [@dblock](https://github.com/dblock).
* [#26](https://github.com/dblock/rubocop-spellcheck/pull/26): Restrict autocorrection to unique, single-edit lowercase typos outside dotted and identifier-like tokens; keep other suggestions report-only - [@dblock](https://github.com/dblock).
* [#25](https://github.com/dblock/rubocop-spellcheck/pull/25): Skip spelling suggestions during vocabulary generation to speed up `--auto-gen-config` - [@dblock](https://github.com/dblock).
* [#24](https://github.com/dblock/rubocop-spellcheck/pull/24): Fix spelling checks crashing on `__FILE__` in Ruby files and Markdown Ruby fences - [@dblock](https://github.com/dblock).
* [#22](https://github.com/dblock/rubocop-spellcheck/pull/22): Check strings and opt-in identifiers in explicitly tagged Ruby Markdown fences; keep strings enabled and identifiers disabled by default in all Ruby checks - [@dblock](https://github.com/dblock).
* [#21](https://github.com/dblock/rubocop-spellcheck/pull/21): Check Ruby strings and identifiers by default, with independent opt-outs, source-mapped string corrections, and report-only identifier diagnostics - [@dblock](https://github.com/dblock).
* [#20](https://github.com/dblock/rubocop-spellcheck/pull/20): Generate project vocabulary and dictionary configuration with `rubocop --auto-gen-config` instead of suppressing spelling checks - [@dblock](https://github.com/dblock).
* [#19](https://github.com/dblock/rubocop-spellcheck/pull/19): Add parser-backed AsciiDoc spelling checks and autocorrection - [@dblock](https://github.com/dblock).
* [#18](https://github.com/dblock/rubocop-spellcheck/pull/18): Check RDoc files and parse RDoc markup in Ruby comments, excluding code examples and link destinations - [@dblock](https://github.com/dblock).
* [#17](https://github.com/dblock/rubocop-spellcheck/pull/17): Select front matter values with dotted inclusion and exclusion paths - [@dblock](https://github.com/dblock).
* [#16](https://github.com/dblock/rubocop-spellcheck/pull/16): Support Markdown HTML comment directives for spelling suppression - [@dblock](https://github.com/dblock).
* [#15](https://github.com/dblock/rubocop-spellcheck/pull/15): Add spelling autocorrection for words with exactly one dictionary suggestion - [@dblock](https://github.com/dblock).
* [#14](https://github.com/dblock/rubocop-spellcheck/pull/14): Reuse loaded dictionaries and word verdicts across file investigations instead of rebuilding them for every file - [@dblock](https://github.com/dblock).
* Your contribution here.

### 0.1.0 (2026/10/20)

* [#12](https://github.com/dblock/rubocop-spellcheck/pull/12): Preserve Markdown parsing and use original prose buffers - [@dblock](https://github.com/dblock).
* [#9](https://github.com/dblock/rubocop-spellcheck/pull/9): Preserve English accented words and ignore quoted delimiters, numeric identifiers, and Liquid template expressions in Markdown - [@dblock](https://github.com/dblock).
* [#6](https://github.com/dblock/rubocop-spellcheck/pull/6): Include plain text files by default while excluding configured dictionaries and bundled dictionary resources from spelling checks - [@dblock](https://github.com/dblock).
* [#8](https://github.com/dblock/rubocop-spellcheck/pull/8): Check YAML front matter string values recursively with original source locations and grouped Markdown settings - [@dblock](https://github.com/dblock).
* [#7](https://github.com/dblock/rubocop-spellcheck/pull/7): Separate lint, test, and package workflows with individual status badges - [@dblock](https://github.com/dblock).
* [#5](https://github.com/dblock/rubocop-spellcheck/pull/5): Rename Spellcheck/Comments to Spellcheck/Spelling and check Markdown prose with original source locations and shared dictionaries - [@dblock](https://github.com/dblock).
* [#4](https://github.com/dblock/rubocop-spellcheck/pull/4): Enable rubocop-rake and rubocop-rspec for development and disable Metrics/BlockLength - [@dblock](https://github.com/dblock).
* [#3](https://github.com/dblock/rubocop-spellcheck/pull/3): Enable this gem's own Spellcheck/Comments cop in repository linting with a project vocabulary file - [@dblock](https://github.com/dblock).
* [#2](https://github.com/dblock/rubocop-spellcheck/pull/2): Add monthly and manual maintenance PRs for the latest stable Kotoshu release and bundled English dictionary with license and provenance updates - [@dblock](https://github.com/dblock).
* [#1](https://github.com/dblock/rubocop-spellcheck/pull/1): Bundle English for zero-setup defaults and support language-keyed DictionaryFiles with gem-relative and local paths for replacement, supplemental vocabulary, and multilingual checking - [@dblock](https://github.com/dblock).
* Initial implementation of Spellcheck/Spelling with offline Kotoshu dictionaries, project vocabulary, precise offenses, and spelling suggestions - [@dblock](https://github.com/dblock).
