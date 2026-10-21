# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Cell line numbers can repeat in CSV tables; locate cells in source order within their table.
    class AsciiDocTable
      def initialize(buffer, table)
        @buffer = buffer
        @cursor = buffer.line_range(table.source_location.lineno).end_pos + 1
        @last = table_end(table)
      end

      def span(cell)
        match = locate(cell.source)
        first = @cursor + match.begin(0)
        @cursor += match.end(0)
        positions = match[0].length.times.map { |index| [first + index, first + index + 1] }
        AsciiDocInline.new(match[0], positions).span
      end

      private

      def table_end(table)
        lines = @buffer.source_lines
        line = table.source_location.lineno
        delimiter = lines.fetch(line - 1)
        last = (line...lines.length).find { |index| lines[index] == delimiter }
        last ? @buffer.line_range(last + 1).begin_pos : @buffer.source.length
      end

      def locate(text)
        match = pattern(text).match(@buffer.source[@cursor...@last])
        return match if match

        raise RuboCop::ValidationError, "Cannot map AsciiDoc table cell in #{@buffer.name}: #{text.inspect}"
      end

      def pattern(text)
        Regexp.new(text.each_char.map do |character|
          case character
          when '|' then /\\?\|/.source
          when '"' then /"{1,2}/.source
          else Regexp.escape(character)
          end
        end.join)
      end
    end
  end
end
