# frozen_string_literal: true

require 'fileutils'
require 'open3'
require_relative 'resources'

resources = SpellcheckBenchmark::Resources
manifest = resources::MANIFEST
manifest.fetch('files').each do |path, hash|
  destination = File.join(resources::CACHE, path)
  FileUtils.mkdir_p(File.dirname(destination))
  url = "https://raw.githubusercontent.com/#{manifest.fetch('repository')}/#{manifest.fetch('revision')}/#{path}"
  system('curl', '--fail', '--silent', '--show-error', '--location', url, '-o', destination, exception: true)
  resources.verify_file!(destination, hash)
end
resources.verify!
File.write(File.join(resources::CACHE, 'empty.pws'), "personal_ws-1.1 en 0\n")
File.write(File.join(resources::CACHE, 'empty.prepl'), "personal_repl-1.1 en 0\n")

aspell = ENV.fetch('ASPELL', 'aspell')
words = File.read(File.join(resources::CACHE, 'data/en/words.txt'))
dictionary = File.join(resources::CACHE, 'expanded.rws')
output, status = Open3.capture2e(aspell, '--lang=en', '--encoding=utf-8', '--affix-compress=false',
                                 'create', 'master', dictionary, stdin_data: words)
raise "Aspell dictionary creation failed: #{output}" unless status.success?

dump, status = Open3.capture2e(aspell, "--master=#{dictionary}", '--encoding=utf-8', 'dump', 'master')
raise "Aspell dictionary inspection failed: #{dump}" unless status.success?

source_words = words.lines.map(&:chomp)
compiled_words = dump.lines.map(&:chomp)
metadata = {
  sha256: Digest::SHA256.file(dictionary).hexdigest, source_count: source_words.size,
  compiled_count: compiled_words.size, omitted_words: source_words - compiled_words,
  extra_words: compiled_words - source_words, creation_output: output
}
File.write(File.join(resources::CACHE, 'aspell-build.json'), "#{JSON.pretty_generate(metadata)}\n")
puts "Verified pinned resources and built #{dictionary}"
