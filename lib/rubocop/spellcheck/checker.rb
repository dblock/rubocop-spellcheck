# frozen_string_literal: true

require 'digest'
require 'kotoshu'
require 'pathname'

module RuboCop
  module Spellcheck
    # Checks words against explicitly selected, local language dictionaries.
    class Checker
      DEFAULT_FILES = { 'en' => ['gem:rubocop-spellcheck/data/en/en.dic'].freeze }.freeze
      ENGLISH_WORD = /(?<![\p{L}\p{M}\p{N}_])[\p{Latin}\p{M}]+(?:['’][\p{Latin}\p{M}]+)*(?![\p{L}\p{M}\p{N}_])/

      def initialize(dictionary_files: nil, base_directory: Dir.pwd)
        @base_directory = base_directory
        @paths = []
        @checkers = build_checkers(dictionary_files.nil? ? DEFAULT_FILES : dictionary_files)
        @verdicts = {}
        @suggestions = {}
        @checksum = Digest::SHA256.hexdigest(
          [Kotoshu::VERSION, *@paths.map { |path| Digest::SHA256.file(path).hexdigest }].join("\0")
        )
      end

      attr_reader :checksum

      def dictionary_file?(path)
        return false unless File.exist?(path)

        @paths.any? { |dictionary| File.identical?(dictionary, path) }
      end

      def misspellings(text)
        @checkers.flat_map { |checker| tokens(checker, text) }.uniq
                 .sort_by(&:last).reject { |word, _position| correct?(word) }
      end

      def suggestions(word)
        @suggestions[word] ||= @checkers.flat_map do |checker|
          checker.suggest(word, max_suggestions: 3).to_words
        end.uniq.first(3)
      end

      private

      def tokens(checker, text)
        return checker.tokenize(text) unless checker.config.language.match?(/\Aen(?:[-_]|\z)/i)

        text.to_enum(:scan, ENGLISH_WORD).map { [Regexp.last_match[0], Regexp.last_match.begin(0)] }
      end

      def build_checkers(files)
        validate!(files)
        files.flat_map do |language, paths|
          paths.map { |path| build_checker(language, resolve_path(path)) }
        end
      end

      def validate!(files)
        valid = files.is_a?(Hash) && !files.empty? &&
                files.all? { |language, paths| valid_language?(language) && valid_paths?(paths) }
        return if valid

        raise RuboCop::ValidationError, 'Spellcheck/DictionaryFiles must map language codes to nonempty lists of paths.'
      end

      def valid_language?(language)
        language.is_a?(String) && language.match?(/\A[a-zA-Z]+(?:[-_][a-zA-Z0-9]+)*\z/)
      end

      def valid_paths?(paths)
        paths.is_a?(Array) && !paths.empty? && paths.all? { |path| path.is_a?(String) && !path.empty? }
      end

      def resolve_path(path)
        return File.expand_path(path, @base_directory) unless path.start_with?('gem:')

        match = %r{\Agem:([^/]+)/(.+)\z}.match(path)
        raise RuboCop::ValidationError, "Invalid gem dictionary path: #{path}" unless match

        root = Gem::Specification.find_by_name(match[1]).full_gem_path
        resolved = File.expand_path(match[2], root)
        raise RuboCop::ValidationError, "Path escapes gem: #{path}" unless resolved.start_with?("#{root}/")

        resolved
      rescue Gem::LoadError => e
        raise RuboCop::ValidationError, "Cannot resolve dictionary #{path}: #{e.message}"
      end

      def build_checker(language, path)
        dictionary = load_dictionary(language, path)
        settings = Kotoshu::Configuration.new(
          language: language, offline: true, personal_dictionary: false, backend: 'ruby'
        )
        Kotoshu::Spellchecker.new(dictionary: dictionary, config: settings)
      end

      def load_dictionary(language, path)
        case File.extname(path)
        when '.dic'
          hunspell_dictionary(language, path)
        when '.txt'
          words = read_file(path).lines.filter_map { |line| dictionary_word(line, path) }
          Kotoshu::Dictionary::PlainText.from_words(words, language_code: language)
        else
          raise RuboCop::ValidationError, "Expected a .dic or .txt dictionary: #{path}"
        end
      end

      def hunspell_dictionary(language, path)
        aff = path.sub(/\.dic\z/, '.aff')
        [path, aff].each { |file| read_file(file) }
        Kotoshu::Dictionary::Hunspell.new(dic_path: path, aff_path: aff, language_code: language)
      end

      def read_file(path)
        content = File.read(path, encoding: 'UTF-8')
        @paths << path
        content
      rescue SystemCallError => e
        raise RuboCop::ValidationError, "Cannot read spelling dictionary #{path}: #{e.message}"
      end

      def dictionary_word(line, path)
        word = line.strip
        return if word.empty? || word.start_with?('#')
        raise RuboCop::ValidationError, "Expected one word per line in #{path}: #{word.inspect}" if word.match?(/\s/)

        word
      end

      def correct?(word)
        return @verdicts[word] if @verdicts.key?(word)

        @verdicts[word] = @checkers.any? { |checker| checker.correct?(word) }
      end
    end
  end
end
