require 'spec_helper'

require 'cli/director'
require 'bosh/dev/director_client'

module Bosh::Dev

  describe DirectorClient do
    let (:director_handle) { instance_double 'Bosh::Cli::Director' }
    let (:valid_stemcell_list_1) {
      [
          {'name' => 'bosh-MOCK-stemcell', 'version' => '007', 'cid' => 'ami-amazon_guid_1'},
          {'name' => 'bosh-MOCK-stemcell', 'version' => '222', 'cid' => 'ami-amazon_guid_2'}
      ]
    }

    let (:valid_stemcell_list_2) {
      [
          {'name' => 'bosh-MOCK-stemcell', 'version' => '007', 'cid' => 'ami-amazon_guid_1'},
          {'name' => 'bosh-MOCK-stemcell', 'version' => '222', 'cid' => 'ami-amazon_guid_2'}
      ]
    }

    subject(:director_client) do
      DirectorClient.new(
          director_handle: director_handle
      )
    end

    it 'lists stemcells stored on director' do
      director_handle.stub(:list_stemcells) { valid_stemcell_list_1 }
      expect(director_client.stemcells).to eq valid_stemcell_list_2
    end

  end
end
