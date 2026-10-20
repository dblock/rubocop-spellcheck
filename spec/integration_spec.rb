# frozen_string_literal: true

require 'open3'
require 'rbconfig'

RSpec.describe 'RuboCop spelling integration' do
  it 'loads through plugins, checks offline, honors config paths, and invalidates its cache' do
    Dir.mktmpdir do |dir|
      dir = File.realpath(dir)
      env = %w[CACHE CONFIG DATA].to_h { |kind| ["KOTOSHU_#{kind}_PATH", File.join(dir, kind.downcase)] }
      env['KOTOSHU_OFFLINE'] = '1'
      File.write(File.join(dir, '.rubocop.yml'), <<~YAML)
        plugins:
          - rubocop-spellcheck
        AllCops:
          NewCops: enable
          SuggestExtensions: false
        Spellcheck:
          DictionaryFiles:
            en:
              - gem:rubocop-spellcheck/data/en/en.dic
              - words.txt
      YAML
      File.write(File.join(dir, 'words.txt'), '')
      File.write(File.join(dir, 'example.rb'), "# hello wrold\n")
      command = [RbConfig.ruby, '-S', 'rubocop', '--only', 'Spellcheck/Spelling', '--format', 'json',
                 '--cache-root', File.join(dir, 'rubocop-cache'), File.join(dir, 'example.rb')]
      first, errors, status = Open3.capture3(env, *command, chdir: dir)
      expect(status.exitstatus).to eq(1), "#{first}\n#{errors}"
      expect(JSON.parse(first).fetch('files').first.fetch('offenses').first.fetch('location').fetch('column')).to eq(9)
      File.write(File.join(dir, 'words.txt'), "wrold\n")
      second, errors, status = Open3.capture3(env, *command, chdir: dir)
      expect(status.success?).to be(true), "#{second}\n#{errors}"
      expect(JSON.parse(second).fetch('summary').fetch('offense_count')).to eq(0)
      expect(Dir.glob(File.join(dir, 'cache', '**', '*')).select { |path| File.file?(path) }).to be_empty
    end
  end

  it 'discovers Markdown, avoids Ruby diagnostics, and invalidates cached dictionary results' do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.rubocop.yml'), <<~YAML)
        plugins:
          - rubocop-spellcheck
        AllCops:
          NewCops: enable
          SuggestExtensions: false
        Spellcheck:
          DictionaryFiles:
            en:
              - gem:rubocop-spellcheck/data/en/en.dic
              - words.txt
      YAML
      File.write(File.join(dir, 'words.txt'), '')
      File.write(File.join(dir, 'example.md'), "# 😀 wrold\n\n```ruby\ninvalid(\n```\n")
      File.write(File.join(dir, 'example.rb'), "# frozen_string_literal: true\n\n# hello world\n")
      command = [RbConfig.ruby, '-S', 'rubocop', '--format', 'json', '--cache-root', File.join(dir, 'cache')]
      first, errors, status = Open3.capture3(*command, chdir: dir)
      expect(status.exitstatus).to eq(1), "#{first}\n#{errors}"
      report = JSON.parse(first)
      expect(report.fetch('summary').fetch('inspected_file_count')).to eq(2)
      offenses = report.fetch('files').flat_map { |file| file.fetch('offenses') }
      expect(offenses.map { |offense| offense.fetch('cop_name') }).to eq(['Spellcheck/Spelling'])
      expect(offenses.first.fetch('location')).to include('line' => 1, 'column' => 5, 'length' => 5)
      cached, errors, status = Open3.capture3(*command, chdir: dir)
      expect(status.exitstatus).to eq(1), "#{cached}\n#{errors}"
      expect(JSON.parse(cached)).to eq(report)
      File.write(File.join(dir, 'words.txt'), "wrold\n")
      second, errors, status = Open3.capture3(*command, chdir: dir)
      expect(status.success?).to be(true), "#{second}\n#{errors}"
      expect(JSON.parse(second).fetch('summary').fetch('offense_count')).to eq(0)
    end
  end
end
