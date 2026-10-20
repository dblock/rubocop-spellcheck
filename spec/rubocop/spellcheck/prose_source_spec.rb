# frozen_string_literal: true

RSpec.describe RuboCop::Spellcheck::ProseSource do
  it 'preserves the original Markdown buffer' do
    source = "# hello **world**\n\n```ruby\nvalue = 1\n```\n"
    processed = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, 'example.md')

    expect(processed.buffer.source).to eq(source)
  end

  it 'passes Markdown unchanged to an existing document provider' do
    provider = Class.new do
      prepend RuboCop::Spellcheck::ProseSource

      attr_reader :markdown_document

      def path
        'example.md'
      end

      def parse(source)
        source
      end
    end
    source = "# hello **world**\n\n```ruby\nvalue = 1\n```\n"

    expect(provider.new.send(:parse, source)).to equal(source)
  end
end
