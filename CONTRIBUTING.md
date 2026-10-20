# Contributing

Fork the repository, create a topic branch from `master`, and keep each pull request focused on one change.

## Development

```sh
bundle install
bundle exec rake
```

The default task runs RSpec and RuboCop. Unit tests use tiny local Hunspell fixtures and need no downloaded dictionaries or network access. The integration spec uses the actual bundled English dictionary with an empty, isolated Kotoshu cache and exercises the real RuboCop CLI, plugin discovery, and cache invalidation. Coverage is written to `coverage/`.

For manual checks against a real dictionary:

```sh
bundle exec rubocop --plugin rubocop-spellcheck --only Spellcheck/Comments path/to/file.rb
```

Add focused regression specs for changed behavior, including precise offense ranges. Update README documentation and add a CHANGELOG entry under the next version with the PR number and contributor attribution. Keep Markdown paragraphs on one line.

The bundled English dictionary and its full license must ship together. See [data/en/README.md](data/en/README.md) for provenance and update instructions. DictionaryFiles maps language codes to explicit gem-relative or local Hunspell/text files, never a Kotoshu-managed resource cache.

Run `bundle exec rake` before committing. Do not introduce implicit resource downloads or silently skip unavailable dictionaries. Do not publish a gem or tag a release without maintainer authorization.
