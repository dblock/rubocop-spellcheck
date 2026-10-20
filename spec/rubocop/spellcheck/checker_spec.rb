# frozen_string_literal: true

RSpec.describe RuboCop::Spellcheck::Checker do
  let(:bundle) { fixture_bundle }

  before do
    allow(Kotoshu::ResourceManager).to receive(:resolve).with(language: 'en', want: [:spelling])
                                                        .and_return(bundle)
  end

  def checker(files = [])
    described_class.new(language: 'en', dictionary_files: files)
  end

  it 'uses real Kotoshu tokenization, affix lookup, and suggestions' do
    instance = checker
    expect(instance.misspellings('hello features wrold')).to eq([['wrold', 15]])
    expect(instance.suggestions('wrold')).to eq(['world'])
  end

  it 'loads project words without changing the Kotoshu global configuration or dictionary' do
    original = Kotoshu.configuration
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'words.txt')
      File.write(path, "# Project vocabulary\n\nWrold\n")
      expect(checker([path]).misspellings('hello wrold')).to eq([])
      expect(checker.misspellings('hello wrold')).to eq([['wrold', 6]])
    end
    expect(Kotoshu.configuration).to equal(original)
    expect(bundle.dictionary.lookup('wrold')).to be(false)
  end

  it 'changes its cache fingerprint when project vocabulary changes' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'words.txt')
      File.write(path, "first\n")
      before = checker([path]).checksum
      File.write(path, "other\n")
      expect(checker([path]).checksum).not_to eq(before)
    end
  end

  it 'changes its fingerprint when Hunspell affix rules change' do
    Dir.mktmpdir do |dir|
      aff = File.join(dir, 'en.aff')
      File.write(aff, File.read(bundle.dictionary.aff_path))
      allow(bundle.dictionary).to receive(:aff_path).and_return(aff)
      before = checker.checksum
      File.write(aff, "#{File.read(aff)}\n# changed\n")
      expect(checker.checksum).not_to eq(before)
    end
  end

  it 'gives an actionable error without downloading resources when setup is missing' do
    allow(Kotoshu::ResourceManager).to receive(:resolve).and_raise(Kotoshu::ResourceNotSetupError.new('en', 'spelling'))
    allow(Kotoshu).to receive(:setup)
    expect { checker }.to raise_error(RuboCop::ValidationError, /bundle exec kotoshu setup en --want spelling/)
    expect(Kotoshu).not_to have_received(:setup)
  end

  it 'rejects invalid settings and unreadable project dictionaries explicitly' do
    expect do
      described_class.new(language: '', dictionary_files: [])
    end.to raise_error(RuboCop::ValidationError, /Language/)
    expect { checker('words.txt') }.to raise_error(RuboCop::ValidationError, /DictionaryFiles/)
    expect { checker(['missing-words.txt']) }.to raise_error(RuboCop::ValidationError, /Cannot read/)
  end

  it 'rejects phrases rather than silently ignoring invalid dictionary entries' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'words.txt')
      File.write(path, "two words\n")
      expect { checker([path]) }.to raise_error(RuboCop::ValidationError, /one word per line/)
    end
  end
end
