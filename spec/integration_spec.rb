# frozen_string_literal: true

require 'open3'
require 'rbconfig'

RSpec.describe 'RuboCop spelling integration' do
  it 'corrects explicitly tagged Markdown Ruby strings, retains identifiers, and generates vocabulary from both' do
    Dir.mktmpdir do |dir|
      fixtures = File.expand_path('fixtures/markdown_ruby', __dir__)
      FileUtils.cp(File.join(fixtures, 'input.md'), File.join(dir, 'example.md'))
      %w[en.dic en.aff].each { |path| FileUtils.cp(File.expand_path("fixtures/#{path}", __dir__), dir) }
      File.write(File.join(dir, '.rubocop.yml'), <<~YAML)
        plugins:
          - rubocop-spellcheck
        AllCops:
          NewCops: enable
          SuggestExtensions: false
        Spellcheck:
          DictionaryFiles:
            en: [en.dic]
        Spellcheck/Spelling:
          Ruby:
            Identifiers: true
      YAML
      command = [RbConfig.ruby, '-S', 'rubocop', '--only', 'Spellcheck/Spelling', 'example.md']
      output, errors, status = Open3.capture3(*command, '-a', chdir: dir)
      expect(status.exitstatus).to eq(1), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, 'example.md'))).to eq(File.read(File.join(fixtures, 'input.md')))
      2.times do
        output, errors, status = Open3.capture3(*command, '-A', '--format', 'json', chdir: dir)
        expect(status.exitstatus).to eq(1), "#{output}\n#{errors}"
        expect(File.read(File.join(dir, 'example.md'))).to eq(File.read(File.join(fixtures, 'expected.md')))
        expect(JSON.parse(output).fetch('summary').fetch('offense_count')).to be >= 2
      end
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, '.spellcheck.txt'))).to eq("wrold\n")
      output, errors, status = Open3.capture3(*command, chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
    end
  end

  it 'generates vocabulary instead of disabling spelling and preserves dictionaries across repeated CLI runs' do
    Dir.mktmpdir do |dir|
      FileUtils.cp_r(File.expand_path('fixtures/auto_gen_config', __dir__), File.join(dir, 'input'))
      File.write(File.join(dir, '.rubocop.yml'), <<~YAML)
        # Keep this comment.
        plugins:
          - rubocop-spellcheck
        AllCops:
          NewCops: enable
          SuggestExtensions: false
      YAML
      command = [RbConfig.ruby, '-S', 'rubocop', '--only', 'Spellcheck/Spelling', 'input']
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, '.spellcheck.txt'))).to eq("quuxify\nwrold\n")
      configuration = File.read(File.join(dir, '.rubocop.yml'))
      expect(configuration).to include('# Keep this comment.')
      expect(YAML.safe_load(configuration).dig('Spellcheck', 'DictionaryFiles')).to eq(
        'en' => ['gem:rubocop-spellcheck/data/en/en.dic', '.spellcheck.txt']
      )
      expect(File.read(File.join(dir, '.rubocop_todo.yml'))).not_to include('Spellcheck/Spelling:')
      output, errors, status = Open3.capture3(*command, '--format', 'json', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(JSON.parse(output).fetch('summary').fetch('offense_count')).to eq(0)
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, '.spellcheck.txt'))).to eq("quuxify\nwrold\n")
      expect(File.read(File.join(dir, '.rubocop.yml'))).to eq(configuration)
      File.write(File.join(dir, 'input', 'new.txt'), 'zzzzzzzzzzzz')
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, '.spellcheck.txt'))).to eq("quuxify\nwrold\nzzzzzzzzzzzz\n")
    end
  end

  it 'retains cop-specific dictionary overrides, comments, and existing case-insensitive vocabulary' do
    Dir.mktmpdir do |dir|
      FileUtils.cp_r(File.expand_path('fixtures/auto_gen_config', __dir__), File.join(dir, 'input'))
      %w[en.dic en.aff].each { |path| FileUtils.cp(File.expand_path("fixtures/#{path}", __dir__), dir) }
      File.write(File.join(dir, '.spellcheck.txt'), "# Existing vocabulary\nQuuxify")
      File.write(File.join(dir, '.rubocop.yml'), <<~YAML)
        plugins:
          - rubocop-spellcheck
        AllCops:
          NewCops: enable
          SuggestExtensions: false
        Spellcheck/Spelling:
          # Keep cop options.
          DictionaryFiles:
            en: [en.dic]
          Markdown:
            FrontMatter:
              Enabled: false
        Layout/LineLength:
          Max: 100
      YAML
      command = [RbConfig.ruby, '-S', 'rubocop', '--only', 'Spellcheck/Spelling', 'input']
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, '.spellcheck.txt'))).to eq("# Existing vocabulary\nQuuxify\nwrold\n")
      configuration = File.read(File.join(dir, '.rubocop.yml'))
      expect(configuration).to include('# Keep cop options.')
      data = YAML.safe_load(configuration)
      expect(data.dig('Spellcheck/Spelling', 'DictionaryFiles')).to eq('en' => ['en.dic', '.spellcheck.txt'])
      expect(data.dig('Spellcheck/Spelling', 'Markdown', 'FrontMatter', 'Enabled')).to be(false)
      expect(data.dig('Layout/LineLength', 'Max')).to eq(100)
      output, errors, status = Open3.capture3(*command, '--format', 'json', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(JSON.parse(output).fetch('summary').fetch('offense_count')).to eq(0)
    end
  end

  it 'updates separate project configurations and leaves other auto-generated cop settings intact' do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'nested'))
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
      YAML
      File.write(File.join(dir, 'nested', '.rubocop.yml'), "inherit_from: ../.rubocop.yml\n")
      File.write(File.join(dir, 'example.rb'), "# wrold\nvalue='hello'\n")
      File.write(File.join(dir, 'nested', 'example.md'), "quuxify\n")
      command = [RbConfig.ruby, '-S', 'rubocop']
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', '--auto-gen-only-exclude', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, '.spellcheck.txt'))).to eq("wrold\n")
      expect(File.read(File.join(dir, 'nested', '.spellcheck.txt'))).to eq("quuxify\n")
      todo = File.read(File.join(dir, '.rubocop_todo.yml'))
      expect(todo).not_to include('Spellcheck/Spelling:')
      expect(todo).to include('Layout/SpaceAroundOperators:')
      output, errors, status = Open3.capture3(*command, '--only', 'Spellcheck/Spelling', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
    end
  end

  it 'uses an explicit configuration directory and creates no vocabulary until spelling offenses exist' do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'config'))
      configuration = File.join(dir, 'config', '.rubocop.yml')
      File.write(configuration, <<~YAML)
        plugins:
          - rubocop-spellcheck
        AllCops:
          NewCops: enable
          SuggestExtensions: false
      YAML
      File.write(File.join(dir, 'example.txt'), 'hello world')
      command = [RbConfig.ruby, '-S', 'rubocop', '--config', 'config/.rubocop.yml',
                 '--only', 'Spellcheck/Spelling', 'example.txt']
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.exist?(File.join(dir, 'config', '.spellcheck.txt'))).to be(false)
      expect(File.read(configuration)).not_to include('DictionaryFiles')
      File.write(File.join(dir, 'example.txt'), 'wrold')
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, 'config', '.spellcheck.txt'))).to eq("wrold\n")
      expect(File.exist?(File.join(dir, '.spellcheck.txt'))).to be(false)
      output, errors, status = Open3.capture3(*command, chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
    end
  end

  it 'rebuilds vocabulary from unsuppressed violations and preserves comments even when all entries become obsolete' do
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
              - .spellcheck.txt
      YAML
      vocabulary = File.join(dir, '.spellcheck.txt')
      File.write(vocabulary, "# Keep this comment.\nQuuxify\nobsoleteword\nhello\nsuppressedword\n")
      source = File.join(dir, 'example.rb')
      File.write(source, "# quuxify\nhello = 'zzzzzzzzzzzz'\n" \
                         "# rubocop:disable Spellcheck/Spelling\n# suppressedword\n" \
                         "# rubocop:enable Spellcheck/Spelling\n")
      command = [RbConfig.ruby, '-S', 'rubocop', '--only', 'Spellcheck/Spelling', 'example.rb']
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(vocabulary)).to eq("# Keep this comment.\nQuuxify\nzzzzzzzzzzzz\n")
      File.write(source, "# hello world\n")
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', '--only', 'Layout/LineLength', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(vocabulary)).to include('Quuxify')
      output, errors, status = Open3.capture3(*command, chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(vocabulary)).to include('Quuxify')
      output, errors, status = Open3.capture3(*command, '--auto-gen-config', chdir: dir)
      expect(status.success?).to be(true), "#{output}\n#{errors}"
      expect(File.read(vocabulary)).to eq("# Keep this comment.\n")
    end
  end

  it 'corrects Ruby string values with safe syntax while reporting identifiers without renaming them' do
    Dir.mktmpdir do |dir|
      fixtures = File.expand_path('fixtures/ruby_spelling', __dir__)
      FileUtils.cp(File.join(fixtures, 'input.rb'), File.join(dir, 'example.rb'))
      File.write(File.join(dir, '.rubocop.yml'), <<~YAML)
        plugins:
          - rubocop-spellcheck
        AllCops:
          NewCops: enable
          SuggestExtensions: false
        Spellcheck:
          DictionaryFiles:
            en:
              - en.dic
              - words.txt
        Spellcheck/Spelling:
          Ruby:
            Identifiers: true
      YAML
      %w[en.dic en.aff].each { |path| FileUtils.cp(File.expand_path("fixtures/#{path}", __dir__), dir) }
      File.write(File.join(dir, 'words.txt'), "isn't\n")
      command = [RbConfig.ruby, '-S', 'rubocop', '--only', 'Spellcheck/Spelling', '--cache', 'false', 'example.rb']
      output, errors, status = Open3.capture3(*command, '-a', chdir: dir)
      expect(status.exitstatus).to eq(1), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, 'example.rb'))).to eq(File.read(File.join(fixtures, 'input.rb')))
      output, errors, status = Open3.capture3(*command, '-A', chdir: dir)
      expect(status.exitstatus).to eq(1), "#{output}\n#{errors}"
      expected = File.read(File.join(fixtures, 'expected.rb'))
      expect(File.read(File.join(dir, 'example.rb'))).to eq(expected)
      expect(RuboCop::ProcessedSource.new(expected, 3.2).valid_syntax?).to be(true)
      output, errors, status = Open3.capture3(*command, '-A', '--format', 'json', chdir: dir)
      expect(status.exitstatus).to eq(1), "#{output}\n#{errors}"
      expect(File.read(File.join(dir, 'example.rb'))).to eq(expected)
      expect(JSON.parse(output).fetch('files').first.fetch('offenses').length).to eq(9)
    end
  end

  it 'corrects only unique suggestions with unsafe correction across source types and is stable on rerun' do
    Dir.mktmpdir do |dir|
      fixtures = File.expand_path('fixtures/autocorrect', __dir__)
      FileUtils.cp_r(File.join(fixtures, 'input'), File.join(dir, 'input'))
      %w[.rubocop.yml words.txt].each { |path| FileUtils.cp(File.join(fixtures, path), dir) }
      %w[en.dic en.aff].each { |path| FileUtils.cp(File.expand_path("fixtures/#{path}", __dir__), dir) }
      sources = fixture_contents(File.join(fixtures, 'input'))
      corrected = fixture_contents(File.join(fixtures, 'expected'))
      command = [RbConfig.ruby, '-S', 'rubocop', '--only', 'Spellcheck/Spelling',
                 '--cache', 'false', '--format', 'json', 'input']
      output, errors, status = Open3.capture3(*command, '-a', chdir: dir)
      expect(status.exitstatus).to eq(1), "#{output}\n#{errors}"
      expect(fixture_contents(File.join(dir, 'input'))).to eq(sources)
      output, errors, status = Open3.capture3(*command, '-A', chdir: dir)
      expect(status.exitstatus).to eq(1), "#{output}\n#{errors}"
      expect(JSON.parse(output).fetch('files').flat_map { |file| file.fetch('offenses') }
                            .count { |offense| offense.fetch('corrected') }).to be_positive
      expect(fixture_contents(File.join(dir, 'input'))).to eq(corrected)
      output, errors, status = Open3.capture3(*command, '-A', chdir: dir)
      expect(status.exitstatus).to eq(1), "#{output}\n#{errors}"
      remaining = JSON.parse(output).fetch('files').reject { |file| file.fetch('offenses').empty? }
      expect(remaining.map { |file| file.fetch('path') }).to eq(
        %w[input/ambiguous.txt input/example.adoc input/example.rb input/example.rdoc
           input/example.txt input/protected.md input/protected.txt input/rdoc_comments.rb input/typed.md]
      )
      expect(fixture_contents(File.join(dir, 'input'))).to eq(corrected)
    end
  end

  def fixture_contents(directory)
    Dir.glob('**/*', base: directory).select { |path| File.file?(File.join(directory, path)) }
       .to_h { |path| [path, File.read(File.join(directory, path))] }
  end

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
