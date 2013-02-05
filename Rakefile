task :default => :spec

desc "run spec tests"
task :spec do
  sh("./ci_build.rb")
end

import File.join("rake","stemcell.rake")
import File.join("rake","bat.rake")
import File.join("rake","gem.rake")
import File.join("rake","integration_tests.rake")
import File.join("rake","migrations.rake")
