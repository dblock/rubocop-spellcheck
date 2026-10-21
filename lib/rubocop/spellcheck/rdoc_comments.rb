# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Combines adjacent Ruby comment lines before parsing their RDoc structure.
    class RDocComments
      def initialize(buffer, comments)
        @buffer = buffer
        @comments = comments
      end

      def each_span(&block)
        return enum_for(__method__) unless block_given?

        groups.each do |comments|
          source, positions = comment_source(comments)
          RDoc.new(@buffer, source: source, positions: positions).each_span(&block)
        end
      end

      private

      def groups
        @comments.slice_when do |previous, current|
          current.loc.line != previous.loc.last_line + 1 || current.text.start_with?('=begin') ||
            previous.text.start_with?('=begin')
        end
      end

      def comment_source(comments)
        source = +''
        positions = []
        comments.each do |comment|
          text, offsets = mapped_comment(comment)
          source << text
          positions.concat(offsets)
          source << "\n"
          positions << [comment.source_range.end_pos, comment.source_range.end_pos]
        end
        [source, positions]
      end

      def mapped_comment(comment)
        first = comment.source_range.begin_pos
        pieces = comment.text.lines.map do |line|
          text, removed = strip_marker(line)
          offsets = positions(first + removed, text.length)
          first += line.length
          [text, offsets]
        end
        [pieces.map(&:first).join, pieces.flat_map(&:last)]
      end

      def positions(first, length)
        length.times.map { |index| [first + index, first + index + 1] }
      end

      def strip_marker(line)
        return [line.gsub(/[^\n]/, ' '), 0] if line.match?(/\A=(?:begin|end)\b/)

        marker = line[/\A# ?/].to_s.length
        [line[marker..], marker]
      end
    end
  end
end
