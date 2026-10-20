# frozen_string_literal: true

require 'digest'
require 'kotoshu'

module RuboCop
  module Spellcheck
    # Owns an isolated, cache-only Kotoshu checker and project vocabulary.
    class Checker
      def initialize(language:, dictionary_files:)
        validate!(language, dictionary_files)
        @words = dictionary_files.flat_map { |path| read_words(path) }.to_set
        @checker = build_checker(language)
        @verdicts = {}
        @suggestions = {}
        @checksum = fingerprint(@checker.dictionary, dictionary_files)
      end

      attr_reader :checksum

      def misspellings(text)
        @checker.tokenize(text).reject { |word, _position| correct?(word) }
      end

      def suggestions(word)
        @suggestions[word] ||= @checker.suggest(word, max_suggestions: 3).to_words.first(3)
      end

      private

      def build_checker(language)
        bundle = Kotoshu::ResourceManager.resolve(language: language, want: [:spelling])
        settings = Kotoshu::Configuration.new(
          language: language, offline: true, personal_dictionary: false, backend: 'ruby'
        )
        Kotoshu::Spellchecker.new(resource_bundle: bundle, config: settings)
      rescue Kotoshu::ResourceNotSetupError => e
        raise RuboCop::ValidationError,
              "#{e.message}\nRun `bundle exec kotoshu setup #{language} --want spelling` before RuboCop."
      end

      def validate!(language, files)
        unless language.is_a?(String) && language.match?(/\A[a-zA-Z]+(?:[-_][a-zA-Z0-9]+)*\z/)
          raise RuboCop::ValidationError, 'Spellcheck/Language must be a language code, such as en.'
        end
        return if files.is_a?(Array) && files.all? { |path| path.is_a?(String) && !path.empty? }

        raise RuboCop::ValidationError, 'Spellcheck/DictionaryFiles must be an array of file paths.'
      end

      def read_words(path)
        File.readlines(path, chomp: true, encoding: 'UTF-8').filter_map do |line|
          word = line.strip
          next if word.empty? || word.start_with?('#')
          raise RuboCop::ValidationError, "Expected one word per line in #{path}: #{word.inspect}" if word.match?(/\s/)

          word.downcase
        end
      rescue SystemCallError => e
        raise RuboCop::ValidationError, "Cannot read spelling dictionary #{path}: #{e.message}"
      end

      def correct?(word)
        return true if @words.include?(word.downcase)
        return @verdicts[word] if @verdicts.key?(word)

        @verdicts[word] = @checker.correct?(word)
      end

      def fingerprint(dictionary, files)
        paths = [dictionary.dic_path, dictionary.aff_path, *files]
        Digest::SHA256.hexdigest(
          [Kotoshu::VERSION, *paths.map { |path| Digest::SHA256.file(path).hexdigest }].join("\0")
        )
      end
    end
  end
end
