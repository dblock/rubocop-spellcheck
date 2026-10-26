# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'
require 'time'
require_relative 'resources'
require_relative 'engines'
require_relative 'summary'

resources = SpellcheckBenchmark::Resources
resources.verify!
resources.verify_generated!
count = Integer(ENV.fetch('TRIALS', '3'))
raise 'TRIALS must be at least three' if count < 3

trials = (1..count).flat_map do |trial|
  SpellcheckBenchmark::Engines::NAMES.rotate(trial - 1).map do |name|
    warn "Trial #{trial}/#{count}: #{name}"
    output, diagnostics, status = Open3.capture3(RbConfig.ruby, '--disable-did_you_mean',
                                                 File.join(__dir__, 'worker.rb'), name)
    result = JSON.parse(output).merge('trial' => trial, 'diagnostics' => diagnostics)
    raise "Benchmark failed: #{result}" unless status.success? && result.fetch('status') == 'ok'

    result
  end
end
report = {
  recorded_at: Time.now.utc.iso8601, ruby: RUBY_DESCRIPTION, platform: RUBY_PLATFORM,
  os: Open3.capture2('uname', '-srvm').first.strip,
  cpu: Open3.capture2('sysctl', '-n', 'machdep.cpu.brand_string').first.strip,
  aspell: Open3.capture2(ENV.fetch('ASPELL', 'aspell'), '--version').first.strip,
  rustc: Open3.capture2('rustc', '--version').first.strip,
  kotoshu_build: SpellcheckBenchmark::Engines.kotoshu_build,
  gems: Gem.loaded_specs.transform_values(&:version).transform_values(&:to_s),
  resources: resources::MANIFEST,
  aspell_dictionary: JSON.parse(File.read(File.join(resources::CACHE, 'aspell-build.json'))),
  seed: SpellcheckBenchmark::Corpus::SEED, expected_corrections: SpellcheckBenchmark::Corpus::TYPOS,
  trials: trials, summary: trials.group_by { |trial| trial.fetch('engine') }.transform_values do |values|
    SpellcheckBenchmark::Summary.engine(values)
  end, lookup_disagreements: SpellcheckBenchmark::Summary.disagreements(trials)
}
destination = ARGV.fetch(0, File.join(__dir__, 'results.json'))
File.write(destination, "#{JSON.pretty_generate(report)}\n")
puts "Wrote #{destination}"
puts JSON.pretty_generate(report.fetch(:summary))
