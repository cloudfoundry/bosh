# Contributing to BOSH

When contributing a pull request, be sure to:
- Check the [BOSH Code Style](docs/code_style.md)
- See [Pull Request Workflow](docs/pull_request_workflow.md) for further details
- Submit your pull request against
the [**master**](https://github.com/cloudfoundry/bosh/tree/master) branch

## Contributor License Agreement

Follow these steps to make a contribution to any of CF open source repositories:

1. Ensure that you have completed our CLA Agreement for
   [individuals](http://cloudfoundry.org/pdfs/CFF_Individual_CLA.pdf) or
   [corporations](http://cloudfoundry.org/pdfs/CFF_Corporate_CLA.pdf).

1. Set your name and email (these should match the information on your submitted
   CLA)

```
git config --global user.name "Firstname Lastname"
git config --global user.email "your_email@example.com"
```

1. See [development docs](docs/README.md) to start contributing to BOSH.

## Creating a Local Development Release

1. Run `bundle exec rake release:create_dev_release`.

2. If you need a tarball release from this then you can run `bundle exec bosh
   create release --with-tarball /path/to/yaml/made/in/previous/step.yml`.

## Commit messages

Please follow [the rules of writing good Git commit
messages](https://chris.beams.io/posts/git-commit/#seven-rules):

- Separate subject from body with a blank line
- Limit the subject line to 50 characters
- Capitalize the subject line
- Do not end the subject line with a period
- Use the imperative mood in the subject line
- Wrap the body at 72 characters
- Use the body to explain what and why vs. how

In addition to those rules, we also like to include references to external
resources, such as Pivotal Tracker stories and GitHub issues. For example, at
the bottom of your commit messages:

```
[GH: Fixes #123, Related: #432, #111]
[finishes #3494307298](https://www.pivotaltracker.com/story/show/3494307298)
```

Also, if you're pairing or working with more people on your commit, we encourage
you to use the `Co-authored-by` line in order to attribute credit to everyone
that contributed. For example (yes you can have as many of those as you want):

```
Co-authored-by: Rob Boshman <rboshman@cloudfoundry.org>
Co-authored-by: Alice Boshington <aboshington@cloudfoundry.org>
```
