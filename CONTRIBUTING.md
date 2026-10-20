# Contributing

Fork the repository, create a topic branch from `master`, and keep each pull request focused on one change.

## Development

```sh
bundle install
bundle exec rake
```

The default task runs RSpec and RuboCop. Tests use tiny local Hunspell fixtures and need no downloaded dictionaries or network access. The integration spec registers those fixtures in an isolated Kotoshu cache and exercises the real RuboCop CLI, plugin discovery, and cache invalidation. Coverage is written to `coverage/`.

For manual checks against a real dictionary:

```sh
bundle exec kotoshu setup en --want spelling
bundle exec rubocop --plugin rubocop-spellcheck --only Spellcheck/Comments path/to/file.rb
```

Add focused regression specs for changed behavior, including precise offense ranges. Update README documentation and add a CHANGELOG entry under the next version with the PR number and contributor attribution. Keep Markdown paragraphs on one line.

Run `bundle exec rake` before committing. Do not introduce implicit resource downloads or silently skip unavailable dictionaries. Do not publish a gem or tag a release without maintainer authorization.
