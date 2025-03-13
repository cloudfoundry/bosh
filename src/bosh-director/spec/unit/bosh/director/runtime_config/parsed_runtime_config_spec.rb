require 'spec_helper'

module Bosh::Director::RuntimeConfig
  describe ParsedRuntimeConfig do
    subject(:config) do
      ParsedRuntimeConfig.new(releases, addons, nil)
    end
    let(:deployment_plan) do
      instance_double(Bosh::Director::DeploymentPlan::Planner, name: 'foo', team_names: [], instance_groups: instance_groups)
    end

    let(:instance_groups) do
      [
        instance_double(Bosh::Director::DeploymentPlan::Job),
        instance_double(Bosh::Director::DeploymentPlan::Job),
      ]
    end

    let(:releases) do
      [
        instance_double(Bosh::Director::RuntimeConfig::Release, name: 'derpy', version: '1'),
        instance_double(Bosh::Director::RuntimeConfig::Release, name: 'burpy', version: '2'),
        instance_double(Bosh::Director::RuntimeConfig::Release, name: 'not_used', version: '99'),
      ]
    end

    context '#get_applicable_addons' do
      let(:applicable_addon) do
        instance_double(Bosh::Director::Addon::Addon, releases: ['derpy'], applies?: true)
      end

      let(:not_applicable_addon) do
        instance_double(Bosh::Director::Addon::Addon, releases: ['burpy'], applies?: false)
      end

      let(:addons) do
        [applicable_addon, not_applicable_addon]
      end

      it 'should only return addons applicable to the current deployment' do
        addons = config.get_applicable_addons(deployment_plan)
        expect(addons.size).to eq(1)
        expect(addons[0]).to eq(applicable_addon)
      end
    end

    context '#get_applicable_releases' do
      let(:applicable_addon_1) do
        instance_double(Bosh::Director::Addon::Addon, releases: ['derpy'], applies?: true)
      end

      let(:applicable_addon_2) do
        instance_double(Bosh::Director::Addon::Addon, releases: ['derpy'], applies?: true)
      end

      let(:not_applicable_addon) do
        instance_double(Bosh::Director::Addon::Addon, releases: ['burpy'], applies?: false)
      end

      let(:addons) do
        [applicable_addon_1, applicable_addon_2, not_applicable_addon]
      end

      it 'should only return unique releases applicable to the current deployment' do
        actual_releases = config.get_applicable_releases(deployment_plan)
        expect(actual_releases).to match_array(releases[0])
      end
    end
  end
end