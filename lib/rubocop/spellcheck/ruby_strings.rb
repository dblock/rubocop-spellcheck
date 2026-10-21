# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Extracts string tokens selected by the syntax tree, excluding symbols and executable strings.
    class RubyStrings
      PATH_ARGUMENTS = { require: 0, require_relative: 0, load: 0, autoload: 1 }.freeze

      # Retains delimiters and heredoc boundaries for source-safe replacement.
      class Span < Spellcheck::Span
        def initialize(text, positions, delimiters, terminator)
          super(text, positions)
          @delimiters = delimiters
          @terminator = terminator
        end

        def correction(word, suggestions)
          Correction.new(word, suggestions, @delimiters, @terminator)
        end
      end

      # Escapes replacement delimiters and never introduces a heredoc terminator.
      class Correction < Spellcheck::Correction
        def initialize(word, suggestions, delimiters, terminator)
          super(word, suggestions)
          @delimiters = delimiters
          @terminator = terminator
        end

        def replacement
          result = super
          return unless result && result != @terminator

          result.each_char.map { |character| @delimiters.include?(character) ? "\\#{character}" : character }.join
        end
      end

      def initialize(source)
        @source = source
        @map = RubyStringMap.new(source.ruby_version)
        @tokens = source.tokens.select { |token| %i[tSTRING tSTRING_CONTENT tCHARACTER].include?(token.type) }
                        .sort_by { |token| token.pos.begin_pos }
      end

      def each_span
        return enum_for(__method__) unless block_given?

        @source.ast.each_node(:str) do |node|
          next if excluded?(node)

          range = content_range(node)
          tokens_in(range).each { |token| yield mapped_span(node, token, range) }
        end
      end

      private

      def mapped_span(node, token, range)
        raw = token.type == :tSTRING_CONTENT ? token.pos : range
        positions = @map.positions(raw.source, raw.begin_pos, token.text, single: single_escapes(node))
        text = token.text.each_char.map { |character| character.valid_encoding? ? character : ' ' }.join
        Span.new(text, positions, delimiters(node), terminator(node))
      end

      def tokens_in(range)
        first = @tokens.bsearch_index { |token| token.pos.end_pos > range.begin_pos }
        return [] unless first

        last = @tokens.bsearch_index { |token| token.pos.begin_pos >= range.end_pos } || @tokens.length
        @tokens[first...last]
      end

      def excluded?(node)
        return true unless node.heredoc? || node.loc.respond_to?(:begin) # __FILE__ has no literal delimiters.
        return true if dependency_string?(node)

        node.each_ancestor do |ancestor|
          return false if ancestor.begin_type?
          return true if %i[regexp dsym xstr].include?(ancestor.type)
        end
        false
      end

      def dependency_string?(node)
        node = node.parent while node.parent && %i[dstr array].include?(node.parent.type)
        call = node.parent
        return false unless call&.send_type?

        dependency_argument?(call, node) &&
          (call.method?(:autoload) ? module_receiver?(call.receiver) : kernel_receiver?(call.receiver))
      end

      def dependency_argument?(call, node)
        return call.arguments.include?(node) if call.method?(:gem)
        return false unless PATH_ARGUMENTS.key?(call.method_name)

        call.arguments[PATH_ARGUMENTS.fetch(call.method_name)].equal?(node)
      end

      def module_receiver?(receiver)
        receiver.nil? || receiver.self_type? || receiver.const_type?
      end

      def kernel_receiver?(receiver)
        receiver.nil? || receiver.self_type? ||
          (receiver.const_type? && %w[Kernel ::Kernel].include?(receiver.const_name))
      end

      def content_range(node)
        return node.loc.heredoc_body if node.heredoc?

        location = node.loc
        range = location.expression
        range.with(begin_pos: location.begin&.end_pos || range.begin_pos,
                   end_pos: location.end&.begin_pos || range.end_pos)
      end

      def single_escapes(node)
        opening = literal_opening(node)
        return '' if opening.match?(/\A<<[-~]?'/)
        return "\\'" if opening == "'"
        return unless opening.start_with?('%q', '%w')

        whitespace = opening.start_with?('%w') ? " \t\r\n" : ''
        "\\#{whitespace}#{paired_delimiters(opening[-1])}"
      end

      def delimiters(node)
        opening = literal_opening(node)
        return '' if opening.start_with?('<<')

        paired_delimiters(opening[-1])
      end

      def paired_delimiters(delimiter)
        return '' unless delimiter

        "#{delimiter}#{{ '(' => ')', '[' => ']', '{' => '}', '<' => '>' }.fetch(delimiter, delimiter)}"
      end

      def terminator(node)
        container = node.parent&.dstr_type? ? node.parent : node
        container.loc.heredoc_end.source.strip if container.heredoc?
      end

      def literal_opening(node)
        return node.loc.expression.source if node.heredoc?
        return node.loc.begin.source if node.loc.begin

        parent = node.parent
        return literal_opening(parent) if parent&.dstr_type?

        parent_opening(parent)
      end

      def parent_opening(parent)
        return '' unless parent&.loc.respond_to?(:begin)

        parent.loc.begin&.source || ''
      end
    end
  end
end
