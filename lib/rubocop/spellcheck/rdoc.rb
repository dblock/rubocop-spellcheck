# frozen_string_literal: true

require 'rdoc'
require 'rdoc/markup'
require 'rdoc/markup/inline_parser'

module RuboCop
  module Spellcheck
    # Reads RDoc prose without checking verbatim examples or inline code.
    class RDoc
      # Records the original tokens consumed by paragraph and heading parsing.
      class Parser < ::RDoc::Markup::Parser
        attr_reader :prose

        def initialize
          super
          @prose = {}
        end

        def build_paragraph(margin)
          @margin = margin
          super
        ensure
          @margin = nil
        end

        def build_heading(level)
          @heading = true
          super
        ensure
          @heading = false
        end

        def get
          token = super
          type, text, column, line = token
          @prose[[line, column]] = text.dup if type == :TEXT && (@heading || column == @margin)
          token
        end
      end

      # Uses consumed inline token ranges to retain original source positions.
      class Inline < ::RDoc::Markup::InlineParser
        def initialize(source)
          super
          @source = source
          @masked = source.dup
        end

        def prose
          parse
          @masked.gsub(/(?:link:|rdoc-(?:ref|label|image):)\S+/) { |link| ' ' * link.length }
        end

        private

        def scan_token
          first = @scanner.pos
          result = super
          raw = @source.byteslice(first...@scanner.pos)
          offset = @source.byteslice(0...first).length
          mask_token(result, raw, offset)
          result
        end

        def mask_token(result, raw, offset)
          type, _token, node = result
          case type
          when :node
            mask_node(node, raw, offset)
          when :open, :close, :tidylink_open, :tidylink_close, :invalidated_tidylink_close
            mask(offset, raw.length)
          end
        end

        def mask_node(node, raw, offset)
          return mask(offset, raw.length) if %i[TT HARD_BREAK].include?(node[:type])

          text = node[:children].join
          first = raw.index(text)
          mask(offset, first)
          mask(offset + first + text.length, raw.length - first - text.length)
        end

        def mask(first, length)
          @masked[first, length] = @masked[first, length].gsub(/[^\n]/, ' ')
        end
      end

      def self.file?(path)
        path && File.extname(path).casecmp?('.rdoc')
      end

      def initialize(buffer, source: buffer.source, positions: nil)
        @buffer = buffer
        @source = source
        @positions = positions || source.length.times.map { |index| [index, index + 1] }
      end

      def each_span
        return enum_for(__method__) unless block_given?

        yield Span.new(Inline.new(prose_source).prose, @positions)
      rescue ::RDoc::Markup::Parser::ParseError => e
        raise RuboCop::ValidationError, "Invalid RDoc in #{@buffer.name}: #{e.message}"
      end

      private

      def prose_source
        source = @source.gsub(/[^\n]/, ' ')
        offsets = line_offsets
        prose.each do |(line, column), text|
          source[offsets.fetch(line) + column, text.length] = text
        end
        source
      end

      def prose
        parser = Parser.new
        parser.tokenize(mask_directives)
        parser.parse(::RDoc::Markup::Document.new)
        parser.prose
      end

      def mask_directives
        @source.gsub(/^[ \t]*:[a-z][\w-]*:.*$/i) { |text| ' ' * text.length }
      end

      def line_offsets
        offset = 0
        @source.lines.map do |line|
          first = offset
          offset += line.length
          first
        end
      end
    end
  end
end
