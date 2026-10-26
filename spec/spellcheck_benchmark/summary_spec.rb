# frozen_string_literal: true

require 'spec_helper'
require_relative '../../benchmark/summary'

RSpec.describe SpellcheckBenchmark::Summary do
  describe '.median' do
    it 'selects the middle trial independently of trial order' do
      expect(described_class.median([9, 1, 3])).to eq(3)
    end

    it 'averages the middle pair for an even number of trials' do
      expect(described_class.median([9, 1, 7, 3])).to eq(5)
    end
  end

  describe '.quality' do
    it 'counts abstentions as misses and distinguishes first from later suggestions' do
      suggestions = SpellcheckBenchmark::Corpus::TYPOS.to_h { |word, _expected| [word, []] }
      suggestions['teh'] = %w[ten the]
      expect(described_class.quality(suggestions)).to eq(total: 20, coverage: 1, top1: 0, top3: 1)
    end
  end

  describe '.timings' do
    it 'normalizes each trial batch to microseconds per word before taking the median' do
      trials = [{ 'lookup' => { 'operations' => 10, 'milliseconds' => 2 } },
                { 'lookup' => { 'operations' => 100, 'milliseconds' => 40 } }]
      expect(described_class.timings(trials, 'lookup')).to eq(300)
    end

    it 'reports an unsupported operation as absent rather than zero time' do
      expect(described_class.timings([{ 'lookup' => { 'operations' => 0 } }], 'lookup')).to be_nil
    end
  end

  describe '.engine' do
    it 'refuses to summarize unsuccessful trials' do
      expect { described_class.engine([{ 'status' => 'error' }]) }.to raise_error('Cannot summarize failed trials')
    end
  end
end
