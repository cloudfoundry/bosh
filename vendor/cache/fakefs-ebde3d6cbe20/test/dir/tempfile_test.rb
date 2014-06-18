require 'test_helper'
require 'tempfile'

class TempfileTest < Test::Unit::TestCase
  include FakeFS

  if RUBY_VERSION >= '2.1'
    def test_should_not_raise_error
      FakeFS do
        assert_nothing_raised do
          FileUtils.mkdir_p('/tmp')
          Tempfile.open('test')
        end
      end
    end
  end
end
