# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Selects YAML values by exact dotted paths, including selected descendants.
    class FrontMatterPaths
      def initialize(config)
        @include = paths(config.fetch('Include', nil), 'Include', nullable: true)
        @exclude = paths(config.fetch('Exclude', []), 'Exclude')
      end

      def include?(path)
        (@include.nil? || matches?(@include, path)) && !matches?(@exclude, path)
      end

      private

      def paths(value, setting, nullable: false)
        return if nullable && value.nil?
        return value.map { |path| path.split('.') } if valid?(value)

        raise RuboCop::ValidationError,
              "Spellcheck/Spelling Markdown.FrontMatter.#{setting} must be a list of nonempty dotted paths."
      end

      def valid?(value)
        value.is_a?(Array) && value.all? do |path|
          path.is_a?(String) && !path.empty? && path.split('.', -1).none?(&:empty?)
        end
      end

      def matches?(patterns, path)
        patterns.any? { |pattern| path.first(pattern.length) == pattern }
      end
    end
  end
end
