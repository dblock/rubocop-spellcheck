# frozen_string_literal: true

require 'commonmarker'

module RuboCop
  module Spellcheck
    # Extracts visible text while retaining character ranges in the original source.
    class Markdown
      EXTENSIONS = %w[.md .markdown].freeze
      ENTITY = /&(?:\#x[0-9a-f]+|\#\d+|[a-z][a-z0-9]+);/i
      PIECE = /#{ENTITY}|\\[[:punct:]]|./m
      LIQUID = /\{\{.*?\}\}|\{%.*?%\}/m

      def self.file?(path)
        path && EXTENSIONS.include?(File.extname(path).downcase)
      end

      def initialize(buffer)
        @buffer = buffer
        @lines = buffer.source.lines
      end

      def each_span
        return enum_for(__method__) unless block_given?

        document = Commonmarker.parse(parser_source, options: {
                                        parse: { smart: false },
                                        extension: { shortcodes: false, footnotes: true }
                                      })
        document.walk do |node|
          next unless node.type == :text

          text, positions = mapped_text(node)
          yield text, positions unless text.empty?
        end
      end

      private

      def parser_source
        without_front_matter.gsub(LIQUID) do |expression|
          expression.gsub(/[^\n]/) { |character| 'x' * character.bytesize }
        end
      end

      def without_front_matter
        @buffer.source.sub(/\A(?:\uFEFF)?---[ \t]*\n.*?^(?:---|\.\.\.)[ \t]*(?:\n|\z)/m) do |header|
          header.gsub(/[^\n]/, ' ')
        end
      end

      def character_position(line, byte_column)
        prefix = @lines.fetch(line - 1).byteslice(0, byte_column)
        @buffer.line_range(line).begin_pos + prefix.length
      end

      def mapped_text(node)
        location = node.source_position
        first = character_position(location.fetch(:start_line), location.fetch(:start_column) - 1)
        last = character_position(location.fetch(:end_line), location.fetch(:end_column))
        decode_text(@buffer.source[first...last], first)
      end

      def decode_text(raw, first)
        raw = without_liquid(raw)
        text = +''
        positions = []
        raw.to_enum(:scan, PIECE).each do
          match = Regexp.last_match
          decoded = decode(match[0])
          text << decoded
          decoded.length.times { positions << [first + match.begin(0), first + match.end(0)] }
        end
        [text, positions]
      end

      def without_liquid(raw)
        raw.gsub(LIQUID) { |expression| expression.gsub(/[^\n]/, ' ') }
      end

      def decode(piece)
        return piece.delete_prefix('\\') if piece.start_with?('\\')
        return piece unless ENTITY.match?(piece)

        document = Commonmarker.parse(piece, options: { parse: { smart: false } })
        document.walk.select { |node| node.type == :text }.map(&:string_content).join
      end
    end
  end
end
