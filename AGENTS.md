# Working on rubocop-spellcheck

Read CONTRIBUTING.md before making changes. This gem checks Ruby comments, Markdown, RDoc, AsciiDoc, and plain text through Kotoshu; Ruby strings, identifiers, and grammar are outside its scope. Ruby comments use RDoc markup. Spelling autocorrection requires `rubocop -A` and is limited to words with exactly one suggestion.

* Keep the implementation small: one Spellcheck/Spelling cop, source-specific extraction, and one shared Kotoshu adapter. Never mutate Kotoshu's global configuration or download resources while linting.
* Default English uses the bundled dictionary without setup. DictionaryFiles maps language codes to paths; explicit maps replace the default. Resolve gem:name/path inside installed gems, ordinary paths relative to configuration. Never use Kotoshu-managed resources. Ship dictionary files with their license and pinned provenance.
* Keep project vocabulary in DictionaryFiles alongside retained primary dictionaries, not an AllowedWords option or personal dictionary.
* Preserve original source offsets, including Unicode. Add focused offense-range tests for extraction changes and real Kotoshu coverage for spelling behavior.
* Include external dictionary content in RuboCop cache invalidation.
* New cops are enabled by default. Update README, the Table of Contents, and CHANGELOG for public changes; include PR links and contributor attribution in changelog entries. After opening a PR, add its assigned number and link to the changelog entry, amend the existing commit, and push the update.
* When cooperating with Markdown source providers, preserve their parsing, inspect the original prose buffer, and map offense ranges through their document API. For now, test source preservation without simulating another plugin. Add integration tests against actual `rubocop-md` in future work, not a replacement parser fixture.
* Keep Markdown paragraphs on one line. Run `bundle exec rake` before committing.
* Use topic branches and one commit per PR. Do not force-push master. Do not merge, publish, or tag without explicit authorization; follow RELEASING.md for authorized releases.
