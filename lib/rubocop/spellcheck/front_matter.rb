# frozen_string_literal: true

require 'psych'
require 'date'

module RuboCop
  module Spellcheck
    # Reads YAML string values without constructing application objects.
    class FrontMatter
      # Retains scalar syntax at extraction time rather than in the reporting code.
      class Span < Spellcheck::Span
        def initialize(text, positions, style)
          super(text, positions)
          @style = style
        end

        def correction(word, suggestions)
          Correction.new(word, suggestions, @style)
        end
      end

      # Applies YAML quoting and scalar-type constraints to a spelling replacement.
      class Correction < Spellcheck::Correction
        def initialize(word, suggestions, style)
          super(word, suggestions)
          @style = style
        end

        def replacement
          suggestion = super
          return unless suggestion

          case @style
          when Psych::Nodes::Scalar::SINGLE_QUOTED
            suggestion.gsub("'", "''")
          when Psych::Nodes::Scalar::PLAIN
            suggestion if Psych::ScalarScanner.new(Psych::ClassLoader.new).tokenize(suggestion).is_a?(String)
          else
            suggestion
          end
        end
      end

      HEADER = /\A(?:\uFEFF)?---[ \t]*\n.*?^(?:---|\.\.\.)[ \t]*(?:\n|\z)/m
      ESCAPE = /\\(?:U[0-9a-fA-F]{8}|u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|.)/m

      def initialize(buffer, config: {})
        @buffer = buffer
        @scanner = Psych::ScalarScanner.new(Psych::ClassLoader.new)
        @paths = FrontMatterPaths.new(config)
      end

      def each_span
        return enum_for(__method__) unless block_given?

        root = yaml_root
        string_values(root) { |node| yield scalar_span(node) } if root
      end

      private

      def yaml_root
        return unless (header = HEADER.match(@buffer.source))

        yaml = header[0].sub(/^(?:---|\.\.\.)[ \t]*\n?\z/, '')
        Psych.parse_stream(yaml).children.first&.root
      rescue Psych::SyntaxError => e
        raise RuboCop::ValidationError, "Invalid YAML front matter in #{@buffer.name}: #{e.message}"
      end

      def string_values(node, path = [], &block)
        case node
        when Psych::Nodes::Mapping
          mapping_values(node, path, &block)
        when Psych::Nodes::Sequence
          node.children.each { |value| string_values(value, path, &block) }
        when Psych::Nodes::Scalar
          yield node if @paths.include?(path) && string_scalar?(node)
        end
      end

      def mapping_values(node, path, &block)
        node.children.each_slice(2) do |key, value|
          name = key.is_a?(Psych::Nodes::Scalar) ? key.value : nil
          string_values(value, [*path, name], &block)
        end
      end

      def string_scalar?(node)
        return node.tag == 'tag:yaml.org,2002:str' if node.tag
        return true unless node.plain

        @scanner.tokenize(node.value).is_a?(String)
      end

      def position(line, column)
        @buffer.line_range(line + 1).begin_pos + column
      end

      def scalar_span(node)
        first = position(node.start_line, node.start_column)
        last = position(node.end_line, node.end_column)
        raw = @buffer.source[first...last]
        prefix = raw[/\A(?:(?:&\S+|!\S+)[ \t]+)+/].to_s.length
        style = node.style
        Span.new(*map_pieces(raw[prefix..], style, first + prefix), style)
      end

      def map_pieces(raw, style, first)
        text = +''
        positions = []
        scalar_pieces(raw, style).each do |piece, offset, decoded|
          text << decoded
          decoded.length.times { positions << [first + offset, first + offset + piece.length] }
        end
        [text, positions]
      end

      def scalar_pieces(raw, style)
        return enum_for(__method__, raw, style) unless block_given?

        pattern = style == Psych::Nodes::Scalar::DOUBLE_QUOTED ? /#{ESCAPE}|./m : /''|./m
        raw.to_enum(:scan, pattern).each do
          match = Regexp.last_match
          piece = match[0]
          decoded = decode(piece, style)
          decoded = ' ' * piece.length if ignored_piece?(raw, match.begin(0), style)
          yield piece, match.begin(0), decoded
        end
      end

      def ignored_piece?(raw, offset, style)
        case style
        when Psych::Nodes::Scalar::LITERAL, Psych::Nodes::Scalar::FOLDED
          offset < raw.index("\n").to_i
        when Psych::Nodes::Scalar::SINGLE_QUOTED, Psych::Nodes::Scalar::DOUBLE_QUOTED
          offset.zero? || offset == raw.length - 1
        else
          false
        end
      end

      def decode(piece, style)
        if style == Psych::Nodes::Scalar::DOUBLE_QUOTED && piece.start_with?('\\')
          Psych.safe_load("\"#{piece}\"") || ''
        elsif style == Psych::Nodes::Scalar::SINGLE_QUOTED && piece == "''"
          "'"
        else
          piece
        end
      end
    end
  end
end
