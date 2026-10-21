# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Rebuilds vocabulary from current violations while retaining comments and needed word spelling.
    class Vocabulary
      # Still fingerprints and excludes the vocabulary file, but does not accept its words.
      class Checker < Spellcheck::Checker
        private

        def dictionary_word(line, path)
          super unless path == File.join(@base_directory, '.spellcheck.txt')
        end
      end

      def initialize(config)
        @config = config
        @path = File.join(config.base_dir_for_path_parameters, '.spellcheck.txt')
        @words = Set.new
      end

      def add(offense)
        word = offense.message[/Misspelled word: `([^`]+)`\./, 1]
        unless word
          raise RuboCop::ValidationError, "Cannot extract spelling vocabulary from #{offense.message.inspect}."
        end

        @words << word.downcase
      end

      def write
        content = File.exist?(@path) ? File.read(@path, encoding: 'UTF-8') : ''
        additions = (@words - existing_words(content)).sort
        config = VocabularyConfig.new(@config.loaded_path, section: section).updated(dictionaries)
        updated = extended(retained(content), additions)
        File.write(@path, updated) unless content == updated
        write_configuration(config)
        puts "Updated #{@path}. Review generated vocabulary: reported typos are accepted too."
      end

      private

      def retained(content)
        content.lines.select do |line|
          word = line.strip
          word.empty? || word.start_with?('#') || @words.include?(word.downcase)
        end.join
      end

      def write_configuration(content)
        File.write(@config.loaded_path, content) unless File.read(@config.loaded_path, encoding: 'UTF-8') == content
      end

      def dictionaries
        badge = RuboCop::Cop::Badge.parse(VocabularyConfig::COP)
        files = @config.for_badge(badge)['DictionaryFiles'] || Checker::DEFAULT_FILES
        files.transform_values do |paths|
          paths.any? { |path| vocabulary_path?(path) } ? paths : [*paths, '.spellcheck.txt']
        end
      end

      def vocabulary_path?(path)
        !path.start_with?('gem:') && File.expand_path(path, @config.base_dir_for_path_parameters) == @path
      end

      def section
        @config.for_cop(VocabularyConfig::COP).key?('DictionaryFiles') ? VocabularyConfig::COP : 'Spellcheck'
      end

      def existing_words(content)
        content.lines.filter_map do |line|
          word = line.strip
          next if word.empty? || word.start_with?('#')
          raise RuboCop::ValidationError, "Expected one word per line in #{@path}: #{word.inspect}" if word.match?(/\s/)

          word.downcase
        end.to_set
      end

      def extended(content, additions)
        return content if additions.empty?

        separator = content.empty? || content.end_with?("\n") ? '' : "\n"
        "#{content}#{separator}#{additions.join("\n")}\n"
      end
    end
  end
end
