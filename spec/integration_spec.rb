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
      expect(report.fetch('summary').fetch('inspected_file_count')).to eq(3)
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

  it 'discovers text but excludes configured dictionaries, their aliases, and bundled data' do
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
      File.write(File.join(dir, 'words.txt'), "# typpo dictionary comment\nprojectword\n")
      File.symlink(File.join(dir, 'words.txt'), File.join(dir, 'alias.txt'))
      File.write(File.join(dir, 'example.txt'), "😀 hello wrold projectword\n`typpo`\n")
      command = [RbConfig.ruby, '-S', 'rubocop', '--format', 'json', '--cache', 'false']
      output, errors, status = Open3.capture3(*command, chdir: dir)
      expect(status.exitstatus).to eq(1), "#{output}\n#{errors}"
      files = JSON.parse(output).fetch('files')
      offenses = files.flat_map { |file| file.fetch('offenses') }
      expect(offenses.map { |offense| offense.fetch('cop_name') }).to eq(
        ['Spellcheck/Spelling', 'Spellcheck/Spelling']
      )
      affected = files.reject { |file| file.fetch('offenses').empty? }
      expect(affected.map { |file| file.fetch('path') }).to eq(['example.txt'])
      bundled_readme = File.expand_path('../data/en/README.md', __dir__)
      output, errors, status = Open3.capture3(*command, bundled_readme, chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(JSON.parse(output).fetch('summary').fetch('offense_count')).to eq(0)
    end
  end
end
