# frozen_string_literal: true

module RuboCop
  module Cop
    module Spellcheck
      # Checks Ruby comments and visible Markdown prose with shared dictionaries.
      class Spelling < Base
        DIRECTIVE = /
          \A\#\s*(?:!|(?:rubocop|standard|coding|encoding|frozen_string_literal|
          warn_indent|shareable_constant_value|typed)\s*:)|\A\#.*-\*-\s*(?:coding|encoding):
        /x
        ADDRESS = %r{(?:https?://|www\.)[^\s<>]+|[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}}

        def on_new_investigation
          super
          processed_source.comments.each do |comment|
            next if DIRECTIVE.match?(comment.text)

            check_comment(comment)
          end
        end

        def on_other_file
          return unless RuboCop::Spellcheck::Markdown.file?(processed_source.path)

          if front_matter_enabled?
            RuboCop::Spellcheck::FrontMatter.new(processed_source.buffer).each_span do |text, positions|
              check_markdown_span(text, positions)
            end
          end
          RuboCop::Spellcheck::Markdown.new(processed_source.buffer).each_span do |text, positions|
            check_markdown_span(text, positions)
          end
        end

        def external_dependency_checksum
          checker.checksum
        end

        private

        def front_matter_enabled?
          cop_config.fetch('Markdown', {}).fetch('FrontMatter', {}).fetch('Enabled', true)
        end

        def checker
          @checker ||= RuboCop::Spellcheck::Checker.new(
            dictionary_files: cop_config['DictionaryFiles'],
            base_directory: config.base_dir_for_path_parameters
          )
        end

        def check_comment(comment)
          checker.misspellings(prose(comment.text)).each do |word, position|
            first = comment.source_range.begin_pos + position
            report_word(word, first, first + word.length)
          end
        end

        def check_markdown_span(text, positions)
          checker.misspellings(mask_addresses(text)).each do |word, position|
            next unless word.match?(/\p{L}/)

            report_word(word, positions.fetch(position).first, positions.fetch(position + word.length - 1).last)
          end
        end

        def report_word(word, first, last)
          range = Parser::Source::Range.new(processed_source.buffer, first, last)
          add_offense(range, message: spelling_message(word))
        end

        def prose(text)
          # Preserve character offsets while removing non-prose addresses and block delimiters.
          mask_addresses(text).gsub(/^=(?:begin|end)\b[^\n]*/) { |marker| ' ' * marker.length }
        end

        def mask_addresses(text)
          text.gsub(ADDRESS) { |address| ' ' * address.length }
        end

        def spelling_message(word)
          suggestions = checker.suggestions(word)
          message = "Misspelled word: `#{word}`."
          return message if suggestions.empty?

          "#{message} Did you mean #{suggestions.map { |suggestion| "`#{suggestion}`" }.join(', ')}?"
        end
      end
    end
  end
end
