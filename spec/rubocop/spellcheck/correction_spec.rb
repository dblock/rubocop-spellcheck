# frozen_string_literal: true

RSpec.describe RuboCop::Spellcheck::Correction do
  it 'requires a unique suggestion and leaves mixed-case identifiers alone' do
    expect(described_class.new('helo', %w[hello help]).replacement).to be_nil
    expect(described_class.new('typpo', []).replacement).to be_nil
    expect(described_class.new('wRoLd', ['world']).replacement).to be_nil
  end

  it 'corrects lowercase words but leaves names and acronyms report-only' do
    expect(described_class.new('wrold', ['World']).replacement).to eq('world')
    expect(described_class.new('Wrold', ['world']).replacement).to be_nil
    expect(described_class.new('WROLD', ['world']).replacement).to be_nil
  end

  it 'accepts a single insertion, deletion, substitution, or adjacent transposition' do
    %w[helo helllo hallo].each do |word|
      expect(described_class.new(word, ['hello']).replacement).to eq('hello')
    end
    expect(described_class.new('wrold', ['world']).replacement).to eq('world')
  end

  it 'rejects distant suggestions even when unique' do
    expect(described_class.new('platformsdk', ['platform']).replacement).to be_nil
    expect(described_class.new('autocorrecton', ['correctional']).replacement).to be_nil
    expect(described_class.new('wrold', ['word']).replacement).to be_nil
  end

  it 'protects technical token components but permits ordinary sentence punctuation' do
    %w[hello.wrold wrold.hello hello_wrold hello-wrold wrold-hello].each do |text|
      expect(described_class.standalone?(text, text.index('wrold'), 5)).to be(false)
    end
    ['wrold.', '(wrold)', "'wrold'"].each do |text|
      expect(described_class.standalone?(text, text.index('wrold'), 5)).to be(true)
    end
  end

  it 'does not introduce formatting or multiple words from dictionary suggestions' do
    ['two words', '*world*', '<world>'].each do |suggestion|
      expect(described_class.new('wrold', [suggestion]).replacement).to be_nil
    end
  end

  it 'escapes apostrophes within single-quoted YAML values' do
    correction = RuboCop::Spellcheck::FrontMatter::Correction.new('isnt', ["isn't"], Psych::Nodes::Scalar::SINGLE_QUOTED)
    expect(correction.replacement).to eq("isn''t")
  end

  it 'does not change a plain YAML string into a typed value' do
    correction = RuboCop::Spellcheck::FrontMatter::Correction.new('nll', ['null'], Psych::Nodes::Scalar::PLAIN)
    expect(correction.replacement).to be_nil
    quoted = RuboCop::Spellcheck::FrontMatter::Correction.new('nll', ['null'], Psych::Nodes::Scalar::DOUBLE_QUOTED)
    expect(quoted.replacement).to eq('null')
  end
end
