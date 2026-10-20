# frozen_string_literal: true

require_relative '../../../script/update_resources'

RSpec.describe RuboCop::Spellcheck::ResourceUpdater do
  let(:revision) { 'a' * 40 }
  let(:url) { "https://raw.githubusercontent.com/kotoshu/dictionaries/#{revision}/en/spelling" }
  let(:root) { Dir.mktmpdir }
  let(:updater) { described_class.new(root) }

  around do |example|
    FileUtils.mkdir_p(File.join(root, 'data/en'))
    %w[en.aff en.dic LICENSE README.md].each { |name| File.write(File.join(root, 'data/en', name), 'old') }
    File.write(File.join(root, 'rubocop-spellcheck.gemspec'), "  spec.add_dependency 'kotoshu', '~> 1.0.8'\n")
    example.run
  ensure
    FileUtils.remove_entry(root)
  end

  before do
    allow(updater).to receive(:fetch).with('https://rubygems.org/api/v1/gems/kotoshu.json')
                                     .and_return('{"version":"1.2.3"}')
    allow(updater).to receive(:fetch).with('https://api.github.com/repos/kotoshu/dictionaries/commits/v1')
                                     .and_return({ sha: revision }.to_json)
    %w[index.aff index.dic license].each do |name|
      allow(updater).to receive(:fetch).with("#{url}/#{name}").and_return("new #{name}\n")
    end
    allow(updater).to receive(:puts)
  end

  it 'updates the stable gem requirement, pinned dictionary, full license, and checksums together' do
    updater.run
    expect(File.read(File.join(root, 'rubocop-spellcheck.gemspec'))).to include("'~> 1.2.3'")
    expect(File.read(File.join(root, 'data/en/LICENSE'))).to eq("new license\n")
    provenance = File.read(File.join(root, 'data/en/README.md'))
    expect(provenance).to include(revision, Digest::SHA256.hexdigest("new index.dic\n"))
  end

  it 'leaves every file untouched when no upstream content or version changes' do
    updater.run
    paths = Dir[File.join(root, '**', '*')].select { |path| File.file?(path) }
    original = paths.to_h { |path| [path, [File.binread(path), File.mtime(path)]] }
    updater.run
    expect(paths.to_h { |path| [path, [File.binread(path), File.mtime(path)]] }).to eq(original)
  end

  it 'does not write partial updates when a download fails' do
    allow(updater).to receive(:fetch).with("#{url}/license").and_raise('HTTP 503')
    expect { updater.run }.to raise_error('HTTP 503')
    expect(File.read(File.join(root, 'data/en/en.dic'))).to eq('old')
    expect(File.read(File.join(root, 'rubocop-spellcheck.gemspec'))).to include("'~> 1.0.8'")
  end

  it 'rejects prereleases rather than updating the dependency' do
    allow(updater).to receive(:fetch).with('https://rubygems.org/api/v1/gems/kotoshu.json')
                                     .and_return('{"version":"2.0.0.rc1"}')
    expect { updater.run }.to raise_error(/Expected a stable/)
  end

  it 'refreshes license-only changes and keeps the dependency unchanged when already current' do
    updater.run
    File.write(File.join(root, 'data/en/LICENSE'), 'old license')
    updater.run
    expect(File.read(File.join(root, 'data/en/LICENSE'))).to eq("new license\n")
  end

  it 'updates Kotoshu independently without repinning unchanged dictionary contents' do
    updater.run
    provenance = File.read(File.join(root, 'data/en/README.md'))
    allow(updater).to receive(:fetch).with('https://rubygems.org/api/v1/gems/kotoshu.json')
                                     .and_return('{"version":"2.1.0"}')
    updater.run
    expect(File.read(File.join(root, 'rubocop-spellcheck.gemspec'))).to include("'~> 2.1.0'")
    expect(File.read(File.join(root, 'data/en/README.md'))).to eq(provenance)
  end
end
