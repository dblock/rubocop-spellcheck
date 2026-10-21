# frozen_string_literal: true

RSpec.describe RuboCop::Spellcheck::VocabularyConfig do
  def update(source, dictionaries = { 'en' => ['en.dic', '.spellcheck.txt'] })
    Dir.mktmpdir do |dir|
      path = File.join(dir, '.rubocop.yml')
      File.write(path, source)
      described_class.new(path, section: 'Spellcheck').updated(dictionaries)
    end
  end

  it 'inserts department dictionaries without rewriting comments or unrelated settings' do
    source = "# Project settings\nSpellcheck:\n    # Keep this comment.\n    Enabled: true\n" \
             "Layout/LineLength:\n  Max: 100\n"
    result = update(source)
    expect(result).to include("# Project settings\n", '    # Keep this comment.', "Layout/LineLength:\n  Max: 100\n")
    expect(YAML.safe_load(result).fetch('Spellcheck')).to eq(
      'Enabled' => true, 'DictionaryFiles' => { 'en' => ['en.dic', '.spellcheck.txt'] }
    )
  end

  it 'replaces inline dictionary mappings without removing following settings' do
    source = "Spellcheck:\n  DictionaryFiles: {en: [en.dic]}\n  Enabled: true\n"
    result = update(source)
    expect(YAML.safe_load(result).dig('Spellcheck', 'Enabled')).to be(true)
    expect(YAML.safe_load(result).dig('Spellcheck', 'DictionaryFiles', 'en')).to eq(['en.dic', '.spellcheck.txt'])
  end

  it 'retains all languages when writing a generated dictionary mapping' do
    files = { 'en' => ['en.dic', '.spellcheck.txt'], 'de' => ['de.dic', '.spellcheck.txt'] }
    expect(YAML.safe_load(update("Spellcheck:\n  DictionaryFiles:\n    en: [en.dic]\n", files))
               .dig('Spellcheck', 'DictionaryFiles')).to eq(files)
  end

  it 'rejects flow-style department configuration instead of overwriting it' do
    expect { update('Spellcheck: {DictionaryFiles: {en: [en.dic]}}') }
      .to raise_error(RuboCop::ValidationError, /non-block Spellcheck/)
  end

  it 'replaces dictionaries at the end of a file without a final newline' do
    result = update("Spellcheck:\n  DictionaryFiles:\n    en: [en.dic]")
    expect(YAML.safe_load(result).dig('Spellcheck', 'DictionaryFiles', 'en')).to eq(['en.dic', '.spellcheck.txt'])
  end

  it 'inserts settings inside an anchored department without disturbing the anchor' do
    result = update("Spellcheck: &spelling\n  Enabled: true\n")
    expect(result).to start_with("Spellcheck: &spelling\n")
    expect(YAML.safe_load(result).dig('Spellcheck', 'DictionaryFiles', 'en')).to eq(['en.dic', '.spellcheck.txt'])
  end

  it 'appends the department before an explicit YAML document end marker' do
    result = update("---\nAllCops:\n  NewCops: enable\n...\n")
    expect(YAML.safe_load(result).dig('Spellcheck', 'DictionaryFiles', 'en')).to eq(['en.dic', '.spellcheck.txt'])
    expect(result).to end_with("...\n")
  end

  it 'surfaces configuration that cannot be edited as literal YAML' do
    expect { update("Spellcheck:\n  <% if true %>\n  DictionaryFiles: {}\n") }
      .to raise_error(RuboCop::ValidationError, /Cannot update spelling configuration/)
  end
end
