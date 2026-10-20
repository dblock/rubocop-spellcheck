# frozen_string_literal: true

RSpec.describe RuboCop::Spellcheck::Checker do
  let(:root) { File.expand_path('../../fixtures', __dir__) }

  it 'keeps accented English words whole and ignores numeric identifiers' do
    checker = described_class.new
    words = checker.misspellings("café Pokémon 'wrold' 4th 0x860c4604fe1125ea43")
    expect(words.map(&:first)).to include('wrold')
    expect(words.map(&:first)).not_to include('caf', 'Pok', 'mon', "'wrold'", 'th', 'fe')
    expect(words.assoc('wrold').last).to eq(14)
  end

  def checker(files = { 'en' => ['en.dic'] }, directory = root)
    described_class.new(dictionary_files: files, base_directory: directory)
  end

  it 'uses real Kotoshu tokenization, affixes, and suggestions' do
    instance = checker
    expect(instance.misspellings('hello features wrold')).to eq([['wrold', 15]])
    expect(instance.suggestions('wrold')).to eq(['world'])
  end

  it 'defaults to gem-packaged English without Kotoshu setup or cache resolution' do
    allow(Kotoshu::ResourceManager).to receive(:resolve)
    instance = described_class.new
    expect(instance.misspellings('hello world')).to eq([])
    expect(instance.misspellings('wrold')).to eq([['wrold', 0]])
    expect(Kotoshu::ResourceManager).not_to have_received(:resolve)
  end

  it 'adds vocabulary only when the primary dictionary is explicitly retained' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'words.txt')
      File.write(path, "# Vocabulary\n\nWrold\n")
      files = { 'en' => [File.join(root, 'en.dic'), path] }
      expect(checker(files).misspellings('hello wrold')).to eq([])
      expect(checker('en' => [path]).misspellings('hello wrold')).to eq([['hello', 0]])
      expect(checker.misspellings('hello wrold')).to eq([['wrold', 6]])
    end
  end

  it 'combines languages without retaining implicit English or duplicating occurrences' do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'de.txt'), "hallo\n")
      File.write(File.join(dir, 'fr.txt'), "bonjour\n")
      instance = checker({ 'de' => ['de.txt'], 'fr' => ['fr.txt'] }, dir)
      expect(instance.misspellings('hallo bonjour hello')).to eq([['hello', 14]])
    end
  end

  it 'resolves gem-relative paths and rejects missing gems, files, and traversal' do
    instance = checker('en' => ['gem:rubocop-spellcheck/data/en/en.dic'])
    expect(instance.misspellings('hello world')).to eq([])
    %w[gem:no-such-spellcheck-gem/data/en.dic gem:rubocop-spellcheck/../outside.dic
       gem:rubocop-spellcheck missing.dic words.json].each do |path|
      expect { checker('en' => [path]) }.to raise_error(RuboCop::ValidationError)
    end
  end

  it 'fingerprints every configured word list, dictionary, and affix file' do
    Dir.mktmpdir do |dir|
      %w[en.dic en.aff].each { |name| FileUtils.cp(File.join(root, name), dir) }
      File.write(File.join(dir, 'words.txt'), "custom\n")
      files = { 'en' => %w[en.dic words.txt] }
      %w[words.txt en.aff en.dic].each do |name|
        before = checker(files, dir).checksum
        path = File.join(dir, name)
        content = File.read(path)
        File.write(path, name == 'en.dic' ? content.sub('hello', 'hullo') : "#{content}\n")
        expect(checker(files, dir).checksum).not_to eq(before)
      end
    end
  end

  it 'rejects malformed maps and empty language lists explicitly' do
    [{}, [], false, { 'en' => [] }, { 'en' => [''] }, { 'en' => 'words.txt' },
     { 'bad language' => ['en.dic'] }].each do |files|
      expect { checker(files) }.to raise_error(RuboCop::ValidationError, /DictionaryFiles/)
    end
  end

  it 'requires matching affix files and rejects phrases in text dictionaries' do
    Dir.mktmpdir do |dir|
      FileUtils.cp(File.join(root, 'en.dic'), dir)
      expect { checker({ 'en' => ['en.dic'] }, dir) }.to raise_error(RuboCop::ValidationError, /en.aff/)
      File.write(File.join(dir, 'words.txt'), "two words\n")
      expect { checker({ 'en' => ['words.txt'] }, dir) }.to raise_error(RuboCop::ValidationError, /one word/)
    end
  end
end
