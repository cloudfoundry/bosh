require 'spec_helper'

describe Bosh::Director::StripDeploymentsMiddlewareCollector do
  before(:all) do
    @cmc = Bosh::Director::StripDeploymentsMiddlewareCollector.new(nil)
  end

  describe '#strip_ids_from_path' do
    it 'strips uuids from path' do
      expect(@cmc.strip_ids_from_path('/jobs/123e4567-e89b-12d3-a456-426614174000/logs')).to eq('/jobs/:uuid/logs')
    end

    it 'strips ids from path' do
      expect(@cmc.strip_ids_from_path('/tasks/123/output')).to eq('/tasks/:id/output')
    end

    it 'strips deployment name from path' do
      expect(@cmc.strip_ids_from_path('/deployments/dummy')).to eq('/deployments/:deployment')
    end

    it 'strips deployment name and uuids from path' do
      expect(@cmc.strip_ids_from_path('/deployments/dummy/jobs/dummy/123e4567-e89b-12d3-a456-426614174000/logs')).to eq('/deployments/:deployment/jobs/dummy/:uuid/logs')
    end

    it 'do not strips if no match' do
      expect(@cmc.strip_ids_from_path('/releases/abs-release')).to eq('/releases/abs-release')
    end
  end
end
