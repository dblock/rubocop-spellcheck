# Contributing

Fork the repository, create a topic branch from `master`, and keep each pull request focused on one change.

## Development

```sh
bundle install
bundle exec rake
```

The default task runs RSpec and RuboCop. Unit tests use tiny local Hunspell fixtures and need no downloaded dictionaries or network access. The integration spec uses the actual bundled English dictionary with an empty, isolated Kotoshu cache and exercises the real RuboCop CLI, plugin discovery, and cache invalidation. Coverage is written to `coverage/`.

The repository enables its own `Spellcheck/Comments` cop in `.rubocop.yml`, so the default task and CI lint comments using bundled English plus `.spellcheck.txt` for project vocabulary.

Development linting also enables `rubocop-rake` and `rubocop-rspec`. `Metrics/BlockLength` is disabled.

For manual checks against a real dictionary:

```sh
bundle exec rubocop --plugin rubocop-spellcheck --only Spellcheck/Comments path/to/file.rb
```

Add focused regression specs for changed behavior, including precise offense ranges. Update README documentation and add a CHANGELOG entry under the next version with the PR number and contributor attribution. Keep Markdown paragraphs on one line.

The bundled English dictionary and its full license must ship together. See [data/en/README.md](data/en/README.md) for provenance and update instructions. DictionaryFiles maps language codes to explicit gem-relative or local Hunspell/text files, never a Kotoshu-managed resource cache.

## Resource maintenance

Run `ruby script/update_resources.rb` to update both the Kotoshu dependency to the latest stable RubyGems release and the bundled English dictionary/license to a single pinned revision of `kotoshu/dictionaries`' `v1` branch. The script needs network access, but linting and tests do not. It leaves files untouched when the upstream contents and dependency are unchanged; all downloads complete before any changes are written.

The **Update spelling resources** workflow runs monthly and supports manual dispatch. Changes are validated on the minimum supported Ruby with RSpec, RuboCop, and a gem build before [peter-evans/create-pull-request](https://github.com/peter-evans/create-pull-request) opens or refreshes one `maintenance/spelling-resources` PR. The action is pinned to an immutable release commit and manages branch updates and commits. Nothing is automatically merged. Review dictionary behavior, the complete license diff, upstream provenance, and Kotoshu compatibility before merging.

Enable **Allow GitHub Actions to create and approve pull requests** in the repository's Actions settings. By default the workflow uses `GITHUB_TOKEN`; GitHub does not trigger additional push/PR workflows for changes made with that token, so the maintenance workflow validates changes itself and links its run in the PR. To also trigger the normal PR matrix and Danger, configure a narrowly scoped `MAINTENANCE_TOKEN` secret with repository contents and pull-request write access. A token cannot bypass an organization policy that prohibits automated PR creation.

Run `bundle exec rake` before committing. Do not introduce implicit resource downloads or silently skip unavailable dictionaries. Do not publish a gem or tag a release without maintainer authorization.
