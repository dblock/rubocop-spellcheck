# Ruby spellchecker comparison

This is an optional, offline word-API benchmark, not a change to rubocop-spellcheck's production backend or dependencies. The question is whether another Ruby-accessible checker offers a useful speed/quality tradeoff, including the exact plain-Ruby implementation discussed in [this comment](https://github.com/codenamev/get-up-offa-that-markdown/pull/2#issuecomment-6425967346).

## Reproduce

Run from the repository root with Ruby 4.0.9 and Bundler 4.0.21. The optional bundle builds Kotoshu 1.0.8 from source for the Rust comparison, requiring a Rust toolchain and native build tools. Install Aspell and a native Hunspell shared library if missing; on macOS, `brew install aspell hunspell` provides them. The measured machine already provided a Hunspell library through macOS. Aspell needs English language support and an installed `en_US` dictionary registration because the binding validates that registration even when using a custom master. Native library versions and language support files are platform prerequisites, not downloaded by the benchmark.

```sh
bundle install
BUNDLE_GEMFILE=benchmark/Gemfile bundle install
BUNDLE_GEMFILE=benchmark/Gemfile bundle exec ruby benchmark/setup.rb
BUNDLE_GEMFILE=benchmark/Gemfile bundle exec ruby benchmark/run.rb
```

Dependency installation can download gems and Rust build dependencies. After installation, only setup downloads benchmark resources: five files from an immutable upstream revision, including both source and dictionary licenses, into ignored `vendor/spellcheck-benchmark`. Every download and the local Hunspell inputs are checked against SHA-256 hashes in [resources.json](resources.json). Setup explicitly invokes `aspell create master` to compile the expanded list; it does not use the installed Aspell vocabulary. Set `ASPELL=/absolute/path/to/aspell` if necessary. The expanded list and its full license stay together; no upstream source is copied into the gem or committed here. Measured runs do not download anything.

The runner performs three serial trials per engine in fresh Ruby processes, rotating engine order between trials. `TRIALS=5` requests more trials; fewer than three is rejected. An optional output argument preserves the checked-in run, for example `ruby benchmark/run.rb benchmark/local-results.json` within the optional bundle. Stop other CPU-heavy jobs before measuring. Missing resources, missing libraries, subprocess failures, and checksum mismatches fail loudly rather than silently removing candidates. The `kotoshu_auto` case requires Kotoshu's Rust extension to be available: it fails explicitly if automatic selection falls back to Ruby, so a fallback cannot be mislabeled as a Rust result. Use the same `RUSTUP_TOOLCHAIN` during installation and measurement if your default toolchain differs.

The precompiled ARM macOS Kotoshu 1.0.8 extension loaded on Ruby 4.0.9 and reported availability, but its first actual lookup raised `TypeError: no implicit conversion of Kotoshu::Native::Dictionary into Kotoshu::Native::Dictionary`. Building the same gem from source against this Ruby fixed the failure. The optional bundle therefore requests the source platform; the production bundle is unchanged. The source manifest references `kotoshu-rs` on `main`, but the gem includes a workspace Cargo lock. The results additionally archive the resolved core Git revision, workspace Cargo lock and its checksum, and compiler version, identifying the actual native build rather than relying on the Ruby gem version alone. The build's `platform: ruby` identifies a source gem, not the selected checking engine.

The normal `bundle exec rake` runs focused harness specs and the existing suite without fetching resources or requiring the optional gems. The benchmark itself is deliberately not part of the default task.

## Candidates and research

Research checked on October 26, 2026. Gem releases are pinned in [Gemfile.lock](Gemfile.lock); release dates below are from the linked RubyGems records, not evidence of compatibility or active maintenance.

