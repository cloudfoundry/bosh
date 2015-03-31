require 'spec_helper'
require 'cli/client/director'
require 'cli/client/credentials'

describe 'Director Client', type: :integration do
  describe '#update_cloud_config' do
    with_reset_sandbox_before_each

    it 'posts a cloud config to the director' do
      credentials = Bosh::Cli::Client::BasicCredentials.new('admin', 'admin')
      director = Bosh::Cli::Client::Director.new(current_sandbox.director_url, credentials)
      cloud_config = 'some awesome configuration'

      expect(director.update_cloud_config(cloud_config)).to eq(true)
    end
  end
end
