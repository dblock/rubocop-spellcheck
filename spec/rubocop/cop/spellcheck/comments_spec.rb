# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Spellcheck::Comments, :config do
  let(:config) do
    RuboCop::Config.new(
      'Spellcheck' => { 'DictionaryFiles' => { 'en' => [File.expand_path('../../../fixtures/en.dic', __dir__)] } },
      'Spellcheck/Comments' => { 'Enabled' => true }
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
      # rubocop:disable Spellcheck/Comments
      # hello wrold
      # rubocop:enable Spellcheck/Comments
    RUBY
  end

  it 'reports repeated occurrences separately' do
    expect_offense(<<~RUBY)
      # wrold wrold
        ^^^^^ Misspelled word: `wrold`. Did you mean `world`?
              ^^^^^ Misspelled word: `wrold`. Did you mean `world`?
    RUBY
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
end
