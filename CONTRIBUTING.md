# Contributing to BOSH

## Contributor License Agreement

Follow these steps to make a contribution to any of our open source repositories:

1. Ensure that you have completed our CLA Agreement for
   [individuals](http://www.cloudfoundry.org/individualcontribution.pdf) or
   [corporations](http://www.cloudfoundry.org/corpcontribution.pdf).

1. Set your name and email (these should match the information on your submitted CLA)

        git config --global user.name "Firstname Lastname"
        git config --global user.email "your_email@example.com"

## General Workflow

Follow these steps to make a contribution to any of our open source repositories:

1. Fork the repository

1. Create a feature branch (`git checkout -b better_bosh`)
    * Run the tests to ensure that your local environment is
  	  working `bundle && bundle exec rake` (this may take a while)
1. Make changes on the branch:
    * Adding a feature
      1. Add specs for the new feature
      1. Make the specs pass
    * Fixing a bug
      1. Add a spec/specs which exercises the bug
      1. Fix the bug, making the specs pass
    * Refactoring existing functionality
      1. Change the implementation
      1. Ensure that specs still pass
        * If you find yourself changing specs after a refactor, consider
          refactoring the specs first

1. Push to your fork (`git push origin better_bosh`) and submit a pull request selecting `develop` as the target branch

We favor pull requests with very small, single commits with a single purpose.

Your pull request is much more likely to be accepted if:

* Your pull request includes tests

* Your pull request is small and focused with a clear message that conveys the intent of your change.

## Code Style

As part of the `spec:unit` task we run [RuboCop](http://batsov.com/rubocop/),
which generally enforces the [Ruby Style Guide](https://github.com/bbatsov/ruby-style-guide).

We have a number of exceptions (see the various `.rubocop.yml` files),
and our style is still evolving, however `rake rubocop` is run by Travis
so making these pass will improve the chances that the pull request will
be accepted.
