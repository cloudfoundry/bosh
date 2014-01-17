require 'spec_helper'

describe 'stemcell integrations' do
  include IntegrationExampleGroup

  context 'when stemcell is in use by a deployment' do
    it 'refuses to delete it' do
      deploy_simple
      results = run_bosh('delete stemcell ubuntu-stemcell 1', failure_expected: true)
      expect(results).to match %r{Stemcell `ubuntu-stemcell/1' is still in use by: simple}
    end
  end
end
