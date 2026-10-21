# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Spellcheck::Spelling, :config do
  let(:config) do
    RuboCop::Config.new(
      'Spellcheck' => { 'DictionaryFiles' => { 'en' => [File.expand_path('../../../fixtures/en.dic', __dir__)] } },
      'Spellcheck/Spelling' => { 'Enabled' => true }
    )
  end

  before do
    allow(Kotoshu::ResourceManager).to receive(:resolve).and_call_original
  end

  it 'reports exactly the misspelled word with suggestions' do
    expect_offense(<<~RUBY)
      # hello wrold
              ^^^^^ Misspelled word: `wrold`. Did you mean `world`?
    RUBY
  end

  it 'preserves offsets after multibyte characters and ignored addresses' do
    expect_offense(<<~RUBY)
      # 😀 https://example.invalid/typpo hello wrold
                                              ^^^^^ Misspelled word: `wrold`. Did you mean `world`?
    RUBY
  end

  it 'checks trailing comments but not strings or identifiers' do
    expect_offense(<<~RUBY)
      wrold = 'wrold' # hello wrold
                              ^^^^^ Misspelled word: `wrold`. Did you mean `world`?
    RUBY
  end

  it 'ignores machine directives, URLs, and email addresses' do
    expect_no_offenses(<<~RUBY)
      #!/usr/bin/env ruby
      # frozen_string_literal: true
      # encoding: utf-8
      # -*- coding: utf-8 -*-
      # typed: strict
      # rubocop:disable Layout/LineLength
      # hello https://example.invalid/typpo www.example.invalid user@example.invalid
    RUBY
  end

  it 'honors RuboCop inline suppression' do
    expect_no_offenses(<<~RUBY)
      # rubocop:disable Spellcheck/Spelling
      # hello wrold
      # rubocop:enable Spellcheck/Spelling
    RUBY
  end

  it 'reports repeated occurrences separately' do
    expect_offense(<<~RUBY)
      # wrold wrold
        ^^^^^ Misspelled word: `wrold`. Did you mean `world`?
              ^^^^^ Misspelled word: `wrold`. Did you mean `world`?
    RUBY
  end

  it 'loads dictionaries once across Ruby, Markdown, and text investigations without retaining offenses' do
    allow(RuboCop::Spellcheck::Checker).to receive(:new).and_call_original
    team = RuboCop::Cop::Team.new([cop], config)
    reports = { 'one.rb' => "# wrold\n", 'two.md' => "hello\n", 'three.txt' => "hello wrold\n" }.map do |path, source|
      team.investigate(parse_source(source, path)).offenses
    end
    expect(reports.map { |offenses| offenses.map { |offense| [offense.location.source, offense.column] } }).to eq(
      [[['wrold', 2]], [], [['wrold', 6]]]
    )
    expect(RuboCop::Spellcheck::Checker).to have_received(:new).once
  end

  it 'loads changed dictionary content for a new team rather than sharing stale verdicts' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'words.txt')
      config['Spellcheck']['DictionaryFiles'] = { 'en' => [path] }
      File.write(path, "hello\n")
      first = RuboCop::Cop::Team.mobilize([described_class], config)
      before = first.external_dependency_checksum
      expect(first.investigate(parse_source("# wrold\n")).offenses.size).to eq(1)
      File.write(path, "wrold\n")
      second = RuboCop::Cop::Team.mobilize([described_class], config)
      expect(second.external_dependency_checksum).not_to eq(before)
      expect(second.investigate(parse_source("# wrold\n")).offenses).to be_empty
    end
  end

  it 'checks block comments without checking their delimiters' do
    expect_offense(<<~RUBY)
      =begin
      hello wrold
            ^^^^^ Misspelled word: `wrold`. Did you mean `world`?
      =end
    RUBY
  end

  it 'leaves correctly spelled words and affixed forms alone' do
    expect_no_offenses("# hello world features\n")
  end

  it 'reports misspellings without suggestions when no candidates exist' do
    expect_offense(<<~RUBY)
      # zzzzzzzzzzzz
        ^^^^^^^^^^^^ Misspelled word: `zzzzzzzzzzzz`.
    RUBY
  end

  it 'does not resolve resources for files without comments' do
    expect_no_offenses("value = 'wrold'\n")
    expect(Kotoshu::ResourceManager).not_to have_received(:resolve)
  end

  it 'resolves project dictionaries relative to the effective configuration file' do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'words.txt'), "wrold\n")
      allow(config).to receive(:base_dir_for_path_parameters).and_return(dir)
      config['Spellcheck']['DictionaryFiles']['en'] << 'words.txt'
      expect_no_offenses("# hello wrold\n")
    end
  end

  it 'resolves a primary override relative to the effective configuration file' do
    root = File.expand_path('../../../fixtures', __dir__)
    allow(config).to receive(:base_dir_for_path_parameters).and_return(root)
    config['Spellcheck']['DictionaryFiles'] = { 'en' => ['en.dic'] }
    expect_no_offenses("# hello world\n")
  end

  it 'checks headings and formatted link labels with original Unicode positions' do
    offenses = markdown_offenses("# 😀 **wrold** [wrold](https://typpo.invalid)\n")
    expect(offenses.map { |offense| [offense.location.source, offense.column] }).to eq(
      [['wrold', 6], ['wrold', 15]]
    )
    expect(offenses.map(&:message).uniq).to eq(['Misspelled word: `wrold`. Did you mean `world`?'])
  end

  it 'checks lists, quotes, and table cells' do
    source = "- wrold\n\n> wrold\n\n| hello |\n| ----- |\n| wrold |\n"
    offenses = markdown_offenses(source, 'example.markdown')
    expect(offenses.map { |offense| [offense.line, offense.column, offense.location.source] }).to eq(
      [[1, 2, 'wrold'], [3, 2, 'wrold'], [7, 2, 'wrold']]
    )
  end

  it 'checks image descriptions and footnote prose but not identifiers' do
    source = "![wrold](typpo.png)\n\nhello[^typpo]\n\n[^typpo]: wrold\n"
    expect(markdown_offenses(source).map { |offense| [offense.line, offense.location.source] }).to eq(
      [[1, 'wrold'], [5, 'wrold']]
    )
  end

  it 'skips code blocks, inline code, destinations, and addresses' do
    source = <<~MARKDOWN
      hello `typpo` [world][typpo] <https://typpo.invalid> user@typpo.invalid

      [typpo]: https://typpo.invalid "typpo"

      ```ruby
      # wrold
      typpo(
      ```

          wrold
    MARKDOWN
    expect(markdown_offenses(source)).to be_empty
  end

  it 'skips front matter and HTML without treating standalone punctuation as words' do
    source = <<~MARKDOWN
      ---
      typpo: 123
      ---
      <!-- wrold -->

      <div typpo="wrold">wrold</div>

      hello <span typpo="wrold">world</span> [hello](url)'.
    MARKDOWN
    expect(markdown_offenses(source)).to be_empty
  end

  it 'maps decoded entities and escaped punctuation back to their full source ranges' do
    offenses = markdown_offenses("hello &amp; wro&#108;d \\*wrold\\*\n")
    expect(offenses.map { |offense| [offense.column, offense.location.source] }).to eq(
      [[12, 'wro&#108;d'], [25, 'wrold']]
    )
  end

  def markdown_offenses(source, path = 'example.md')
    _investigate(cop, parse_source(source, path))
  end

  it 'honors Markdown disable and enable blocks without losing Unicode source locations' do
    source = "<!-- rubocop:disable Spellcheck/Spelling -->\nwrold\n" \
             "<!-- rubocop:enable Spellcheck/Spelling -->\n😀 wrold\n"
    expect(markdown_offenses(source).map { |offense| [offense.line, offense.column] }).to eq([[4, 2]])
  end

  it 'limits trailing disable and todo directives to their own line' do
    source = "wrold <!-- rubocop:disable all -->\nwrold <!-- rubocop:todo Spellcheck/Spelling -->\nwrold\n"
    expect(markdown_offenses(source).map(&:line)).to eq([3])
  end

  it 'supports all and cop lists with reasons while ignoring unrelated directives' do
    source = "<!-- rubocop:disable Layout/LineLength, Spellcheck/Spelling -- vocabulary -->\nwrold\n" \
             "<!-- rubocop:enable all -->\nwrold\n<!-- rubocop:disable Layout/LineLength -->\nwrold\n"
    expect(markdown_offenses(source).map(&:line)).to eq([4, 6])
  end

  it 'does not interpret directives in code or Liquid as suppression' do
    source = "`<!-- rubocop:disable all -->`\n\n```\n<!-- rubocop:disable all -->\n```\n" \
             "{{ '<!-- rubocop:disable all -->' }}\n\nwrold\n"
    expect(markdown_offenses(source).map(&:line)).to eq([8])
  end

  it 'resets Markdown suppression between investigations' do
    expect(markdown_offenses("<!-- rubocop:disable all -->\nwrold\n")).to be_empty
    expect(markdown_offenses("wrold\n").map(&:line)).to eq([1])
  end

  it 'skips Liquid expressions and recognizes template-based link destinations' do
    source = "![world]({{ site.url }}/typpo.png)\n{% include typpo %} 😀 wrold\n"
    expect(markdown_offenses(source).map { |offense| [offense.line, offense.column, offense.location.source] }).to eq(
      [[2, 22, 'wrold']]
    )
  end

  it 'does not treat quote marks or formatted possessive suffixes as misspelled words' do
    expect(markdown_offenses("'hello' [world](url)'s `world`'s\n")).to be_empty
  end

  it 'checks string values without checking keys or strongly typed metadata' do
    source = "---\ntitle: 😀 wrold\ncount: 42\ndescription: 'hello wrold'\nsummary: world\n---\nhello\n"
    expect(markdown_offenses(source).map { |offense| [offense.line, offense.column, offense.location.source] }).to eq(
      [[2, 9, 'wrold'], [4, 20, 'wrold']]
    )
  end

  it 'maps quoted YAML escapes and multiline block scalars to original source ranges' do
    source = "---\ntitle: \"wro\\u006cd\"\ndescription: >-\n  hello\n  wrold\nsummary: |\n  wrold\n---\n"
    expect(markdown_offenses(source).map { |offense| [offense.line, offense.location.source] }).to eq(
      [[2, 'wro\\u006cd'], [5, 'wrold'], [7, 'wrold']]
    )
  end

  it 'checks nested mappings, arrays, anchored strings, and explicitly tagged strings' do
    source = "---\nmetadata:\n  caption: [hello, wrold]\nsummary: &text wrold\n" \
             "description: *text\nother: !!str wrold\n---\n"
    expect(markdown_offenses(source).map(&:line)).to eq([3, 4, 6])
  end

  it 'disables front matter spelling with nested Markdown configuration' do
    config['Spellcheck/Spelling']['Markdown'] = { 'FrontMatter' => { 'Enabled' => false } }
    expect(markdown_offenses("---\ntitle: wrold\n---\n")).to be_empty
  end

  it 'skips numbers, booleans, dates, timestamps, nulls, and aliases' do
    source = "---\nvalues: [42, 1.5, true, false, yes, no, null, ~, 2026-10-20, 2026-10-20T12:00:00Z]\n---\n"
    expect(markdown_offenses(source)).to be_empty
  end

  it 'reports malformed YAML front matter explicitly' do
    expect { markdown_offenses("---\ntitle: [hello\n---\n") }.to raise_error(
      RuboCop::ValidationError, /Invalid YAML front matter/
    )
  end

  it 'checks multiline plain values without checking trailing YAML comments' do
    source = "---\ntitle: hello\n  wrold # typpo\n---\n"
    expect(markdown_offenses(source).map { |offense| [offense.line, offense.location.source] }).to eq(
      [[3, 'wrold']]
    )
  end

  it 'does not deserialize application objects in front matter' do
    source = "---\ntitle: !ruby/object:Typpo {}\nlayout: !ruby/object:Typpo {}\n---\n"
    expect(markdown_offenses(source)).to be_empty
  end

  it 'checks quoted strings even when their contents resemble YAML scalar types' do
    source = "---\nvalues: ['yes', 'null', '2026-10-20', 'wrold']\n---\n"
    expect(markdown_offenses(source).map { |offense| offense.location.source }).to eq(
      %w[yes null wrold]
    )
  end

  it 'checks plain text literally, including Markdown-like code, with Unicode positions' do
    source = "😀 hello `wrold`\nhttps://typpo.invalid user@typpo.invalid\n# wrold\n"
    offenses = _investigate(cop, parse_source(source, 'example.txt'))
    expect(offenses.map { |offense| [offense.line, offense.column, offense.location.source] }).to eq(
      [[1, 9, 'wrold'], [3, 2, 'wrold']]
    )
  end

  it 'excludes bundled resources even when explicitly named as targets' do
    data = File.expand_path('../../../../data', __dir__)
    expect(cop.relevant_file?(File.join(data, 'en/en.dic'))).to be(false)
    expect(cop.relevant_file?(File.join(data, 'en/README.md'))).to be(false)
  end
end
