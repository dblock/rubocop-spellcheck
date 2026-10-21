# frozen_string_literal: true

require 'kotoshu/algorithms/edit_distance'

module RuboCop
  module Spellcheck
    # Restricts unsafe corrections to single-edit lowercase and title-case typos.
    class Correction
      WORD = /\A[\p{L}\p{M}]+(?:['’][\p{L}\p{M}]+)*\z/

      def self.standalone?(text, position, length)
        before = text[0...position]
        after = text[(position + length)..]
        !before.match?(/[\p{L}\p{M}\p{N}_](?:[.-])?\z/) &&
          !after.match?(/\A(?:[.-])?[\p{L}\p{M}\p{N}_]/)
      end

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
        replacement_word
      end

      def replacement_word
        return if @suggestions.empty? || !correctable_case?

        suggestion = @suggestions.first.downcase
        return unless WORD.match?(suggestion)

        return unless Kotoshu::Algorithms::EditDistance.distance_with_threshold(@word.downcase, suggestion, 1) == 1

        @word == @word.downcase ? suggestion : suggestion.capitalize
      end

      def replacement_in(source, first, last, checker:)
        word = replacement_word
        return unless word && checker.correct?(word)

        replacement if Correction.standalone?(source, first, last - first)
      end

      def message
        message = "Misspelled word: `#{@word}`."
        return message if @suggestions.empty?

        "#{message} Did you mean #{@suggestions.map { |suggestion| "`#{suggestion}`" }.join(', ')}?"
      end

      private

      def correctable_case?
        @word == @word.downcase || (@word == @word.capitalize && @word != @word.upcase)
      end
    end
  end
end
