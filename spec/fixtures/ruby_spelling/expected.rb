# frozen_string_literal: true

wrold = 'world'
Wrold = "😀 world"
@wrold = "world #{wrold} world"
@@wrold = %q{world}
$wrold = %w[world hello]
hello.wrold
world = 'isn\'t'
hello = "isn't"
hello = %q'isn\'t'
hello = %Q'isn\'t'
hello = %w'isn\'t'
hello = "\u{68 65 6c 6c 6f 20 77 72 6f 6c 64}"
world = <<~COMMENT
  😀 world
  world
COMMENT
hello = <<~'COMMENT'
  world
  \world
COMMENT
hello = <<~WORLD
  WROLD
WORLD
world = [:wrold, :"wrold", /wrold/, `wrold`, { wrold: 1 }]
# rubocop:disable Spellcheck/Spelling
typpo = 'wrold'
# rubocop:enable Spellcheck/Spelling
