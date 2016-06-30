require 'spec_helper'

module Bosh::Director::ConfigServer
  describe ConfigPathValidator do

    describe '#validate' do
      it 'should return true for global properties path' do
        path = ['properties', 'a', 'b', 'c']
        expect(ConfigPathValidator.validate(path)).to be_truthy
      end

      it 'should return true for instance group properties path' do
        path = ['instance_groups', 1, 'properties', 'a', 'test_prop']
        expect(ConfigPathValidator.validate(path)).to be_truthy
      end

      it 'should return true for job properties path' do
        path = ['instance_groups', 0, 'jobs', 1, 'properties', 'test_prop']
        expect(ConfigPathValidator.validate(path)).to be_truthy
      end

      it 'should return true for env properties path' do
        path = ['resource_pools', 0, 'env', 'test_prop']
        expect(ConfigPathValidator.validate(path)).to be_truthy
      end

      it 'should return true for link properties' do
        path = ['instance_groups', 0, 'jobs', 1, 'consumes', 'some_link', 'properties']
        expect(ConfigPathValidator.validate(path)).to be_truthy
      end

      it 'should return false for any other paths' do
        path = ['instance_groups', 0, 'name']
        expect(ConfigPathValidator.validate(path)).to eq(false)
      end
    end
  end
end