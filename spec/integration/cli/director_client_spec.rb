require 'spec_helper'
require 'cli/client/director'
require 'cli/client/credentials'

describe 'Director Client', type: :integration do
  with_reset_sandbox_before_each

  describe '#update_cloud_config' do
    it 'posts a cloud config to the director' do
      credentials = Bosh::Cli::Client::BasicCredentials.new('admin', 'admin')
      director = Bosh::Cli::Client::Director.new(current_sandbox.director_url, credentials)
      cloud_config = 'some awesome configuration'

      expect(director.update_cloud_config(cloud_config)).to eq(true)
    end
  end

  describe '#get_cloud_config' do
    it 'gets the most recent cloud config from the director' do
      credentials = Bosh::Cli::Client::BasicCredentials.new('admin', 'admin')
      director = Bosh::Cli::Client::Director.new(current_sandbox.director_url, credentials)
      older_cloud_config = '---\nfoo: bar'
      newest_cloud_config = '---\nfoo: baz'

      expect(director.get_cloud_config).to eq(nil)

      director.update_cloud_config(older_cloud_config)
      director.update_cloud_config(newest_cloud_config)

      latest_cloud_config = director.get_cloud_config
      expect(latest_cloud_config.properties).to eq(newest_cloud_config)
      expect(latest_cloud_config.created_at).to_not be_nil
    end
  end
end
