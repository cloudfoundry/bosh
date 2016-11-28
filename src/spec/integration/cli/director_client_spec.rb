require 'spec_helper'
require 'cli/client/director'
require 'cli/client/credentials'

describe 'Director Client', type: :integration do
  with_reset_sandbox_before_each

  describe '#update_cloud_config' do
    it 'posts a cloud config to the director' do
      credentials = Bosh::Cli::Client::BasicCredentials.new('test', 'test')
      director = Bosh::Cli::Client::Director.new(current_sandbox.director_url, credentials)
      cloud_config = Psych.dump(Bosh::Spec::Deployments.simple_cloud_config)

      expect(director.update_cloud_config(cloud_config)).to eq(true)
    end
  end

  describe '#get_cloud_config' do
    it 'gets the most recent cloud config from the director' do
      credentials = Bosh::Cli::Client::BasicCredentials.new('test', 'test')
      director = Bosh::Cli::Client::Director.new(current_sandbox.director_url, credentials)
      cloud_config = Bosh::Spec::Deployments.simple_cloud_config
      old_manifest = Psych.dump(cloud_config)
      cloud_config['compilation']['workers'] = 100
      new_manifest = Psych.dump(cloud_config)

      expect(director.get_cloud_config).to eq(nil)

      director.update_cloud_config(old_manifest)
      director.update_cloud_config(new_manifest)

      latest_cloud_config = director.get_cloud_config
      expect(latest_cloud_config.properties).to eq(new_manifest)
      expect(latest_cloud_config.created_at).to_not be_nil
    end
  end
end
