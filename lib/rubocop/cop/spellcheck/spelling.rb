# frozen_string_literal: true

module RuboCop
  module Cop
    module Spellcheck
      # Checks Ruby comments, Markdown prose, and plain text with shared dictionaries.
      class Spelling < Base
        extend AutoCorrector

        BUNDLED_DATA = File.expand_path('../../../../data', __dir__).freeze
        DIRECTIVE = /
          \A\#\s*(?:!|(?:rubocop|standard|coding|encoding|frozen_string_literal|
          warn_indent|shareable_constant_value|typed)\s*:)|\A\#.*-\*-\s*(?:coding|encoding):
        /x
        ADDRESS = %r{(?:https?://|www\.)[^\s<>]+|[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}}

        def self.support_multiple_source?
          true
        end

        def on_new_investigation
          super
          if RuboCop::Spellcheck::Markdown.file?(processed_source.path)
            check_markdown
          else
            comments = processed_source.comments.reject { |comment| DIRECTIVE.match?(comment.text) }
            RuboCop::Spellcheck::RDocComments.new(prose_buffer, comments).each_span { |span| check_markdown_span(span) }
          end
        end

        def on_other_file
          if RuboCop::Spellcheck::ProseSource.text_file?(processed_source.path)
            check_text
          elsif RuboCop::Spellcheck::Markdown.file?(processed_source.path)
            check_markdown
          elsif RuboCop::Spellcheck::RDoc.file?(processed_source.path)
            RuboCop::Spellcheck::RDoc.new(prose_buffer).each_span { |span| check_markdown_span(span) }
          else
            super
          end
        end

        def relevant_file?(file)
          return false unless super
          return false if File.expand_path(file).start_with?("#{BUNDLED_DATA}/")
          return true unless RuboCop::Spellcheck::ProseSource.text_file?(file)

          !checker.dictionary_file?(file)
        end

        def external_dependency_checksum
          checker.checksum
        end

        def current_corrector
          return super unless RuboCop::Spellcheck::ProseSource.file?(processed_source.path)

          # Prose deliberately bypasses Ruby parsing, but its buffer can still be rewritten.
          @current_corrector ||= Corrector.new(processed_source)
        end

        private

        def check_markdown
          front_matter = cop_config.fetch('Markdown', {}).fetch('FrontMatter', {})
          if front_matter.fetch('Enabled', true)
            RuboCop::Spellcheck::FrontMatter.new(prose_buffer, config: front_matter).each_span do |span|
              check_markdown_span(span)
            end
          end
          RuboCop::Spellcheck::Markdown.new(prose_buffer).each_span do |text, positions|
            check_markdown_span(RuboCop::Spellcheck::Span.new(text, positions))
          end
        end

        def check_text
          checker.misspellings(mask_addresses(processed_source.buffer.source)).each do |word, position|
            next unless word.match?(/\p{L}/)

            report_word(word, position, position + word.length)
          end
        end

        def checker
          @checker ||= RuboCop::Spellcheck::Checker.new(
            dictionary_files: cop_config['DictionaryFiles'],
            base_directory: config.base_dir_for_path_parameters
          )
        end

        def check_markdown_span(span)
          text = mask_addresses(span.text.sub(/\A['’]s\b/, '  '))
          span.each_misspelling(checker, text) do |word, first, last, correction, whole|
            report_word(word, first, last, correction: correction, correctable: whole)
          end
        end

        def report_word(word, first, last, correction: nil, correctable: true)
          range = Parser::Source::Range.new(prose_buffer, first, last)
          range = markdown_document.processed_range(range) if markdown_document
          correction ||= RuboCop::Spellcheck::Correction.new(word, checker.suggestions(word))
          replacement = correction.replacement
          add_offense(range, message: correction.message) do |corrector|
            corrector.replace(range, replacement) if replacement && correctable
          end
        end

        def markdown_document
          processed_source.markdown_document if processed_source.respond_to?(:markdown_document)
        end

        def prose_buffer
          markdown_document ? markdown_document.buffer : processed_source.buffer
        end

        def mask_addresses(text)
          text.gsub(ADDRESS) { |address| ' ' * address.length }
        end
      end
    end
  end
end
