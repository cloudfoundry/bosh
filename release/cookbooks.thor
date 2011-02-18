require "bundler/setup"

class Cookbooks < Thor
  include Thor::Actions

  COOKBOOKS_PATH = File.expand_path("../cookbooks", __FILE__)

  desc "metadata", "generate metadata"
  def metadata
    fork { exec "bundle exec knife cookbook metadata -a -o cookbooks #{COOKBOOKS_PATH}" }
    Process.wait
  end

  desc "create COOKBOOK", "create a new cookbook"
  def create(cookbook)
    fork { exec "bundle exec knife cookbook create #{cookbook} -o cookbooks #{COOKBOOKS_PATH}" }
    Process.wait
  end
end