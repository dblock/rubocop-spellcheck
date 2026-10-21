# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Applies independent Ruby scope settings to source-aware extractors.
    class RubyCode
      DIRECTIVE = /
        \A\#\s*(?:!|(?:rubocop|standard|coding|encoding|frozen_string_literal|
        warn_indent|shareable_constant_value|typed)\s*:)|\A\#.*-\*-\s*(?:coding|encoding):
      /x

      def initialize(source, config: {})
        valid = config.is_a?(Hash) &&
                %w[Strings Identifiers].all? { |key| [true, false].include?(config.fetch(key, true)) }
        unless valid
          raise RuboCop::ValidationError, 'Spellcheck/Spelling Ruby Strings and Identifiers must be true or false.'
        end

        @source = source
        @config = config
      end

      def each_span(&)
        comments = @source.comments.reject { |comment| DIRECTIVE.match?(comment.text) }
        RDocComments.new(@source.buffer, comments).each_span(&)
        each_code_span(&)
      end

      def each_code_span(&)
        return unless @source.ast

        RubyStrings.new(@source).each_span(&) if @config.fetch('Strings', true)
        RubyIdentifiers.new(@source).each_span(&) if @config.fetch('Identifiers', false)
      end
    end
  end
end
