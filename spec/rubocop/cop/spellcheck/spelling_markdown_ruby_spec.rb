# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Spellcheck::Spelling, :config do
  let(:config) do
    RuboCop::Config.new(
      'Spellcheck' => { 'DictionaryFiles' => { 'en' => [File.expand_path('../../../fixtures/en.dic', __dir__)] } },
      'Spellcheck/Spelling' => { 'Enabled' => true, 'Ruby' => { 'Identifiers' => true } }
    )
  end

  it 'checks fenced strings but not identifiers by default' do
    config['Spellcheck/Spelling'].delete('Ruby')
    expect(offenses("```ruby\nwrold = 'wrold'\n```\n")).to eq([[2, 9, 'wrold']])
  end

  it 'ignores implicit filename strings inside Ruby fences without skipping literal strings' do
    expect(offenses("```ruby\nhello = __FILE__; world = 'wrold'\n```\n")).to eq([[2, 27, 'wrold']])
  end

  def offenses(source)
    _investigate(cop, parse_source(source, 'example.md')).sort.map do |offense|
      [offense.line, offense.column, offense.location.source]
    end
  end

  it 'checks only explicitly tagged Ruby fences, including metadata and tilde fences' do
    source = "```ruby example\nwrold = 'wrold'\n```\n\n~~~ruby\nhello.wrold\n~~~\n" \
             "\n```\nwrold = 'wrold'\n```\n\n```python\nwrold = 'wrold'\n```\n\n    wrold = 'wrold'\n"
    expect(offenses(source)).to eq([[2, 0, 'wrold'], [2, 9, 'wrold'], [6, 6, 'wrold']])
  end

  it 'maps nested code, Unicode, escape sequences, and interpolation to original Markdown' do
    source = "😀 hello\n\n> ```ruby\n> wrold = \"😀 wro\\u006cd \#{wrold}\"\n> ```\n\n" \
             "- hello\n\n  ````ruby\n  helloWrold = %w[wrold]\n  ````\n"
    expect(offenses(source)).to eq(
      [[4, 2, 'wrold'], [4, 13, 'wro\u006cd'], [4, 26, 'wrold'], [10, 7, 'Wrold'], [10, 18, 'wrold']]
    )
  end

  it 'honors Markdown blocks and native Ruby suppression without leaking between fences' do
    source = "<!-- rubocop:disable Spellcheck/Spelling -->\n```ruby\nwrold = 'wrold'\n```\n" \
             "<!-- rubocop:enable Spellcheck/Spelling -->\n```ruby\n" \
             "# rubocop:disable Spellcheck/Spelling\nwrold = 'wrold'\n```\n" \
             "```ruby\nhello = 'wrold' # rubocop:todo Spellcheck/Spelling\nhello.wrold\n```\n"
    expect(offenses(source)).to eq([[12, 6, 'wrold']])
  end

  it 'respects Ruby scope settings and leaves comments, symbols, regexps, and command text excluded' do
    config['Spellcheck/Spelling']['Ruby'] = { 'Identifiers' => false }
    source = "```ruby\n# typpo\nwrold = ['wrold', :typpo, /typpo/, `typpo`]\n```\n"
    expect(offenses(source)).to eq([[3, 10, 'wrold']])
  end

  it 'disables string checks independently and does not execute embedded expressions' do
    config['Spellcheck/Spelling']['Ruby'] = { 'Strings' => false, 'Identifiers' => true }
    expect(offenses("```ruby\nwrold = \"typpo \#{raise 'typpo'}\"\n```\n"))
      .to eq([[2, 0, 'wrold'], [2, 17, 'raise']])
  end

  it 'ignores incomplete Ruby snippets and does not extract fences inside other code or HTML' do
    source = "```ruby\nhello = (\n```\n\n````markdown\n```ruby\nwrold = 'wrold'\n```\n````\n\n" \
             "<div>\n```ruby\nwrold = 'wrold'\n```\n</div>\n"
    expect(offenses(source)).to be_empty
  end

  it 'restores literal Liquid text and maps partial-tab indentation using original characters' do
    source = "  ```ruby\n\thello = \"{{ '😀' }} wrold\"\n  ```\n"
    expect(offenses(source)).to eq([[2, 20, 'wrold']])
  end
end
