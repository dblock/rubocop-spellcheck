# frozen_string_literal: true

require 'spec_helper'
require_relative '../../benchmark/engines'

RSpec.describe SpellcheckBenchmark::Engines do
  describe '.kotoshu_auto' do
    it 'refuses to report Ruby fallback as a Rust measurement' do
      allow(Kotoshu::Native).to receive(:available?).and_return(false)

      expect { described_class.build('kotoshu_auto') }
        .to raise_error(Kotoshu::Native::Unavailable, /auto selected Ruby/)
    end

    context 'when the automatic backend resolves to native' do
      let(:native) { instance_double(Kotoshu::NativeBackend, correct?: true) }

      before do
        allow(Kotoshu::Native).to receive(:available?).and_return(true)
        stub_const('Kotoshu::Native::VERSION', 'test-version')
        allow(Kotoshu::NativeBackend).to receive(:resolve)
          .with(hash_including(backend: 'auto')).and_return(native)
      end

      it 'records the selected Rust engine and delegates lookups to it' do
        engine = described_class.build('kotoshu_auto')

        expect(engine.metadata).to include(requested: 'auto', selected: 'native', native_version: 'test-version')
        expect(engine.lookup.call('native-only-probe')).to be(true)
      end
    end
  end
end
