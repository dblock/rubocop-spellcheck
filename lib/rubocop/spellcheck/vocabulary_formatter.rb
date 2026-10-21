# frozen_string_literal: true

module RuboCop
  module Spellcheck
    # Collects auto-generation results in the parent process, even when investigations are cached.
    module VocabularyFormatter
      def file_started(file, options)
        @spellcheck_config_store = options.fetch(:config_store)
        super
      end

      def file_finished(file, offenses)
        spelling, others = offenses.partition { |offense| offense.cop_name == VocabularyConfig::COP }
        config = @spellcheck_config_store.for_file(file)
        if !spelling.empty? || regenerating?(file, config)
          @spellcheck_vocabularies ||= {}
          vocabulary = (@spellcheck_vocabularies[config.loaded_path] ||= Vocabulary.new(config))
          spelling.each { |offense| vocabulary.add(offense) }
        end
        super(file, others)
      end

      def finished(inspected_files)
        @spellcheck_vocabularies&.each_value(&:write)
        super
      end

      private

      def regenerating?(file, config)
        return false unless spelling_selected?
        return false unless File.exist?(File.join(config.base_dir_for_path_parameters, '.spellcheck.txt'))

        @spellcheck_cops ||= {}
        cop = (@spellcheck_cops[config.loaded_path] ||= RuboCop::Cop::Spellcheck::Spelling.new(config, @options))
        config.for_badge(cop.class.badge)['Enabled'] && cop.relevant_file?(file)
      end

      def spelling_selected?
        names = %w[Spellcheck Spellcheck/Spelling]
        (!@options[:only] || @options[:only].intersect?(names)) && !@options.fetch(:except, []).intersect?(names)
      end
    end
  end
end

RuboCop::Formatter::DisabledConfigFormatter.prepend(RuboCop::Spellcheck::VocabularyFormatter)
