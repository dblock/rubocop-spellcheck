# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Uses Ruby's parser, never evaluation, to decode escape sequences and retain source ranges.
    class RubyStringMap
      ESCAPE = /\\(?:u\{[0-9a-fA-F\s]+\}|u[0-9a-fA-F]{4}|x[0-9a-fA-F]{1,2}|
                   [0-7]{1,3}|(?:M-|C-|c)(?:\\(?:M-|C-|c))*\\?.|.)/mx
      PIECE = /#{ESCAPE}|./m

      def initialize(version)
        @version = version
        @escapes = {}
      end

      def positions(raw, first, expected, single:)
        decoded, bytes = decoded_bytes(raw, first, single)
        bytes = without_indentation(decoded, bytes, expected.b)
        character_positions(expected, bytes)
      end

      private

      def decoded_bytes(raw, first, single)
        decoded = +''.b
        bytes = []
        raw.scan(pattern(single)) do |piece|
          match = Regexp.last_match
          piece = decode(piece, single)
          decoded << piece.b
          piece.bytesize.times { bytes << [first + match.begin(0), first + match.end(0)] }
        end
        [decoded, bytes]
      end

      def pattern(single)
        return PIECE unless single
        return /./m if single.empty?

        /\\[#{Regexp.escape(single)}]|./m
      end

      def decode(piece, single)
        return piece unless piece.start_with?('\\') && piece.length > 1
        return piece.delete_prefix('\\') if single&.include?(piece[1])
        return piece if single

        @escapes[piece] ||= parsed_escape(piece)
      end

      def parsed_escape(piece)
        source = RuboCop::ProcessedSource.new("\"#{piece}\"", @version)
        return source.ast.value if source.valid_syntax? && source.ast&.str_type?

        raise RuboCop::ValidationError, "Cannot map Ruby string escape #{piece.inspect}."
      end

      def without_indentation(decoded, bytes, expected)
        return bytes if decoded == expected

        offset = 0
        lines = expected.lines
        decoded.lines.flat_map.with_index do |line, index|
          target = lines.fetch(index, '')
          removed = indentation(line, target)
          mapped = bytes.slice(offset + removed, target.bytesize)
          offset += line.bytesize
          mapped
        end
      end

      def indentation(line, target)
        removed = line.bytesize - target.bytesize
        return removed if removed >= 0 && line.end_with?(target) && line.byteslice(0, removed).match?(/\A[ \t]*\z/)

        raise RuboCop::ValidationError, "Cannot map decoded Ruby string #{target.inspect}."
      end

      def character_positions(text, bytes)
        offset = 0
        text.each_char.map do |character|
          range = [bytes.fetch(offset).first, bytes.fetch(offset + character.bytesize - 1).last]
          offset += character.bytesize
          range
        end
      end
    end
  end
end
