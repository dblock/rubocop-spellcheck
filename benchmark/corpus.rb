# frozen_string_literal: true

module SpellcheckBenchmark
  # Small diagnostic set, not a representative language accuracy evaluation.
  module Corpus
    SEED = 20_261_026
    SAMPLE_SIZE = 1000
    PROBES = %w[hello Hello HELLO hElLo London london LONDON iPhone IPHONE
                café naïve résumé can't can’t children's children’s running
                walked unhappy dictionaries spellcheck xyzzyq teh brwn grammer].freeze
    TYPOS = {
      'teh' => 'the', 'brwn' => 'brown', 'grammer' => 'grammar', 'recieve' => 'receive',
      'seperate' => 'separate', 'definately' => 'definitely', 'occured' => 'occurred',
      'untill' => 'until', 'helo' => 'hello', 'wrold' => 'world', 'speling' => 'spelling',
      'langauge' => 'language', 'documment' => 'document', 'commment' => 'comment',
      'jumsp' => 'jumps', 'adress' => 'address', 'accomodate' => 'accommodate',
      'becuase' => 'because', 'wierd' => 'weird', 'Thier' => 'Their'
    }.freeze

    def self.lookups(words)
      (words.sample(SAMPLE_SIZE, random: Random.new(SEED)) + PROBES + TYPOS.keys).uniq
    end
  end
end
