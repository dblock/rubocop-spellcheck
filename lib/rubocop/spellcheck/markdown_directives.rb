# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Recognizes spelling directives only in Markdown HTML comment nodes.
    class MarkdownDirectives
      COMMENT = /<!--(.*?)-->/m
      DIRECTIVE = /\A\s*rubocop:(disable|enable|todo)\s+(.+?)\s*\z/m

      def initialize(buffer, document)
        @buffer = buffer
        @lines = buffer.source.lines
        @disabled = Set.new
        events = document.walk.filter_map { |node| comment_event(node) }.flatten(1).sort_by(&:first)
        collect_lines(events)
      end

      def mask(raw, first)
        line = @buffer.decompose_position(first).first
        raw.lines.map.with_index do |text, index|
          @disabled.include?(line + index) ? text.gsub(/[^\n]/, ' ') : text
        end.join
      end

      private

      def comment_event(node)
        return unless %i[html_inline html_block].include?(node.type)

        raw, first = node_source(node)
        return unless raw.gsub(COMMENT, '').strip.empty?

        raw.to_enum(:scan, COMMENT).filter_map { event(Regexp.last_match, first) }
      end

      def node_source(node)
        location = node.source_position
        first = position(location.fetch(:start_line), location.fetch(:start_column) - 1)
        last = position(location.fetch(:end_line), location.fetch(:end_column))
        [@buffer.source[first...last], first]
      end

      def event(match, first)
        directive = DIRECTIVE.match(match[1])
        return unless directive && relevant?(directive[2])

        line, column = @buffer.decompose_position(first + match.begin(0))
        prefix = @lines.fetch(line - 1)[0...column]
        [line, directive[1], !prefix.strip.empty?]
      end

      def position(line, column)
        @buffer.line_range(line).begin_pos + @lines.fetch(line - 1).byteslice(0, column).length
      end

      def relevant?(names)
        names.split(/\s*--\s*/, 2).first.split(/[,\s]+/).intersect?(%w[all Spellcheck/Spelling])
      end

      def collect_lines(events)
        events = events.group_by(&:first)
        @lines.each_index do |index|
          line = index + 1
          @disabled << line if @block_disabled
          events.fetch(line, []).each { |event| apply_event(*event) }
        end
      end

      def apply_event(line, action, inline)
        if inline || action == 'todo'
          @disabled << line unless action == 'enable'
        else
          @block_disabled = action == 'disable'
          @disabled << line if @block_disabled
        end
      end
    end
  end
end
