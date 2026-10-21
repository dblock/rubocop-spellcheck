# frozen_string_literal: true

require 'yaml'

module RuboCop
  module Spellcheck
    # Updates only the generated dictionary setting, preserving surrounding configuration.
    class VocabularyConfig
      COP = 'Spellcheck/Spelling'

      def initialize(path, section:)
        @path = path
        @section = section
        @source = File.read(path, encoding: 'UTF-8')
        @root = Psych.parse(@source)&.root
      rescue Psych::SyntaxError => e
        raise RuboCop::ValidationError, "Cannot update spelling configuration #{@path}: #{e.message}"
      end

      def updated(dictionaries)
        setting = YAML.dump('DictionaryFiles' => dictionaries).delete_prefix("---\n")
        cop = value_for(@root, @section)
        return append("#{@section}:\n#{indent(setting)}") unless cop

        unless cop.is_a?(Psych::Nodes::Mapping) && cop.style == Psych::Nodes::Mapping::BLOCK
          raise RuboCop::ValidationError, "Cannot generate spelling vocabulary for non-block #{@section} in #{@path}."
        end

        replace_setting(cop, setting)
      end

      private

      def value_for(mapping, key)
        return unless mapping.is_a?(Psych::Nodes::Mapping)

        mapping.children.each_slice(2).find { |name, _value| name.value == key }&.last
      end

      def indent(text, width = 2)
        text.lines.map { |line| "#{' ' * width}#{line}" }.join
      end

      def append(text)
        if @root && @source.lines[@root.end_line]&.match?(/\A\.\.\.(?:\s|#|\z)/)
          return @source.lines.insert(@root.end_line, "\n#{text}").join
        end

        "#{@source.rstrip}\n\n#{text}"
      end

      def replace_setting(cop, setting)
        lines = @source.lines
        pair = cop.children.each_slice(2).find { |key, _value| key.value == 'DictionaryFiles' }
        if pair
          replace_pair(lines, pair, setting)
        else
          first = cop.children.first
          lines.insert(first.start_line, indent(setting, first.start_column))
        end
        lines.join
      end

      def replace_pair(lines, pair, setting)
        key, value = pair
        prefix = lines[value.end_line]&.slice(0, value.end_column)
        last = value.end_line + (prefix && !prefix.strip.empty? ? 1 : 0)
        lines[key.start_line...last] = [indent(setting, key.start_column)]
      end
    end
  end
end
