require 'cloud'
require 'bosh/cpi'

# add the spec/support to load path so we can find the dummy provider
$:.unshift(File.expand_path('../support', __FILE__))

class CloudSpecConfig
  attr_accessor :db, :uuid

  def logger
    if @logger.nil?
      @logger = Logger.new(STDOUT)
      @logger.level = :error
    end
    @logger
  end

  def uuid
    @uuid ||= self.class.name
  end
end

Bosh::Clouds::Config.configure(CloudSpecConfig.new)
