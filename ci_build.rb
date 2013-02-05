#!/usr/bin/env ruby

def bundle_without
  ENV['HAS_JOSH_K_SEAL_OF_APPROVAL'] ? "--local --without development" : "" # aka: on travis
end

system("bundle check || bundle #{bundle_without}")  || raise("Bundler is required.")

if ENV['SUITE'] == "integration"
  system "bundle exec rake spec:integration" || raise("failed to run spec/integration")
else
  system "bundle exec rake spec:unit" || raise("failed to run unit tests")
end
