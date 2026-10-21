# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Splits Ruby names without treating symbols, keywords, or operators as identifiers.
    class RubyIdentifiers
      # Identifier occurrences cannot be renamed independently of their references.
      class Span < Spellcheck::Span
        def correction(word, suggestions)
          Correction.new(word, suggestions)
        end
      end

      # Keeps diagnostics and suggestions without offering identifier replacements.
      class Correction < Spellcheck::Correction
        def replacement; end
      end

      TYPES = %i[tIDENTIFIER tFID tCONSTANT tIVAR tCVAR tGVAR].freeze
      BOUNDARY = /(?<=\p{Ll})(?=\p{Lu})|(?<=\p{Lu})(?=\p{Lu}\p{Ll})/

      def initialize(source)
        @source = source
        @parameters = source.ast.each_node(:kwarg, :kwoptarg).to_set { |node| node.loc.name.begin_pos }
        @tokens = source.tokens.select { |token| identifier?(token) }
      end

      def each_span(&block)
        return enum_for(__method__) unless block_given?

        @tokens.each do |token|
          token.text.to_enum(:scan, /[\p{L}\p{M}]+/).each do
            match = Regexp.last_match
            split(match[0], token.pos.begin_pos + match.begin(0), &block)
          end
        end
      end

      private

      def identifier?(token)
        TYPES.include?(token.type) || (token.type == :tLABEL && @parameters.include?(token.pos.begin_pos))
      end

      def split(name, first)
        name.split(BOUNDARY).each do |word|
          positions = word.length.times.map { |index| [first + index, first + index + 1] }
          yield Span.new(word, positions)
          first += word.length
        end
      end
    end
  end
end
