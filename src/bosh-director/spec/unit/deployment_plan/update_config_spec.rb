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

      expect(config.canaries_before_calculation).to eq('2')
      expect(config.max_in_flight_before_calculation).to eq('4')
      expect(config.min_canary_watch_time).to eq(60000)
      expect(config.max_canary_watch_time).to eq(60000)
      expect(config.min_update_watch_time).to eq(30000)
      expect(config.max_update_watch_time).to eq(30000)
      expect(config).to be_serial
    end


    it 'should return Integer after calculation' do
      config = BD::DeploymentPlan::UpdateConfig.new(
        'canaries' => 2,
        'max_in_flight' => 4,
        'canary_watch_time' => 60000,
        'update_watch_time' => 30000,
      )
      expect(config.canaries(10)).to eq(2)
      expect(config.max_in_flight(10)).to eq(4)
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
      let(:other_opts) { {
        'canaries' => 2,
        'max_in_flight' => 4,
        'canary_watch_time' => 60000,
        'update_watch_time' => 30000,
      } }

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

        context 'when the hash is nil' do
          it 'returns false' do
            config = BD::DeploymentPlan::UpdateConfig.new(nil, default_config)
            expect(config.to_hash['serial']).to be(false)
          end
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

      it 'should allow values as string' do
        config = BD::DeploymentPlan::UpdateConfig.new({
          'canaries' => '2',
          'max_in_flight' => '4',
        }, default_config)
        expect(config.canaries_before_calculation).to eq('2')
        expect(config.max_in_flight_before_calculation).to eq('4')
        expect(config.canaries(10)).to eq(2)
        expect(config.max_in_flight(10)).to eq(4)
      end

      it 'should let you override all defaults' do
        config = BD::DeploymentPlan::UpdateConfig.new({
          'canaries' => 2,
          'max_in_flight' => 4,
          'canary_watch_time' => 60000,
          'update_watch_time' => 30000,
        }, default_config)

        expect(config.canaries_before_calculation).to eq('2')
        expect(config.max_in_flight_before_calculation).to eq('4')
        expect(config.min_canary_watch_time).to eq(60000)
        expect(config.max_canary_watch_time).to eq(60000)
        expect(config.min_update_watch_time).to eq(30000)
        expect(config.max_update_watch_time).to eq(30000)
      end

      it 'should inherit settings from default config' do
        config = BD::DeploymentPlan::UpdateConfig.new({}, default_config)
        expect(config.canaries_before_calculation).to eq('1')
        expect(config.max_in_flight_before_calculation).to eq('2')
        expect(config.canaries(10)).to eq(1)
        expect(config.max_in_flight(10)).to eq(2)
        expect(config.min_canary_watch_time).to eq(10000)
        expect(config.max_canary_watch_time).to eq(10000)
        expect(config.min_update_watch_time).to eq(5000)
        expect(config.max_update_watch_time).to eq(5000)
      end
    end

    context 'strategy' do
      it 'should return the strategy configuration from the spec' do
        config = BD::DeploymentPlan::UpdateConfig.new(
          'strategy' => 'hot-swap',
          'canaries' => 2,
          'max_in_flight' => 4,
          'canary_watch_time' => 60000,
          'update_watch_time' => 30000
        )

        expect(config.strategy).to eq('hot-swap')
      end

      context 'when strategy has a wrong format' do
        it 'raises an error' do
          expect {
            BD::DeploymentPlan::UpdateConfig.new(
              {
                'strategy' => 'incorrect-strategy-value',
                'canaries' => 2,
                'max_in_flight' => 4,
                'canary_watch_time' => 60000,
                'update_watch_time' => 30000
              }
            )
          }.to raise_error(Bosh::Director::ValidationInvalidValue, /Invalid strategy 'incorrect-strategy-value', valid strategies are: hot-swap, legacy/)
        end
      end

      context 'when strategy is created from previously created strategy (such as happens in cck)' do
        let(:old_config) {
          BD::DeploymentPlan::UpdateConfig.new(
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => 60000,
            'update_watch_time' => 30000
          )
        }

        it 'can make an update from the hash of the old config' do
          expect { BD::DeploymentPlan::UpdateConfig.new(old_config.to_hash) }.to_not raise_error
        end
      end

      context 'when default update_config is provided and strategy is not provided' do
        let(:default_config) {
          BD::DeploymentPlan::UpdateConfig.new(
            'strategy' => 'hot-swap',
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => 60000,
            'update_watch_time' => 30000
          )
        }

        it 'should use strategy value from default_update_config' do
          config = BD::DeploymentPlan::UpdateConfig.new({}, default_config)

          expect(config.strategy).to eq('hot-swap')
        end

        context 'when strategy has a wrong format' do
          it 'raises an error' do
            expect {
              BD::DeploymentPlan::UpdateConfig.new(
                {
                  'strategy' => '',
                  'canaries' => 2,
                  'max_in_flight' => 4,
                  'canary_watch_time' => 60000,
                  'update_watch_time' => 30000
                }, default_config
              )
            }.to raise_error(Bosh::Director::ValidationInvalidValue, /Invalid strategy '', valid strategies are: hot-swap, legacy/)
          end
        end
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

  describe '#to_hash' do
    it 'should create a valid hash' do
      config = BD::DeploymentPlan::UpdateConfig.new(
        'strategy' => 'hot-swap',
        'canaries' => 2,
        'max_in_flight' => 4,
        'canary_watch_time' => 60000,
        'update_watch_time' => 30000
      )

      config_hash = config.to_hash
      expect(config_hash).to eq({
        'strategy' => 'hot-swap',
        'canaries' => '2',
        'max_in_flight' => '4',
        'canary_watch_time' => '60000-60000',
        'update_watch_time' => '30000-30000',
        'serial' => true,
      })
    end

    context 'when strategy is nil' do
      it 'should set strategy to legacy strategy' do
        config = BD::DeploymentPlan::UpdateConfig.new(
          'canaries' => 2,
          'max_in_flight' => 4,
          'canary_watch_time' => 60000,
          'update_watch_time' => 30000
        )

        config_hash = config.to_hash
        expect(config_hash).to eq({
          'strategy' => 'legacy',
          'canaries' => '2',
          'max_in_flight' => '4',
          'canary_watch_time' => '60000-60000',
          'update_watch_time' => '30000-30000',
          'serial' => true,
        })
      end
    end
  end

  context 'when max_in_flight or canaries have wrong format' do
    it 'raises an error' do
      config = BD::DeploymentPlan::UpdateConfig.new(
        {
          'canaries' => 'blala',
          'max_in_flight' => 'blabla',
          'canary_watch_time' => 60000,
          'update_watch_time' => 30000,
        }
      )
      expect {
        config.canaries(10)
      }.to raise_error(/cannot be calculated/)
      expect {
        config.max_in_flight(10)
      }.to raise_error(/cannot be calculated/)
    end
  end

  context 'when max_in_flight or canaries are percents' do
    let(:default_config) {
      BD::DeploymentPlan::UpdateConfig.new(
        'canaries' => canaries_before_calculation,
        'max_in_flight' => max_in_flight_before_calculation,
        'canary_watch_time' => 60000,
        'update_watch_time' => 30000,
      )
    }
    let(:canaries_before_calculation) { '20%' }
    let(:max_in_flight_before_calculation) { '40%' }
    let(:size) { 10 }

    it 'should work with percents ' do
      expect(default_config.canaries(size)).to eq(2)
      expect(default_config.max_in_flight(size)).to eq(4)
    end

    it 'should be minimum 1 for max_in_flight' do
      expect(default_config.max_in_flight(0)).to eq(1)
    end

    it 'should inherit settings from default config' do
      config = BD::DeploymentPlan::UpdateConfig.new({}, default_config)
      expect(config.canaries_before_calculation).to eq(canaries_before_calculation)
      expect(config.max_in_flight_before_calculation).to eq(max_in_flight_before_calculation)
    end

    it 'should let you override all defaults' do
      config = BD::DeploymentPlan::UpdateConfig.new(
        {
          'canaries' => 1,
          'max_in_flight' => 2,
          'canary_watch_time' => 60000,
          'update_watch_time' => 30000,
        }, default_config)

      expect(config.canaries_before_calculation).to eq('1')
      expect(config.max_in_flight_before_calculation).to eq('2')

      config = BD::DeploymentPlan::UpdateConfig.new(
        {
          'canaries' => '30%',
          'max_in_flight' => '50%',
          'canary_watch_time' => 60000,
          'update_watch_time' => 30000,
        }, default_config)
      expect(config.canaries_before_calculation).to eq('30%')
      expect(config.max_in_flight_before_calculation).to eq('50%')
    end
  end
end
