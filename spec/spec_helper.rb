# frozen_string_literal: true

require 'simplecov'
SimpleCov.start

require 'rubocop'
require 'rubocop/rspec/support'
require 'rubocop-spellcheck'
require 'tmpdir'

RSpec.configure do |config|
  config.include RuboCop::RSpec::ExpectOffense
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
end

module SpellcheckFixtures
  def fixture_bundle(language = 'en')
    root = File.expand_path('fixtures', __dir__)
    dictionary = Kotoshu::Dictionary::Hunspell.new(
      dic_path: File.join(root, 'en.dic'), aff_path: File.join(root, 'en.aff'), language_code: language
    )
    Kotoshu::ResourceBundle.new(language: language, dictionary: dictionary, cached: true)
  end
end

RSpec.configure { |config| config.include SpellcheckFixtures }
