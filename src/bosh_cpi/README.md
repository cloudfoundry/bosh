# To run tests
```
$ bundle exec rspec spec
```

# CI
https://main.bosh-ci.cf-app.com/teams/main/pipelines/bosh:cpi-ruby

#Rubygems
https://rubygems.org/gems/bosh_cpi


## Developer

```
git clean -xfd # remove old gems
vim version # bump version number
gem build *.gemspec
gem push bosh_cpi-*.gem
```
