require 'blue-shell'

BlueShell.timeout = 180 # the cli can be pretty slow

RSpec.configure do |c|
  c.include(BlueShell::Matchers)
end
