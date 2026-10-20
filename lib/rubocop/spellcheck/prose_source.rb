# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Prose files use the non-Ruby callback, with an untouched source buffer.
    module ProseSource
      def self.file?(path)
        Markdown.file?(path) || text_file?(path)
      end

      def self.text_file?(path)
        path && File.extname(path).downcase == '.txt'
      end

      def valid_syntax?
        ProseSource.file?(path) ? false : super
      end

      private

      def parse(source, *)
        return super unless ProseSource.file?(path)

        super('', *)
        @buffer = Parser::Source::Buffer.new(path, source: source)
      end
    end
  end
end

RuboCop::ProcessedSource.prepend(RuboCop::Spellcheck::ProseSource)