| Candidate | What is actually measured | License and evidence |
| --- | --- | --- |
| Kotoshu 1.0.8 | Raw `Kotoshu::Spellchecker` with the current offline `ruby` backend, personal dictionary disabled, bundled `.dic` and `.aff` | BSD-2-Clause; [source](https://github.com/kotoshu/kotoshu), [release](https://rubygems.org/gems/kotoshu/versions/1.0.8) |
| Kotoshu 1.0.8 auto | Same configuration and dictionary, but `backend: 'auto'`; verifies `native_backend` is selected and records the Rust engine version. Public suggestions still use the Ruby pipeline in this release. | Same gem; [automatic selection](https://github.com/kotoshu/kotoshu/blob/v1.0.8/lib/kotoshu/native_backend.rb), [actual method dispatch](https://github.com/kotoshu/kotoshu/blob/v1.0.8/lib/kotoshu/spellchecker.rb) |
| Current checker | Actual `RuboCop::Spellcheck::Checker`, including its verdict/suggestion memoization and dictionary checksum initialization | This project's MIT license; [adapter](../lib/rubocop/spellcheck/checker.rb) |
| Plain Ruby | Unmodified `Spelling` from merged upstream PR 2, revision `ab75db9b218bd6bfc7c2c303ee4ecfc282979b98`; `correct?` and `replacement` | MIT; [source](https://github.com/codenamev/get-up-offa-that-markdown/blob/ab75db9b218bd6bfc7c2c303ee4ecfc282979b98/spelling.rb), [PR](https://github.com/codenamev/get-up-offa-that-markdown/pull/2) |
| ffi-hunspell 0.6.1 | Native Hunspell through `Dictionary.new(aff_path, dic_path)`, `check?`, and `suggest`; same original dictionary | MIT binding; [API](https://github.com/postmodern/ffi-hunspell), [release February 13, 2021](https://rubygems.org/gems/ffi-hunspell/versions/0.6.1). Native Hunspell has separate licensing: [upstream](https://github.com/hunspell/hunspell). |
| ffi-aspell 1.1.0 | Native Aspell with an explicitly compiled master from the same expanded list, normal suggestion mode, empty personal/replacement dictionaries | MPL-2.0 binding; [API](https://github.com/yorickpeterse/ffi-aspell), [release May 15, 2015](https://rubygems.org/gems/ffi-aspell/versions/1.1.0). Aspell is separately LGPL: [upstream](http://aspell.net/). |
| did_you_mean 2.0.0 | `DidYouMean::SpellChecker` suggestions over the same expanded list; no lookup measurement because it has no natural-language `correct?` API | MIT; [algorithm](https://github.com/ruby/did_you_mean/blob/v2.0.0/lib/did_you_mean/spell_checker.rb), [release December 4, 2024](https://rubygems.org/gems/did_you_mean/versions/2.0.0) |

The original Kotoshu case and the production adapter explicitly select Ruby. The additional automatic case selects Kotoshu's own Rust implementation, not the native Hunspell C++ library measured separately through FFI. Worker metadata records the requested and selected backend, the available native engine version, and the suggestion pipeline. Kotoshu 1.0.8's public `correct?` dispatches to Rust when selected, but its public `suggest` still uses the Ruby generator, even with `auto`. Its optional semantic/language features are not exercised by the production configuration or this comparison. Native dependencies can still be loaded while requiring Kotoshu. The plain-Ruby implementation has no gem dependencies, but its dictionary expansion is not a general multilingual Hunspell replacement.

Other options investigated but not measured: [raspell 1.3](https://rubygems.org/gems/raspell/versions/1.3), an older Aspell option last released December 3, 2011; [spellchecker 0.1.5](https://rubygems.org/gems/spellchecker/versions/0.1.5), last released February 2, 2011 (its advertised source repository was unavailable during research); and [symspell 0.0.3](https://rubygems.org/gems/symspell/versions/0.0.3), last released August 25, 2015. The [SymSpell port's own README](https://github.com/PhilT/symspell) describes a Ruby symmetric-delete algorithm with dictionary construction, configurable edit distance and verbosity, and only basic tests; it states LGPL-3.0 licensing. These deserve separate compatibility and indexing-memory work rather than invented performance numbers. Remote spelling services are outside this offline comparison.

## Inputs and methodology

The original `.aff` and `.dic` are this project's [SCOWL-derived American English 2020.12.07 size-60 dictionary](../data/en/README.md), not an operating-system default. The upstream 123,699-word expansion and 61-word never-suggest list derive from the same files. Its [expansion tool](https://github.com/codenamev/get-up-offa-that-markdown/blob/ab75db9b218bd6bfc7c2c303ee4ecfc282979b98/tools/build_wordlist.rb) implements the prefix/suffix, cross-product and flags used by this English dictionary, excluding generated ordinal compounds (explicit numeric entries still occur in the list). Upstream reports independent spylls validation in the PR; that is their validation, not a full equivalence proof performed here.

The 1,042-word lookup corpus combines 1,000 expanded entries sampled with fixed seed `20261026`, explicit valid/invalid, casing, accented, apostrophe, inflection and compound probes, and the typo set. Duplicates are removed. The expanded samples are dictionary-consistency checks, not an independently labeled accuracy corpus. Every raw verdict is retained, and disagreements are reported without calling any engine the ground truth.

Twenty curated typo/expected-correction pairs in [the corpus](corpus.rb) cover transposition, insertion, deletion, substitution, ambiguity and title case. They are a small diagnostic set, not a balanced natural-language evaluation. Suggestions are measured for every pair, even if a backend accepts the input. Coverage counts nonempty answers; top-1 and top-3 count exact expected matches out of all 20, including abstentions as misses. Expected words and every suggestion are recorded so alternatives can be inspected rather than scored invisibly.

Initialization includes requiring the engine adapter and its backend, dictionary loading and object creation, but excludes interpreter/Bundler startup, corpus loading, checksum verification and full RuboCop boot. Ruby's automatic did_you_mean loading is disabled in workers so its explicit require is measured. No claim about end-to-end lint speed follows from these timings.

Cold means the first batch of distinct words in that new engine instance, not a cold operating-system filesystem cache. Warm lookup repeats the identical ordered corpus ten times; warm suggestions repeat the 20 typos once. Engine caches are preserved, not cleared or emulated. Both the production wrapper and plain Ruby memoize answers; the latter clears its caches at 4,096 entries, above this corpus size. Other engines retain any internal caching they normally implement. Batch timing uses the monotonic clock and excludes JSON serialization. Reported per-word values are medians of trial batch times divided by their operation counts, not percentiles of individual word latency.

Kotoshu requests three suggestions. Native Hunspell, Aspell and did_you_mean generate their normal candidate lists, then the adapter retains three; their full generation cost is still timed. Plain Ruby deliberately returns zero or one correction, preferring unique swapped/doubled-letter candidates, then unique one-edit candidates. It is not a ranked top-three engine. Aspell's compiled flat list loses Hunspell affix, case and never-suggest semantics and uses Aspell's installed English language rules. Setup audits the compiled dictionary with `aspell dump master`: this installation retains 123,679 entries, omitting exactly 20 numeric forms (`0` through `9` and their ordinal forms) and adding none. The omissions and compiler output are recorded, not silently treated as an identical dictionary. did_you_mean also has no Hunspell case/never-suggest handling and normalizes for identifier-like similarity rather than prose correction. Neither is a semantic drop-in replacement.

## Results

See [results.json](results.json) for raw trials, all word verdicts/suggestions, engine versions, checksums, environment, operation counts, output stability and disagreements. Results and recommendations below describe one shared machine, not universal timings.

Measured October 26, 2026 on Apple M3 Pro, macOS 26.6.2/Darwin 25.6.0, Ruby 4.0.9, with three trials for all seven engines (21 fresh subprocesses). Kotoshu was source-built with `RUSTUP_TOOLCHAIN=stable-aarch64-apple-darwin`, `rustc` 1.99.1 (`58cf8f9c3`, October 13, 2026). Every automatic trial confirmed selection of native engine 0.2.3, core revision `ee2079a807690d594bb06a46d96f97724d466663`. Aspell was Homebrew 0.60.8.1 (`libaspell.dylib`); Hunspell resolved to the macOS `libhunspell-1.2.dylib` ABI, not a newly installed Hunspell 1.7. The library's exact semantic release is not identified, so reproduce that native comparison on the same OS build or clearly record a different library. Worker diagnostics and native build provenance are retained. Do not generalize these numbers to other native builds.

Median per-word times, with initialization measured once per fresh instance:

| Engine | Initialization (ms) | Cold lookup (microseconds) | Warm lookup (microseconds) | Cold suggestions (ms) | Warm suggestions (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Kotoshu Ruby | 264.93 | 100.907 | 14.874 | 526.776 | 407.090 |
| Kotoshu auto (Rust lookup) | 252.53 | 3.110 | 1.918 | 545.462 | 396.762 |
| Current checker | 245.16 | 93.419 | 0.122 | 706.349 | 0.00020 |
| Plain Ruby | 74.66 | 0.850 | 0.127 | 0.331 | 0.00015 |
| Native Hunspell | 25.12 | 0.709 | 0.436 | 5.360 | 5.398 |
| Native Aspell | 32.45 | 1.147 | 1.283 | 0.207 | 0.193 |
| did_you_mean | 11.97 | Not supported | Not supported | 342.614 | 333.013 |

Each cold lookup batch has 1,042 operations, each warm lookup batch 10,420, and each suggestion batch 20. The very small cached suggestion batches are dominated by clock/loop/allocation overhead; their sub-microsecond per-word values should not be used to rank implementations.

Variation is visible in the raw trials: Kotoshu Ruby initialization ranged from 210 to 269 ms, native Hunspell initialization from 24 to 31 ms, and plain-Ruby cold suggestions from 0.108 to 0.336 ms/word. Shared-machine load and garbage collection were not isolated; small differences should not be treated as definitive rankings.

| Engine | Answer coverage | Expected first suggestion | Expected within first three |
| --- | ---: | ---: | ---: |
| Kotoshu Ruby / auto / current checker | 20/20 | 18/20 | 20/20 |
| Plain Ruby | 17/20 | 17/20 | 17/20 |
| Native Hunspell | 20/20 | 14/20 | 19/20 |
| Native Aspell | 20/20 | 18/20 | 20/20 |
| did_you_mean | 20/20 | 14/20 | 18/20 |

All six lookup-capable engines, including the verified Rust backend, agreed on all 1,042 words in this run, and all outputs were stable across trials. Kotoshu Ruby and automatic Rust selection returned exactly the same suggestion arrays. That includes rejecting accented probes such as `café` and `naïve`: agreement is not proof that the chosen dictionary covers every real English word, nor proof of full Hunspell equivalence.

Plain Ruby abstained on `brwn`, `grammer`, and `wierd` and returned the expected correction on its other 17 answers. Kotoshu ranked `Crammer` before `grammar` and `wired` before `weird`; the harness measures suggestions, not whether the cop would permit their autocorrection. Aspell ranked `Brown` before `brown` and `crammer` before `grammar`. Native Hunspell did not include `hello` in its first three answers for `helo`. did_you_mean's `Thier` answer was lowercase `their`, which intentionally misses the exact-case expected `Their`.

## Recommendation

Keep production unchanged in this branch. A replacement must preserve multilingual dictionary selection, supplemental `.txt` vocabulary, external-file cache invalidation, case handling, never-suggest rules, and the cop's guarded correction behavior. Speed alone is not enough to replace the adapter, and word-API measurements do not evaluate Markdown parsing or original-source offsets.

On this diagnostic workload, plain Ruby is an attractive dependency-free English path: roughly 119 times faster first lookup than raw Kotoshu Ruby and about 2,130 times faster first suggestion than the current wrapper, with 85% answer coverage and no wrong first answers among those 17. Those ratios compare different suggestion policies, not equal algorithms or guaranteed correction safety. Production memoization already makes repeated lookups and suggestions comparable to plain Ruby; the opportunity is primarily startup and unseen words.

Automatic Rust selection improved raw Kotoshu cold lookup by about 32 times and warm lookup by about 7.8 times, without changing this corpus's verdicts or suggestions. It did not accelerate suggestions: those still use the same Ruby pipeline, and their measured variation is not evidence of a Rust suggestion speedup or slowdown. The production wrapper's cached warm lookup remains faster than raw Rust calls. Automatic selection is worth evaluating for previously unseen words, but the precompiled extension failure, source-build prerequisites, supplemental dictionaries, and end-to-end lint behavior need consideration before changing the production default.

Native Hunspell is a useful next candidate when retaining general Hunspell semantics matters, but its native deployment cost, library revision and lower first-suggestion score here need evaluation. Aspell performed well on this small typo set, but the old binding, differing language rules, lost never-suggest flags and omitted numeric forms rule out an unqualified replacement recommendation. did_you_mean is a useful standard-library baseline, not a competitive full prose checker over this 123,699-entry dictionary.

The author's [original comment](https://github.com/codenamev/get-up-offa-that-markdown/pull/2#issuecomment-6425967346) reports 58 versus 148 ms startup, approximately 34 times faster lookup, and 0.1 ms versus 0.4–1.4 seconds correction on Ruby 4.0.7/M5 Max. It also reports identical flagged words on that author's corpus and notes the version 1.2.1 document-offset fix. Those are attributed upstream results, not measurements made by this harness. Different corpus sizes, caches, Ruby versions and machines prevent a direct replication claim.
