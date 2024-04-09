### To publish a new version

1. Update the `lib/common/version.rb` to your desired version.  Once the gem is published, this should be reverted back to `0.0.0` for bosh-director usage
2. Change to the same directory as `bosh_common.gemspec`
3. `gem build bosh_common.gemspec`
4. Verify that it is the version you expect and the metadata looks good using `gem specification bosh_common-<X.Y.Z>.gem`
4. Acquire an API key for rubygems.org
5. `GEM_HOST_API_KEY="<KEY>" gem push bosh_common-<X.Y.Z>.gem`
6. 👀 https://rubygems.org/gems/bosh_common to make sure it all worked ok
7. `git restore lib/common/version.rb` to get back to `0.0.0` for bosh director usage
8. `rm bosh_common-<X.Y.Z>.gem`
9. Optionally commit your other changes