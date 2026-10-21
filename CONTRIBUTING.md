# Contributing

Fork the repository, create a topic branch from `master`, and keep each pull request focused on one change.

## Development

```sh
bundle install
bundle exec rake
```

The default task runs RSpec and RuboCop without network access. Tests use local fixtures and the bundled dictionary; CLI integration covers plugin loading, corrections, vocabulary generation, and caching. Coverage is written to `coverage/`.

Add focused regression specs with precise offense ranges. Autocorrection fixtures pair `input` and `expected` files; CLI tests use temporary copies. Intentional spelling fixtures are excluded from repository lint.

Repository lint checks comments and documentation using `.spellcheck.txt`; Ruby strings and identifiers are disabled for this repository, though enabled by default for users. CI tests minimum Ruby 3.2 and latest Ruby 4.0, including minimum-supported RuboCop 1.72.1 on Ruby 3.2.

For manual checks against a real dictionary:

```sh
bundle exec rubocop --plugin rubocop-spellcheck --only Spellcheck/Spelling path/to/file.rb
```

Update relevant README documentation and add a CHANGELOG entry under the next version with the PR number and contributor attribution. Keep Markdown paragraphs on one line.

The bundled English dictionary and its full license must ship together. See [data/en/README.md](data/en/README.md) for provenance.

## Resource maintenance

Run `ruby script/update_resources.rb` to update Kotoshu and the bundled dictionary/license. This requires network access; linting and tests do not.

The **Update spelling resources** workflow runs monthly or on manual dispatch. It validates changes on minimum Ruby and opens or updates `maintenance/spelling-resources`. Nothing is automatically merged. Review dictionary behavior, license changes, provenance, and Kotoshu compatibility.

Enable **Allow GitHub Actions to create and approve pull requests** in Actions settings. The default `GITHUB_TOKEN` does not trigger downstream CI, so the maintenance workflow validates changes itself. To trigger normal PR checks too, configure `MAINTENANCE_TOKEN` with repository contents and pull-request write access.

Run `bundle exec rake` before committing. Do not introduce implicit resource downloads or silently skip unavailable dictionaries. Do not publish a gem or tag a release without maintainer authorization.
