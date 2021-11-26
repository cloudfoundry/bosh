# Pull Request Workflow

Follow these steps to make a contribution to any of CF open source repositories:

1. Fork the repository

1. Update submodules (`git submodule update --init`)

1. Create a feature branch (`git checkout -b better_bosh`)
    * Run the tests to ensure that your local environment is working `bundle && bundle exec rake` (this may take a while)

1. Make changes on the branch:
    * Adding a feature
      1. Add tests for the new feature
      1. Make the tests pass
    * Fixing a bug
      1. Add a test/tests which exercises the bug
      1. Fix the bug, making the tests pass
    * Refactoring existing functionality
      1. Change the implementation
      1. Ensure that tests still pass
        * If you find yourself changing tests after a refactor, consider refactoring the tests first

  See [running tests](running_tests.md) to determine which test suite to run. We expect you to run the unit tests.

1. Push to your fork (`git push origin better_bosh`) and submit a pull request selecting `master` as the target branch

We favor pull requests with very small, single commits with a single purpose.

Your pull request is much more likely to be accepted if:

* Your pull request includes tests
* Your pull request is small and focused with a clear message that conveys the intent of your change.
