require "rspec"
require "blobstore_client"

def asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end
