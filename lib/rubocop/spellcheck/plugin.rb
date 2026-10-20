# frozen_string_literal: true

require 'lint_roller'

module RuboCop
  module Spellcheck
    # Registers the extension and its defaults with RuboCop.
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: 'rubocop-spellcheck',
          version: VERSION,
          homepage: 'https://github.com/dblock/rubocop-spellcheck',
          description: 'Spellcheck Ruby comments, Markdown prose, and plain text.'
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path, config_format: :rubocop,
          value: Pathname.new(__dir__).join('../../../config/default.yml')
        )
      end
    end
  end
end
