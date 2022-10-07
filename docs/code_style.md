# Code Style

We use [RuboCop](http://batsov.com/rubocop/) which generally enforces the [Ruby Style Guide](https://github.com/bbatsov/ruby-style-guide).
We use a [`.rubocop.yml` file](https://github.com/cloudfoundry/bosh/blob/master/src/.rubocop.yml) for customized style configuration.

The current strategy is to fix the offenses either manually (if your changes are small enough) or fix them automated by running `rubocop --autocorrect` on the file(s) you changed. However, if you decide to run `rubocop --autocorrect` on the whole file(s), make sure to have a separate commit for the reformatting so that your actual commit is not polluted with code reformatting. You could do this in one of two ways:

1. skipping the hook
  - `git commit --no-verify` for your code change
  - `rubocop --autocorrect` on the file you changed
  - do the commit for the reformatted file
  
2. reformatting the file before you commit your changes
  - stash your changes
  - `rubocop --autocorrect` on the file you're about to change
  - do the commit for the reformatted file
  - reapply your changes
  - `rubocop --autocorrect` on the file
  - commit your changes
  
It's currently not possible to run `rubocop -a` on the whole repo since it's breaking some of our tests and makes it difficult for feature branches to be rebased onto master.

Our code style is still evolving, however `rake rubocop` is run by Travis so making these pass will improve the chances that the pull request will be accepted.
