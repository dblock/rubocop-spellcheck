# frozen_string_literal: true

require 'spec_helper'
require_relative '../../benchmark/resources'

RSpec.describe SpellcheckBenchmark::Resources do
  it 'rejects changed resource content' do
    expect { described_class.verify_file!(__FILE__, 'incorrect') }.to raise_error(/Missing or changed/)
  end
end
