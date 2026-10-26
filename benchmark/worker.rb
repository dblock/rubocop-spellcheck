# frozen_string_literal: true

require 'json'
require_relative 'resources'
require_relative 'corpus'

module SpellcheckBenchmark
  # Measures each batch without JSON serialization inside the timed region.
  module Worker
    def self.measure(callable, words, repeats)
      return { milliseconds: nil, operations: 0, values: nil } unless callable

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      values = nil
      repeats.times { values = words.map { |word| callable.call(word) } }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      { milliseconds: elapsed * 1000, operations: words.size * repeats, values: words.zip(values).to_h }
    end

    def self.initialize_engine(name)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      require_relative 'engines'
      engine = Engines.build(name)
      [engine, (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000]
    end

    def self.run(name)
      words = File.readlines(File.join(Resources::CACHE, 'data/en/words.txt'), chomp: true)
      lookups = Corpus.lookups(words)
      engine, initialization = initialize_engine(name)
      { engine: name, status: 'ok', initialization_ms: initialization, backend: engine.metadata,
        **phases(engine, lookups), native: native_libraries }
    ensure
      engine&.close&.call
    end

    def self.phases(engine, lookups)
      { lookup_cold: measure(engine.lookup, lookups, 1), lookup_warm: measure(engine.lookup, lookups, 10),
        suggestion_cold: measure(engine.suggestions, Corpus::TYPOS.keys, 1),
        suggestion_warm: measure(engine.suggestions, Corpus::TYPOS.keys, 1) }
    end

    def self.native_libraries
      return FFI::Hunspell.ffi_libraries.map(&:name) if defined?(FFI::Hunspell)
      return FFI::Aspell.ffi_libraries.map(&:name) if defined?(FFI::Aspell)

      []
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    SpellcheckBenchmark::Resources.verify!
    SpellcheckBenchmark::Resources.verify_generated!
    puts JSON.generate(SpellcheckBenchmark::Worker.run(ARGV.fetch(0)))
  rescue StandardError, LoadError => e
    warn "#{e.class}: #{e.message}"
    puts JSON.generate(engine: ARGV[0], status: 'error', error: "#{e.class}: #{e.message}")
    exit 1
  end
end
