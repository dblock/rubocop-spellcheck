# frozen_string_literal: true

wrold = 'wrold'
Wrold = "😀 wro\u006cd"
@wrold = "wrold #{wrold} wrold"
@@wrold = %q{wrold}
$wrold = %w[wrold hello]
hello.wrold
world = 'isnt'
hello = "isnt"
hello = %q'isnt'
hello = %Q'isnt'
hello = %w'isnt'
hello = "\u{68 65 6c 6c 6f 20 77 72 6f 6c 64}"
world = <<~COMMENT
  😀 wrold
  wro\u{006c 0064}
COMMENT
hello = <<~'COMMENT'
  wrold
  \wrold
COMMENT
hello = <<~WORLD
  WROLD
WORLD
world = [:wrold, :"wrold", /wrold/, `wrold`, { wrold: 1 }]
# rubocop:disable Spellcheck/Spelling
typpo = 'wrold'
# rubocop:enable Spellcheck/Spelling
