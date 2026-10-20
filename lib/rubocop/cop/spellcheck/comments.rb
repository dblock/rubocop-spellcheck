# frozen_string_literal: true

module RuboCop
  module Cop
    module Spellcheck
      # Checks comment prose without interpreting Ruby strings or identifiers.
      class Comments < Base
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

        def external_dependency_checksum
          checker.checksum
        end

        private

        def checker
          @checker ||= RuboCop::Spellcheck::Checker.new(
            language: cop_config['Language'],
            dictionary_files: dictionary_files
          )
        end

        def dictionary_files
          files = cop_config['DictionaryFiles']
          return files unless files.is_a?(Array)

          files.map do |path|
            path.is_a?(String) && !path.empty? ? File.expand_path(path, config.base_dir_for_path_parameters) : path
          end
        end

        def check_comment(comment)
          checker.misspellings(prose(comment.text)).each do |word, position|
            first = comment.source_range.begin_pos + position
            range = Parser::Source::Range.new(processed_source.buffer, first, first + word.length)
            add_offense(range, message: spelling_message(word))
          end
        end

        def prose(text)
          # Preserve character offsets while removing non-prose addresses and block delimiters.
          text.gsub(ADDRESS) { |address| ' ' * address.length }
              .gsub(/^=(?:begin|end)\b[^\n]*/) { |marker| ' ' * marker.length }
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
