# frozen_string_literal: true

require_relative 'resources'

module SpellcheckBenchmark
  # Normalizes word APIs only; no document extraction or correction policy is added.
  module Engines
    NAMES = %w[kotoshu kotoshu_auto checker plain_ruby hunspell aspell did_you_mean].freeze
    Engine = Struct.new(:lookup, :suggestions, :close, :metadata, keyword_init: true)

    def self.build(name)
      raise ArgumentError, "Unknown engine: #{name}" unless NAMES.include?(name)

      public_send(name)
    end

    def self.kotoshu
      kotoshu_engine('ruby')
    end

    def self.kotoshu_auto
      kotoshu_engine('auto')
    end

    def self.kotoshu_engine(backend)
      require 'kotoshu'
      config = Kotoshu::Configuration.new(language: 'en', offline: true, personal_dictionary: false, backend: backend)
      object = Kotoshu::Spellchecker.new(dictionary: kotoshu_dictionary, config: config)
      if backend == 'auto' && !object.native_backend
        raise Kotoshu::Native::Unavailable, 'Kotoshu auto selected Ruby; Rust comparison requires the native extension.'
      end

      suggestions = ->(word) { object.suggest(word, max_suggestions: 3).to_words }
      Engine.new(lookup: object.method(:correct?), suggestions: suggestions, metadata: kotoshu_metadata(object))
    end

    def self.kotoshu_dictionary
      Kotoshu::Dictionary::Hunspell.new(
        dic_path: File.join(Resources::ROOT, 'data/en/en.dic'),
        aff_path: File.join(Resources::ROOT, 'data/en/en.aff'), language_code: 'en'
      )
    end

    def self.kotoshu_metadata(object)
      { requested: object.config.backend, selected: object.native_backend ? 'native' : 'ruby',
        native_version: Kotoshu::Native.available? ? Kotoshu::Native::VERSION : nil, suggestions: 'ruby' }
    end

    def self.kotoshu_build
      spec = Gem.loaded_specs.fetch('kotoshu')
      lock = File.read(File.join(spec.full_gem_path, 'Cargo.lock'))
      source = lock.match(/\[\[package\]\]\nname = "kotoshu"\nversion = "[^"]+"\nsource = "([^"]+)"/)
      raise 'Cannot identify the compiled Rust engine source' unless source

      { platform: spec.platform.to_s, core_source: source[1],
        cargo_lock_sha256: Digest::SHA256.hexdigest(lock), cargo_lock: lock }
    end

    def self.checker
      require_relative '../lib/rubocop/spellcheck/checker'
      object = RuboCop::Spellcheck::Checker.new
      Engine.new(lookup: object.method(:correct?), suggestions: object.method(:suggestions))
    end

    def self.plain_ruby
      require File.join(Resources::CACHE, 'spelling')
      object = Spelling.new
      Engine.new(lookup: object.method(:correct?), suggestions: ->(word) { [object.replacement(word)].compact })
    end

    def self.hunspell
      require 'ffi/hunspell'
      object = FFI::Hunspell::Dictionary.new(File.join(Resources::ROOT, 'data/en/en.aff'),
                                             File.join(Resources::ROOT, 'data/en/en.dic'))
      Engine.new(lookup: object.method(:check?), suggestions: ->(word) { object.suggest(word).first(3) },
                 close: object.method(:close))
    end

    def self.aspell
      require 'ffi/aspell'
      object = FFI::Aspell::Speller.new('en_US', 'lang' => 'en_US',
                                                 'master' => File.join(Resources::CACHE, 'expanded.rws'),
                                                 'encoding' => 'utf-8', 'ignore' => '0',
                                                 'ignore-case' => 'false', 'use-other-dicts' => 'false',
                                                 'personal' => File.join(Resources::CACHE, 'empty.pws'),
                                                 'repl' => File.join(Resources::CACHE, 'empty.prepl'),
                                                 'sug-mode' => 'normal')
      Engine.new(lookup: object.method(:correct?), suggestions: ->(word) { object.suggestions(word).first(3) },
                 close: object.method(:close))
    end

    def self.did_you_mean
      require 'did_you_mean'
      words = File.readlines(File.join(Resources::CACHE, 'data/en/words.txt'), chomp: true)
      object = DidYouMean::SpellChecker.new(dictionary: words)
      Engine.new(suggestions: ->(word) { object.correct(word).first(3) })
    end
  end
end
