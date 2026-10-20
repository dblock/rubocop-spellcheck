# frozen_string_literal: true

require 'open3'
require 'rbconfig'

RSpec.describe 'RuboCop plugin integration' do
  it 'loads through plugins, checks offline, honors config paths, and invalidates its cache' do
    Dir.mktmpdir do |dir|
      dir = File.realpath(dir)
      env = %w[CACHE CONFIG DATA].to_h { |kind| ["KOTOSHU_#{kind}_PATH", File.join(dir, kind.downcase)] }
      env['KOTOSHU_OFFLINE'] = '1'
      root = File.expand_path('fixtures', __dir__)
      setup = ['kotoshu', 'setup', 'en', '--aff', File.join(root, 'en.aff'), '--dic', File.join(root, 'en.dic')]
      output, status = Open3.capture2e(env, *setup)
      expect(status.success?).to be(true), output

      File.write(File.join(dir, '.rubocop.yml'), <<~YAML)
        plugins:
          - rubocop-spellcheck
        AllCops:
          NewCops: enable
          SuggestExtensions: false
        Spellcheck:
          DictionaryFiles:
            - words.txt
      YAML
      File.write(File.join(dir, 'words.txt'), '')
      File.write(File.join(dir, 'example.rb'), "# hello wrold\n")
      command = [RbConfig.ruby, '-S', 'rubocop', '--only', 'Spellcheck/Comments', '--format', 'json',
                 '--cache-root', File.join(dir, 'rubocop-cache'), File.join(dir, 'example.rb')]
      first, errors, status = Open3.capture3(env, *command, chdir: dir)
      expect(status.exitstatus).to eq(1), "#{first}\n#{errors}"
      expect(JSON.parse(first).fetch('files').first.fetch('offenses').first.fetch('location').fetch('column')).to eq(9)
      File.write(File.join(dir, 'words.txt'), "wrold\n")
      second, errors, status = Open3.capture3(env, *command, chdir: dir)
      expect(status.success?).to be(true), "#{second}\n#{errors}"
      expect(JSON.parse(second).fetch('summary').fetch('offense_count')).to eq(0)
    end
  end
end
