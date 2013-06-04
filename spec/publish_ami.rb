#!/usr/bin/env ruby
#

unless ARGV.length == 1
  puts "usage: #{$0} </path/to/stemcell.tgz>"
  exit(1)
end

stemcell_tgz = File.expand_path(ARGV[0])

require_relative '../rake/lib/helpers/candidate_artifacts'

candidate_artifacts = Bosh::Helpers::CandidateArtifacts.new(stemcell_tgz)
candidate_artifacts.publish
