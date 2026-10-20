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
        ProseSource.file?(path) && !markdown_preprocessor? ? false : super
      end

      private

      def parse(source, *)
        return super if !ProseSource.file?(path) || markdown_preprocessor?

        super('', *)
        @buffer = Parser::Source::Buffer.new(path, source: source)
      end

      def markdown_preprocessor?
        Markdown.file?(path) && respond_to?(:markdown_document)
      end
    end
  end
end

RuboCop::ProcessedSource.prepend(RuboCop::Spellcheck::ProseSource)
