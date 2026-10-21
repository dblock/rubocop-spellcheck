# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Maps explicitly tagged Ruby fences back through Markdown container prefixes.
    class MarkdownRuby
      # Retains Ruby string escaping and report-only identifier corrections.
      class Span < Spellcheck::Span
        def initialize(original, text, positions)
          super(text, positions)
          @original = original
        end

        def correction(word, suggestions)
          @original.correction(word, suggestions)
        end
      end

      def initialize(markdown, node, version, config:)
        @buffer = markdown.buffer
        @node = node
        @config = config
        @directives = markdown.directives
        @parser_lines = markdown.parser_lines
        @positions = []
        @source = RuboCop::ProcessedSource.new(mapped_source, version, "#{@buffer.name}.rb")
        @source.config = RuboCop::Config.new
        @source.registry = RuboCop::Cop::Registry.global
      end

      def each_span
        return enum_for(__method__) unless block_given?
        return unless @source.valid_syntax?

        RubyCode.new(@source, config: @config).each_code_span do |span|
          yield mapped_span(span)
        end
      end

      private

      def mapped_span(span)
        positions = span.positions.map { |first, last| [@positions.fetch(first), @positions.fetch(last - 1) + 1] }
        Span.new(span, enabled_text(span, positions), positions)
      end

      def enabled_text(span, positions)
        span.text.each_char.with_index.map do |character, index|
          disabled?(span.positions[index].first, positions[index].first) ? ' ' : character
        end.join
      end

      def mapped_source
        first = @node.source_position.fetch(:start_line) + 1
        @node.string_content.lines.each_with_index.map do |line, index|
          mapped_line(line, first + index)
        end.join
      end

      def mapped_line(line, number)
        content = line.delete_suffix("\n")
        suffix = mapped_suffix(content, number)
        prefix = @parser_lines.fetch(number - 1).bytesize - suffix.bytesize
        raw = @buffer.source_line(number).byteslice(prefix..)
        indentation = content.delete_suffix(suffix)
        offset = @buffer.line_range(number).end_pos - raw.length
        map_positions(indentation, raw, offset, number)
        "#{indentation}#{raw}\n"
      end

      def mapped_suffix(content, number)
        parsed = @parser_lines.fetch(number - 1)
        suffix = parsed.end_with?(content) ? content : content.lstrip
        unless parsed.end_with?(suffix)
          raise RuboCop::ValidationError, "Cannot map Ruby fence in #{@buffer.name}:#{number}."
        end

        suffix
      end

      def map_positions(indentation, raw, offset, number)
        indentation.length.times { @positions << [offset - 1, @buffer.line_range(number).begin_pos].max }
        (raw.length + 1).times { |column| @positions << (offset + column) }
      end

      def disabled?(ruby_position, original_position)
        line = @source.buffer.decompose_position(ruby_position).first
        original_line = @buffer.decompose_position(original_position).first
        @directives.disabled?(original_line) ||
          !@source.comment_config.cop_enabled_at_line?('Spellcheck/Spelling', line)
      end
    end
  end
end
