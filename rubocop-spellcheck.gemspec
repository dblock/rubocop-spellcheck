# frozen_string_literal: true

require_relative 'lib/rubocop/spellcheck/version'

Gem::Specification.new do |spec|
  spec.name = 'rubocop-spellcheck'
  spec.version = RuboCop::Spellcheck::VERSION
  spec.authors = ['Daniel (dB.) Doubrovkine']
  spec.email = ['dblock@dblock.org']
  spec.summary = 'Spellcheck Ruby comments with RuboCop and Kotoshu.'
  spec.description = 'RuboCop spelling checks for Ruby comments, powered by Kotoshu with offline dictionaries.'
  spec.homepage = 'https://github.com/dblock/rubocop-spellcheck'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'
  spec.metadata = {
    'allowed_push_host' => 'https://rubygems.org',
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/master/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'rubygems_mfa_required' => 'true',
    'default_lint_roller_plugin' => 'RuboCop::Spellcheck::Plugin'
  }
  spec.files = Dir['lib/**/*.rb', 'config/*.yml'] + %w[README.md CHANGELOG.md LICENSE.txt]
  spec.require_paths = ['lib']
  spec.add_dependency 'kotoshu', '~> 1.0.8'
  spec.add_dependency 'lint_roller', '~> 1.1'
  spec.add_dependency 'rubocop', '~> 1.72', '>= 1.72.1'
end
