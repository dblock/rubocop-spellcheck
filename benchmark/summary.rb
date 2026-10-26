# frozen_string_literal: true

require_relative 'corpus'

module SpellcheckBenchmark
  # Summarizes raw trials without treating abstentions as correct answers.
  module Summary
    def self.median(values)
      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
    end

    def self.quality(suggestions)
      total = Corpus::TYPOS.size
      { total: total, coverage: suggestions.count { |_word, values| !values.empty? },
        top1: Corpus::TYPOS.count { |word, expected| suggestions.fetch(word).first == expected },
        top3: Corpus::TYPOS.count { |word, expected| suggestions.fetch(word).include?(expected) } }
    end

    def self.timings(trials, phase)
      values = trials.map { |trial| trial.fetch(phase) }
      return nil if values.first.fetch('operations').zero?

      median(values.map { |value| value.fetch('milliseconds') * 1000 / value.fetch('operations') })
    end

    def self.engine(trials)
      raise 'Cannot summarize failed trials' unless trials.all? { |trial| trial.fetch('status') == 'ok' }

      { initialization_ms: median(trials.map { |trial| trial.fetch('initialization_ms') }),
        microseconds_per_word: %w[lookup_cold lookup_warm suggestion_cold suggestion_warm].to_h do |phase|
          [phase, timings(trials, phase)]
        end, quality: quality(trials.first.fetch('suggestion_cold').fetch('values')),
        stable_outputs: stable?(trials) }
    end

    def self.stable?(trials)
      %w[lookup_cold lookup_warm suggestion_cold suggestion_warm].all? do |phase|
        trials.map { |trial| trial.fetch(phase).fetch('values') }.uniq.size == 1
      end
    end

    def self.lookup_values(trials)
      trials.select { |trial| trial['trial'] == 1 && trial.dig('lookup_cold', 'values') }
            .to_h { |trial| [trial.fetch('engine'), trial.fetch('lookup_cold').fetch('values')] }
    end

    def self.disagreements(trials)
      verdicts = lookup_values(trials)
      verdicts.values.first.keys.filter_map do |word|
        values = verdicts.transform_values { |words| words.fetch(word) }
        [word, values] if values.values.uniq.size > 1
      end.to_h
    end
  end
end
