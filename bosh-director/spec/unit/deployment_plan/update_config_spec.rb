require 'spec_helper'

describe Bosh::Director::DeploymentPlan::UpdateConfig do
  describe '#initialize' do
    it 'should create an update configuration from the spec' do
      config = BD::DeploymentPlan::UpdateConfig.new(
        'canaries' => 2,
        'max_in_flight' => 4,
        'canary_watch_time' => 60000,
        'update_watch_time' => 30000,
        'serial' => true,
      )

      expect(config.canaries).to eq(2)
      expect(config.max_in_flight).to eq(4)
      expect(config.min_canary_watch_time).to eq(60000)
      expect(config.max_canary_watch_time).to eq(60000)
      expect(config.min_update_watch_time).to eq(30000)
      expect(config.max_update_watch_time).to eq(30000)
      expect(config).to be_serial
    end

    it 'should allow ranges for canary watch time' do
      config = BD::DeploymentPlan::UpdateConfig.new(
        'canaries' => 2,
        'max_in_flight' => 4,
        'canary_watch_time' => '60000-120000',
        'update_watch_time' => 30000,
      )
      expect(config.min_canary_watch_time).to eq(60000)
      expect(config.max_canary_watch_time).to eq(120000)
    end

    it 'should allow ranges for canary watch time' do
      config = BD::DeploymentPlan::UpdateConfig.new(
        'canaries' => 2,
        'max_in_flight' => 4,
        'canary_watch_time' => 60000,
        'update_watch_time' => '5000-30000',
      )
      expect(config.min_update_watch_time).to eq(5000)
      expect(config.max_update_watch_time).to eq(30000)
    end

    it 'should require canaries when there is no default config' do
      expect {
        BD::DeploymentPlan::UpdateConfig.new(
          'max_in_flight' => 4,
          'canary_watch_time' => 60000,
          'update_watch_time' => 30000,
        )
      }.to raise_error(BD::ValidationMissingField)
    end

    it 'should require max_in_flight when there is no default config' do
      expect {
        BD::DeploymentPlan::UpdateConfig.new(
          'canaries' => 2,
          'canary_watch_time' => 60000,
          'update_watch_time' => 30000,
        )
      }.to raise_error(BD::ValidationMissingField)
    end

    it 'should require update_watch_time when there is no default config' do
      expect {
        BD::DeploymentPlan::UpdateConfig.new(
          'canaries' => 2,
          'max_in_flight' => 4,
          'canary_watch_time' => 60000
        )
      }.to raise_error(BD::ValidationMissingField)
    end

    it 'should require canary_watch_time when there is no default config' do
      expect {
        BD::DeploymentPlan::UpdateConfig.new(
          'canaries' => 2,
          'max_in_flight' => 4,
          'update_watch_time' => 30000,
        )
      }.to raise_error(BD::ValidationMissingField)
    end

    describe 'serial' do
      let(:other_opts) {{
        'canaries' => 2,
        'max_in_flight' => 4,
        'canary_watch_time' => 60000,
        'update_watch_time' => 30000,
      }}

      it 'raises an error if property is not TrueClass/FalseClass' do
        expect {
          BD::DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => double))
        }.to raise_error(BD::ValidationInvalidType, /serial/)
      end

      context 'when default config is nil' do
        let(:default_config) { nil }

        it 'can be set to be serial' do
          config = BD::DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => true), default_config)
          expect(config).to be_serial
        end

        it 'can be set to be not serial (parallel)' do
          config = BD::DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => false), default_config)
          expect(config).to_not be_serial
        end

        it 'is serial (not parallel) if serial option is not set' do
          other_opts.delete('serial')
          config = BD::DeploymentPlan::UpdateConfig.new(other_opts, default_config)
          expect(config).to be_serial
        end
      end

      context 'when default config specifies serial to be true' do
        let(:default_config) { BD::DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => true)) }

        it 'can be set to be serial' do
          config = BD::DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => true), default_config)
          expect(config).to be_serial
        end

        it 'can be set to be not serial (parallel)' do
          config = BD::DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => false), default_config)
          expect(config).to_not be_serial
        end

        it 'is serial if serial option is not set' do
          other_opts.delete('serial')
          config = BD::DeploymentPlan::UpdateConfig.new(other_opts, default_config)
          expect(config).to be_serial
        end
      end

      context 'when default config specifies serial to be false' do
        let(:default_config) { BD::DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => false)) }

        it 'can be set to be serial' do
          config = BD::DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => true), default_config)
          expect(config).to be_serial
        end

        it 'can be set to be not serial (parallel)' do
          config = BD::DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => false), default_config)
          expect(config).to_not be_serial
        end

        it 'is not serial (parallel) if serial option is not set' do
          other_opts.delete('serial')
          config = BD::DeploymentPlan::UpdateConfig.new(other_opts, default_config)
          expect(config).to_not be_serial
        end
      end
    end

    describe 'defaults' do
      let(:default_config) do
        BD::DeploymentPlan::UpdateConfig.new(
          'canaries' => 1,
          'max_in_flight' => 2,
          'canary_watch_time' => 10000,
          'update_watch_time' => 5000,
        )
      end

      it 'should let you override all defaults' do
        config = BD::DeploymentPlan::UpdateConfig.new({
          'canaries' => 2,
          'max_in_flight' => 4,
          'canary_watch_time' => 60000,
          'update_watch_time' => 30000,
        }, default_config)

        expect(config.canaries).to eq(2)
        expect(config.max_in_flight).to eq(4)
        expect(config.min_canary_watch_time).to eq(60000)
        expect(config.max_canary_watch_time).to eq(60000)
        expect(config.min_update_watch_time).to eq(30000)
        expect(config.max_update_watch_time).to eq(30000)
      end

      it 'should inherit settings from default config' do
        config = BD::DeploymentPlan::UpdateConfig.new({}, default_config)
        expect(config.canaries).to eq(1)
        expect(config.max_in_flight).to eq(2)
        expect(config.min_canary_watch_time).to eq(10000)
        expect(config.max_canary_watch_time).to eq(10000)
        expect(config.min_update_watch_time).to eq(5000)
        expect(config.max_update_watch_time).to eq(5000)
      end
    end
  end

  describe '#parse_watch_times' do
    let(:basic_config) do
      BD::DeploymentPlan::UpdateConfig.new(
        'canaries' => 1,
        'max_in_flight' => 2,
        'canary_watch_time' => 10000,
        'update_watch_time' => 5000,
       )
    end

    it('should parse literals') { expect(basic_config.parse_watch_times(1000)).to eq([1000, 1000]) }
    it('should parse ranges') { expect(basic_config.parse_watch_times('100 - 1000')).to eq([100, 1000]) }

    it 'should fail parsing garbage' do
      expect {
        basic_config.parse_watch_times('100 - 1000 - 5000')
      }.to raise_error(/Watch time should be/)
    end

    it 'should fail parsing ranges with a higher min than max value' do
      expect {
        basic_config.parse_watch_times('1001 - 100')
      }.to raise_error(/Min watch time cannot/)
    end
  end
end
