task :default => :spec

desc "build and install the bosh cli gem"
task :build do
  sh("cd cli && bundle exec rake install")
end

desc "run spec tests"
task :spec do
  sh("./ci_build.rb")
end

import File.join("rake","stemcell.rake")
import File.join("rake","bat.rake")
