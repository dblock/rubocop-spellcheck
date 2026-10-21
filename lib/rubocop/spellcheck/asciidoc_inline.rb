# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Masks Asciidoctor inline syntax without substituting attributes or generating HTML.
    class AsciiDocInline
      def initialize(source, positions)
        @source = source.dup
        @positions = positions
      end

      def span
        mask_code
        mask_macros
        mask_quotes
        decoded_span
      end

      private

      def decoded_span
        text = +''
        positions = []
        @source.to_enum(:scan, Markdown::PIECE).each do
          decoded, mapped = decoded_piece(Regexp.last_match)
          text << decoded
          positions.concat(mapped)
        end
        Span.new(text, positions)
      end

      def decoded_piece(match)
        decoded = Markdown.decode(match[0])
        range = [@positions.fetch(match.begin(0)).first, @positions.fetch(match.end(0) - 1).last]
        [decoded, Array.new(decoded.length, range)]
      end

      def mask_code
        mask_matches(::Asciidoctor::InlinePassMacroRx)
        mask_matches(::Asciidoctor::InlinePassRx[false][2], 6)
        mask_matches(::Asciidoctor::InlineStemMacroRx)
        mask_matches(::Asciidoctor::InlineKbdBtnMacroRx)
        mask_matches(::Asciidoctor::InlineImageMacroRx)
        mask_matches(::Asciidoctor::InlineIndextermMacroRx)
        mask_matches(::Asciidoctor::InlineMenuMacroRx)
      end

      def mask_macros
        keep_capture(::Asciidoctor::InlineLinkMacroRx, 3)
        keep_capture(::Asciidoctor::InlineLinkRx, 5)
        keep_capture(/<<[^>,]+(?:,([^>]+))?>>|xref:[^\s\[]+\[([^\]]*)\]/, 1, 2)
        keep_capture(::Asciidoctor::InlineFootnoteMacroRx, 3)
        mask_matches(::Asciidoctor::InlineAnchorRx)
        mask_matches(::Asciidoctor::AttributeReferenceRx)
      end

      def mask_quotes
        ::Asciidoctor::QUOTE_SUBS[false].each do |type, scope, pattern|
          capture = scope == :constrained ? 3 : 2
          type == :monospaced ? mask_matches(pattern) : keep_capture(pattern, capture)
        end
      end

      def mask_matches(pattern, capture = 0)
        @source.dup.to_enum(:scan, pattern).each do
          match = Regexp.last_match
          mask(match.begin(capture), match.end(capture))
        end
      end

      def keep_capture(pattern, *captures)
        @source.dup.to_enum(:scan, pattern).each do
          match = Regexp.last_match
          capture = captures.find { |index| match[index] }
          if capture
            mask(match.begin(0), match.begin(capture))
            mask(match.end(capture), match.end(0))
          else
            mask(match.begin(0), match.end(0))
          end
        end
      end

      def mask(first, last)
        @source[first...last] = @source[first...last].gsub(/[^\n]/, ' ')
      end
    end
  end
end
