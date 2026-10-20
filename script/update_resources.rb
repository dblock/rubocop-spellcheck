# frozen_string_literal: true

require 'digest'
require 'json'
require 'net/http'
require 'rubygems'

module RuboCop
  module Spellcheck
    # Refreshes packaged resources from one immutable revision and a stable gem release.
    class ResourceUpdater
      REPOSITORY = 'https://github.com/kotoshu/dictionaries'
      FILES = { 'en.aff' => 'index.aff', 'en.dic' => 'index.dic', 'LICENSE' => 'license' }.freeze

      def initialize(root = File.expand_path('..', __dir__))
        @root = root
      end

      def run
        version = latest_version
        revision = latest_revision
        updates = dictionary_updates(download_dictionary(revision), revision).merge(gemspec_update(version))
        updates.each { |path, content| File.binwrite(File.join(@root, path), content) }
        puts "Kotoshu #{version}; dictionary revision #{revision}; #{updates.length} file(s) updated."
      end

      private

      def latest_version
        version = JSON.parse(fetch('https://rubygems.org/api/v1/gems/kotoshu.json')).fetch('version')
        raise "Expected a stable Kotoshu release, got #{version.inspect}" if Gem::Version.new(version).prerelease?

        version
      end

      def latest_revision
        revision = JSON.parse(fetch('https://api.github.com/repos/kotoshu/dictionaries/commits/v1')).fetch('sha')
        raise "Invalid dictionary revision: #{revision.inspect}" unless /\A[0-9a-f]{40}\z/.match?(revision)

        revision
      end

      def download_dictionary(revision)
        files = FILES.transform_values do |name|
          fetch("https://raw.githubusercontent.com/kotoshu/dictionaries/#{revision}/en/spelling/#{name}")
        end
        raise 'Empty dictionary or license received' if files.values.any? { |content| content.strip.empty? }

        files
      end

      def fetch(url)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'rubocop-spellcheck-resource-updater'
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 60) do |http|
          http.request(request)
        end
        raise "Cannot fetch #{url}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      end

      def dictionary_updates(files, revision)
        return {} if files.all? { |name, content| File.binread(File.join(@root, 'data/en', name)) == content }

        updates = files.to_h { |name, content| ["data/en/#{name}", content] }
        updates['data/en/README.md'] = provenance(files, revision)
        updates
      end

      def provenance(files, revision)
        <<~MARKDOWN
          # Bundled English dictionary

          `en.aff` and `en.dic` are unchanged copies of `en/spelling/index.aff` and `en/spelling/index.dic` from [kotoshu/dictionaries at commit `#{revision}`](#{REPOSITORY}/tree/#{revision}/en/spelling).

          This is the SCOWL-derived American English Hunspell dictionary. Its upstream version, copyright, redistribution permissions, credits, and notices are reproduced in full in [LICENSE](LICENSE). The gem's MIT license does not replace these dictionary terms.

          SHA-256 checksums of the unmodified upstream files:

          ```text
          #{Digest::SHA256.hexdigest(files.fetch('en.aff'))}  en.aff
          #{Digest::SHA256.hexdigest(files.fetch('en.dic'))}  en.dic
          #{Digest::SHA256.hexdigest(files.fetch('LICENSE'))}  LICENSE
          ```

          Run `ruby script/update_resources.rb` to check for upstream changes, then review the dictionary and full license diff before merging. The monthly/manual [**Update spelling resources** workflow](../../.github/workflows/update-resources.yml) opens a maintenance PR for these changes. Updates are intentional gem changes, never downloads during linting.
        MARKDOWN
      end

      def gemspec_update(version)
        path = 'rubocop-spellcheck.gemspec'
        original = File.read(File.join(@root, path))
        pattern = /^  spec\.add_dependency 'kotoshu', '~> [0-9.]+'$/
        raise 'Cannot find the Kotoshu dependency declaration' unless original.match?(pattern)

        updated = original.sub(pattern, "  spec.add_dependency 'kotoshu', '~> #{version}'")
        original == updated ? {} : { path => updated }
      end
    end
  end
end

RuboCop::Spellcheck::ResourceUpdater.new.run if $PROGRAM_NAME == __FILE__
