# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Restricts unsafe corrections to unambiguous words with reproducible casing.
    class Correction
      WORD = /\A[\p{L}\p{M}]+(?:['’][\p{L}\p{M}]+)*\z/

      def self.whole_word?(positions, position, length)
        first = positions.fetch(position).first
        last = positions.fetch(position + length - 1).last
        (position.zero? || positions[position - 1].last <= first) &&
          (position + length == positions.length || positions[position + length].first >= last)
      end

      def initialize(word, suggestions)
        @word = word
        @suggestions = suggestions
      end

      def replacement
        return unless @suggestions.one?

        suggestion = @suggestions.first
        return unless WORD.match?(suggestion)

        suggestion = capitalized(suggestion)
        suggestion if suggestion && suggestion != @word
      end

      def message
        message = "Misspelled word: `#{@word}`."
        return message if @suggestions.empty?

        "#{message} Did you mean #{@suggestions.map { |suggestion| "`#{suggestion}`" }.join(', ')}?"
      end

      private

      def capitalized(suggestion)
        if @word == @word.downcase
          suggestion.downcase
        elsif @word == @word.upcase
          suggestion.upcase
        elsif @word == @word.capitalize
          suggestion.capitalize
        end
      end
    end
  end
end
