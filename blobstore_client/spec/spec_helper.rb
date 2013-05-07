require "rspec"
require "blobstore_client"

require 'coveralls'
Coveralls.wear!

def asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end
