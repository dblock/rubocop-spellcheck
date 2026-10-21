# frozen_string_literal: true

require 'asciidoctor'

module RuboCop
  module Spellcheck
    # Extracts original prose selected by the Asciidoctor block parser in secure mode.
    class AsciiDoc
      PROSE = %i[paragraph admonition verse list_item table_cell].freeze
      SKIP = %i[listing literal pass stem comment].freeze

      def self.file?(path)
        path && %w[.adoc .asciidoc].include?(File.extname(path).downcase)
      end

      def initialize(buffer)
        @buffer = buffer
        @lines = buffer.source.lines
      end

      def each_span(&)
        return enum_for(__method__) unless block_given?

        @columns = Hash.new(0)
        @tables = {}
        source = @buffer.source.gsub(/^include::.*$/) { |line| ' ' * line.length }
        document = ::Asciidoctor.load(source, safe: :secure, sourcemap: true, extensions: false)
        spans(document, &)
      end

      private

      def spans(document, &block)
        document.find_by.each do |node|
          next if excluded?(node) || !node.source_location

          if node.context == :table_cell
            table_spans(node, &block)
          else
            fragments(node).each { |text, line| yield mapped_span(text, line) }
          end
        end
      end

      def table_spans(node, &)
        table = node.parent.parent
        span = (@tables[table] ||= AsciiDocTable.new(@buffer, table)).span(node)
        return if node.style == :literal
        return spans(node.inner_document, &) if node.style == :asciidoc

        yield span
      end

      def excluded?(node)
        return false if node.context == :document
        return true if SKIP.include?(node.context)

        node.parent && excluded?(node.parent)
      end

      def fragments(node)
        line = node.source_location.lineno
        return [] if node.context == :document
        return heading(line) if node.context == :section

        titles(node, line) + prose(node, line)
      end

      def heading(line)
        source = @lines.fetch(line - 1)
        title = source[/\A={1,6} (.*)/, 1]
        title ||= source.chomp if @lines[line]&.match?(/\A[=\-~^+]{2,}\s*\z/)
        title ? [[title, line]] : []
      end

      def titles(node, line)
        return [] unless node.title?

        index = line - 2
        index -= 1 while index >= 0 && @lines[index].start_with?('[')
        text = @lines[index] if index >= 0
        text&.start_with?('.') ? [[text.chomp.delete_prefix('.'), index + 1]] : []
      end

      def prose(node, line)
        return [] unless PROSE.include?(node.context)

        if node.context == :list_item
          node.subs.clear
          text = node.text
        else
          text = node.source
        end
        text ? [[text, line]] : []
      end

      def mapped_span(text, line)
        positions = text.lines.flat_map do |part|
          line += 1 while @lines.fetch(line - 1).start_with?('//')
          mapped = line_positions(part, line)
          line += 1
          mapped
        end
        AsciiDocInline.new(text, positions).span
      end

      def line_positions(part, line)
        column = column_for(part, line)
        first = @buffer.line_range(line).begin_pos + column
        @columns[line] = column + part.chomp.length
        part.length.times.map { |index| [first + index, first + index + 1] }
      end

      def column_for(part, line)
        @lines.fetch(line - 1).index(part.chomp, @columns[line]) ||
          raise(RuboCop::ValidationError, "Cannot map AsciiDoc prose in #{@buffer.name}:#{line}: #{part.inspect}")
      end
    end
  end
end
