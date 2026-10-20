# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Markdown uses the non-Ruby callback, with an untouched source buffer.
    module MarkdownSource
      def valid_syntax?
        Markdown.file?(path) ? false : super
      end

      private

      def parse(source, *)
        return super unless Markdown.file?(path)

        super('', *)
        @buffer = Parser::Source::Buffer.new(path, source: source)
      end
    end
  end
end

RuboCop::ProcessedSource.prepend(RuboCop::Spellcheck::MarkdownSource)
