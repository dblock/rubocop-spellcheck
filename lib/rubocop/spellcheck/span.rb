# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Associates extracted prose with its original positions and correction policy.
    class Span
      attr_reader :text, :positions

      def initialize(text, positions)
        @text = text
        @positions = positions
      end

      def correction(word, suggestions)
        Correction.new(word, suggestions)
      end

      def each_misspelling(checker, text)
        checker.misspellings(text).each do |word, position|
          next unless word.match?(/\p{L}/)

          whole = Correction.whole_word?(positions, position, word.length)
          yield word, *range(position, word.length), correction(word, checker.suggestions(word)), whole
        end
      end

      private

      def range(position, length)
        [positions.fetch(position).first, positions.fetch(position + length - 1).last]
      end
    end
  end
end
