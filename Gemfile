# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.13'
gem 'rubocop', ENV.fetch('RUBOCOP_VERSION', '~> 1.72')
gem 'simplecov', '~> 0.22', require: false

group :development do
  gem 'danger', require: false
  gem 'danger-changelog', require: false
  gem 'danger-toc', require: false
end
