# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.13'
gem 'rubocop', ENV.fetch('RUBOCOP_VERSION', '~> 1.72')
gem 'rubocop-rake', '~> 0.7', require: false
gem 'rubocop-rspec', '~> 3.0', require: false
gem 'simplecov', '~> 0.22', require: false

group :development do
  gem 'danger', require: false
  gem 'danger-changelog', require: false
  gem 'danger-toc', require: false
end
