# frozen_string_literal: true

require 'kotoshu/algorithms/edit_distance'

module RuboCop
  module Spellcheck
    # Restricts unsafe corrections to unambiguous, single-edit lowercase typos.
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
        return unless @suggestions.one? && @word == @word.downcase

        suggestion = @suggestions.first.downcase
        return unless WORD.match?(suggestion)

        suggestion if Kotoshu::Algorithms::EditDistance.distance_with_threshold(@word, suggestion, 1) == 1
      end

      def replacement_in(source, first, last)
        replacement if Correction.standalone?(source, first, last - first)
      end

      def message
        message = "Misspelled word: `#{@word}`."
        return message if @suggestions.empty?

        "#{message} Did you mean #{@suggestions.map { |suggestion| "`#{suggestion}`" }.join(', ')}?"
      end
    end
  end
end
