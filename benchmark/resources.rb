# frozen_string_literal: true

require 'digest'
require 'json'

module SpellcheckBenchmark
  # Verifies local inputs without network access.
  module Resources
    ROOT = File.expand_path('..', __dir__)
    CACHE = File.join(ROOT, 'vendor/spellcheck-benchmark')
    MANIFEST = JSON.parse(File.read(File.join(__dir__, 'resources.json'))).freeze

    def self.verify_file!(path, expected)
      return if File.file?(path) && Digest::SHA256.file(path).hexdigest == expected

      raise "Missing or changed benchmark resource: #{path}. Run ruby benchmark/setup.rb."
    end

    def self.verify!
      MANIFEST.fetch('files').each { |path, hash| verify_file!(File.join(CACHE, path), hash) }
      MANIFEST.fetch('dictionary').each { |path, hash| verify_file!(File.join(ROOT, path), hash) }
    end

    def self.verify_generated!
      %w[expanded.rws aspell-build.json empty.pws empty.prepl].each do |path|
        next if File.size?(File.join(CACHE, path))

        raise "Missing generated dictionary: #{path}. Run ruby benchmark/setup.rb."
      end
      verify_file!(File.join(CACHE, 'empty.pws'), Digest::SHA256.hexdigest("personal_ws-1.1 en 0\n"))
      verify_file!(File.join(CACHE, 'empty.prepl'), Digest::SHA256.hexdigest("personal_repl-1.1 en 0\n"))
      metadata = JSON.parse(File.read(File.join(CACHE, 'aspell-build.json')))
      verify_file!(File.join(CACHE, 'expanded.rws'), metadata.fetch('sha256'))
    end
  end
end
