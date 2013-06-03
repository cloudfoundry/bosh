#!/usr/bin/env ruby
#

require_relative('../rake/lib/helpers/build/ami')

unless ARGV.length == 1
  puts "usage: #{$0} </path/to/stemcell.tgz>"
  exit(1)
end

stemcell_tgz = File.expand_path(ARGV[0])
ami = Bosh::Helpers:Ami.new(stemcell_tgz)
ami.publish
