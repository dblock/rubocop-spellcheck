# frozen_string_literal: true

RSpec.describe RuboCop::Spellcheck::Correction do
  it 'requires a unique suggestion and leaves mixed-case identifiers alone' do
    expect(described_class.new('helo', %w[hello help]).replacement).to be_nil
    expect(described_class.new('typpo', []).replacement).to be_nil
    expect(described_class.new('wRoLd', ['world']).replacement).to be_nil
  end

  it 'preserves lowercase, title case, and uppercase' do
    expect(described_class.new('wrold', ['World']).replacement).to eq('world')
    expect(described_class.new('Wrold', ['world']).replacement).to eq('World')
    expect(described_class.new('WROLD', ['world']).replacement).to eq('WORLD')
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
