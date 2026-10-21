# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Spellcheck::Spelling, :config do
  let(:config) do
    RuboCop::Config.new(
      'Spellcheck' => { 'DictionaryFiles' => { 'en' => [File.expand_path('../../../fixtures/en.dic', __dir__)] } },
      'Spellcheck/Spelling' => { 'Enabled' => true }
    )
  end

  def offenses(source)
    _investigate(cop, parse_source(source)).sort.map do |offense|
      [offense.line, offense.column, offense.location.source]
    end
  end

  it 'checks strings and identifiers by default at separate Unicode-aware positions' do
    expect(offenses('wrold = "😀 wrold"')).to eq([[1, 0, 'wrold'], [1, 11, 'wrold']])
  end

  it 'splits snake case, camel case, acronym boundaries, sigils, and digits at each use' do
    source = "@hello_wrold = HelloWrold2WROLD\n@@wrold = $wrold\nhello.wrold!\n"
    expect(offenses(source)).to eq(
      [[1, 7, 'wrold'], [1, 20, 'Wrold'], [1, 26, 'WROLD'], [2, 2, 'wrold'], [2, 11, 'wrold'], [3, 6, 'wrold']]
    )
  end

  it 'checks method, class, module, constant, and keyword argument definitions' do
    source = "module Wrold\nclass WROLD\nWrold = 1\ndef self.wrold(wrold:, hello: 'world'); wrold; end\nend\nend\n"
    expect(offenses(source)).to eq(
      [[1, 7, 'Wrold'], [2, 6, 'WROLD'], [3, 0, 'Wrold'], [4, 9, 'wrold'], [4, 15, 'wrold'], [4, 40, 'wrold']]
    )
  end

  it 'does not check symbols, regular expressions, shell commands, or symbol hash keys' do
    source = "hello = [:wrold, :\"wrold \#{hello}\", %s[wrold], /wrold/, %x[wrold], `wrold`, {wrold: 1}]"
    expect(offenses(source)).to be_empty
  end

  it 'checks real Ruby expressions and string literals inside interpolation without checking symbol text' do
    source = %q(hello = "wrold #{'wrold'} #{wrold}"; :"typpo #{'wrold'}")
    expect(offenses(source).map(&:last)).to eq(%w[wrold wrold wrold wrold])
  end

  it 'retains source ranges for decoded Unicode, octal, and hexadecimal escapes' do
    source = %q(hello = "😀 wro\u006cd wro\154d wro\x6cd wro\u{006c 0064}")
    expect(offenses(source).map(&:last)).to eq(['wro\u006cd', 'wro\154d', 'wro\x6cd', 'wro\u{006c 0064}'])
  end

  it 'checks percent string arrays and squiggly heredocs without checking delimiters or indentation' do
    source = "hello = %w[wrold world]\nworld = <<~COMMENT\n  😀 wrold\n  WROLD\nCOMMENT\n"
    expect(offenses(source)).to eq([[1, 11, 'wrold'], [3, 4, 'wrold'], [4, 2, 'WROLD']])
  end

  it 'handles escaped byte sequences, single-quoted heredocs, and line continuations' do
    source = "hello = \"\\xF0\\x9F\\x98\\x80 wro\\\nld\"\nworld = <<~'COMMENT'\n  wrold\nCOMMENT\n"
    expect(offenses(source).map(&:last)).to eq(["wro\\\nld", 'wrold'])
  end

  it 'honors native suppression for strings and identifiers' do
    source = "# rubocop:disable Spellcheck/Spelling\nwrold = 'wrold'\n" \
             "# rubocop:enable Spellcheck/Spelling\nhello.wrold\n"
    expect(offenses(source)).to eq([[4, 6, 'wrold']])
  end

  it 'allows strings to be disabled without disabling identifiers or comments' do
    config['Spellcheck/Spelling']['Ruby'] = { 'Strings' => false }
    expect(offenses("wrold = 'typpo'\n# wrold\n")).to eq([[1, 0, 'wrold'], [2, 2, 'wrold']])
  end

  it 'allows identifiers to be disabled without disabling strings' do
    config['Spellcheck/Spelling']['Ruby'] = { 'Identifiers' => false }
    expect(offenses("typpo = 'wrold'\n")).to eq([[1, 9, 'wrold']])
  end

  it 'ignores addresses in string content rather than splitting their components as names' do
    expect(offenses('hello = "https://typpo.invalid user@typpo.invalid world"')).to be_empty
  end

  it 'handles literal backslashes, unknown escapes, control escapes, and binary bytes without evaluation' do
    source = %q(hello = "\xFF \cA \M-\C-a wrold"; world = %q{hello\ world}; hello = "\q wrold")
    expect(offenses(source).map(&:last)).to eq(['wrold', '\q', 'wrold'])
  end

  it 'never evaluates interpolation while inspecting literal strings' do
    source = %q(hello = "wrold #{raise 'wrold'}")
    expect(offenses(source).map(&:last)).to eq(%w[wrold raise wrold])
  end

  it 'maps literal backslashes in noninterpolating strings without absorbing adjacent letters' do
    source = "hello = %q{wrold\\q}\nworld = <<~'COMMENT'\n  \\wrold\nCOMMENT\n"
    expect(offenses(source).map(&:last)).to eq(%w[wrold q wrold])
  end

  it 'rejects nonboolean Ruby scope settings explicitly' do
    config['Spellcheck/Spelling']['Ruby'] = { 'Strings' => 'false' }
    expect { offenses("hello = 'world'") }.to raise_error(RuboCop::ValidationError, /must be true or false/)
  end
end
