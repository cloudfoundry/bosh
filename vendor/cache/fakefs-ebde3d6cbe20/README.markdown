FakeFS [![build status](https://secure.travis-ci.org/defunkt/fakefs.png)](https://secure.travis-ci.org/defunkt/fakefs)
======

Mocha is great. But when your library is all about manipulating the
filesystem, you really want to test the behavior and not the implementation.

If you're mocking and stubbing every call to FileUtils or File, you're
tightly coupling your tests with the implementation.

``` ruby
def test_creates_directory
  FileUtils.expects(:mkdir).with("directory").once
  Library.add "directory"
end
```

The above test will break if we decide to use `mkdir_p` in our code. Refactoring
code shouldn't necessitate refactoring tests.

With FakeFS:

``` ruby
def test_creates_directory
  Library.add "directory"
  assert File.directory?("directory")
end
```

Woot.


Usage
-----

``` ruby
require 'fakefs'

# That's it.
```

Don't Fake the FS Immediately
-----------------------------

``` ruby
gem "fakefs", :require => "fakefs/safe"

require 'fakefs/safe'

FakeFS.activate!
# your code
FakeFS.deactivate!

# or
FakeFS do
  # your code
end
```

Rails
-----

If you are using fakefs in a rails project with bundler, you'll probably want
to specify the following in your Gemfile:

``` ruby
gem "fakefs", :require => "fakefs/safe"
```


RSpec
-----

The above approach works with RSpec as well. In addition you may include
FakeFS::SpecHelpers to turn FakeFS on and off in a given example group:

``` ruby
require 'fakefs/spec_helpers'

describe "my spec" do
  include FakeFS::SpecHelpers
end
```

See `lib/fakefs/spec_helpers.rb` for more info.


Integrating with other filesystem libraries
--------------------------------------------
Third-party libraries may add methods to filesystem-related classes. FakeFS
doesn't support these methods out of the box, but you can define fake versions
yourself on the equivalent FakeFS classes. For example,
[FileMagic](https://rubygems.org/gems/ruby-filemagic) adds `File#content_type`.
A fake version can be provided as follows:

``` ruby
module FakeFS
  class File
    def content_type
      'fake/file'
    end
  end
end
```

How is this different than MockFS?
----------------------------------

FakeFS provides a test suite and works with symlinks. It's also strictly a
test-time dependency: your actual library does not need to use or know about
FakeFS.


Caveats
-------

FakeFS internally uses the `Pathname` and `FileUtils` constants. If you use
these in your app, be certain you're properly requiring them and not counting
on FakeFS' own require.

As of v0.5.0, FakeFS's current working directory (i.e. `Dir.pwd`) is
independent of the real working directory. Previously if the real working
directory were, for example, `/Users/donovan/Desktop`, then FakeFS would use
that as the fake working directory too, even though it most likely didn't
exist. This caused all kinds of subtle bugs. Now the default working directory
is the only thing that is guaranteed to exist, namely the root (i.e. `/`). This
may be important when upgrading from v0.4.x to v0.5.x, especially if you depend
on the real working directory while using FakeFS.


Speed?
------

<http://gist.github.com/156091>


Installation
------------

### [RubyGems](http://rubygems.org/)

    $ gem install fakefs


Contributing
------------

Once you've made your great commits:

1. [Fork][0] FakeFS
2. Create a topic branch - `git checkout -b my_branch`
3. Push to your branch - `git push origin my_branch`
5. Open a [Pull Request][1]
5. That's it!

Meta
----

* Code: `git clone git://github.com/defunkt/fakefs.git`
* Home: <http://github.com/defunkt/fakefs>
* Docs: <http://rdoc.info/github/defunkt/fakefs>
* Bugs: <http://github.com/defunkt/fakefs/issues>
* Test: <http://travisci.org/#!/defunkt/fakefs>
* Gems: <http://rubygems.org/gems/fakefs>

[0]: http://help.github.com/forking/
[1]: http://help.github.com/send-pull-requests/

Releasing
---------

1. Update version in lib/fakefs/version.rb
2. Commit it
3. rake publish
