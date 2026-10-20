# Releasing rubocop-spellcheck

Release only with explicit maintainer authorization. Release preparation happens on `master`; never force-push `master`.

## Prepare

Check the latest **Update spelling resources** workflow and any open maintenance PR. Optionally dispatch the workflow before a release, then review and merge its dictionary/license and Kotoshu updates if desired. Never fetch or update resources implicitly during the release or gem build: package the exact reviewed files and dependency declaration already committed.

Update `master` with a fast-forward pull. Run `bundle exec rake` and confirm the latest GitHub Actions checks pass. Set the release version in `lib/rubocop/spellcheck/version.rb`, date its CHANGELOG heading as `YYYY/MM/DD`, and remove the contribution placeholder from that release.

Commit and push the preparation changes, wait for green CI, then build and inspect the package:

```sh
bundle exec rake build
gem specification pkg/rubocop-spellcheck-0.1.0.gem files
```

Confirm the package contains only runtime code, defaults, README, CHANGELOG, license, and the bundled English dictionary with its full license and provenance.

## Publish

Publish the exact inspected package. Enter a fresh RubyGems MFA code when prompted; never put credentials or codes in source, logs, or documentation.

```sh
gem push pkg/rubocop-spellcheck-0.1.0.gem
```

Verify that exact version on RubyGems before creating and pushing an annotated `v0.1.0` tag at the release commit. Create a GitHub release with the matching changelog notes. Do not move an existing release tag.

## Next development iteration

Bump the gem version, add a matching `(Next)` CHANGELOG section with `* Your contribution here.`, then commit and push to `master`.
