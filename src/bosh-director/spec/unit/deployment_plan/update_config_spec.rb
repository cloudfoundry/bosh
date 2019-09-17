require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::UpdateConfig do
    describe '#initialize' do
      it 'should create an update configuration from the spec' do
        config = DeploymentPlan::UpdateConfig.new(
          'canaries' => 2,
          'max_in_flight' => 4,
          'canary_watch_time' => 60_000,
          'update_watch_time' => 30_000,
          'serial' => true,
        )

        expect(config.canaries_before_calculation).to eq('2')
        expect(config.max_in_flight_before_calculation).to eq('4')
        expect(config.min_canary_watch_time).to eq(60_000)
        expect(config.max_canary_watch_time).to eq(60_000)
        expect(config.min_update_watch_time).to eq(30_000)
        expect(config.max_update_watch_time).to eq(30_000)
        expect(config).to be_serial
      end

      it 'should return Integer after calculation' do
        config = DeploymentPlan::UpdateConfig.new(
          'canaries' => 2,
          'max_in_flight' => 4,
          'canary_watch_time' => 60_000,
          'update_watch_time' => 30_000,
        )
        expect(config.canaries(10)).to eq(2)
        expect(config.max_in_flight(10)).to eq(4)
      end

      context 'when canary_watch_time is a range' do
        it 'should allow ranges for canary watch time' do
          config = DeploymentPlan::UpdateConfig.new(
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => '60000-120000',
            'update_watch_time' => 30_000,
          )
          expect(config.min_canary_watch_time).to eq(60_000)
          expect(config.max_canary_watch_time).to eq(120_000)
        end
      end

      context 'when update_watch_time is a range' do
        it 'should allow ranges for update watch time' do
          config = DeploymentPlan::UpdateConfig.new(
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => 60_000,
            'update_watch_time' => '5000-30000',
          )
          expect(config.min_update_watch_time).to eq(5000)
          expect(config.max_update_watch_time).to eq(30_000)
        end
      end

      it 'should require canaries when there is no default config' do
        expect do
          DeploymentPlan::UpdateConfig.new(
            'max_in_flight' => 4,
            'canary_watch_time' => 60_000,
            'update_watch_time' => 30_000,
          )
        end.to raise_error(ValidationMissingField)
      end

      it 'should require max_in_flight when there is no default config' do
        expect do
          DeploymentPlan::UpdateConfig.new(
            'canaries' => 2,
            'canary_watch_time' => 60_000,
            'update_watch_time' => 30_000,
          )
        end.to raise_error(ValidationMissingField)
      end

      it 'should require update_watch_time when there is no default config' do
        expect do
          DeploymentPlan::UpdateConfig.new(
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => 60_000,
          )
        end.to raise_error(ValidationMissingField)
      end

      it 'should require canary_watch_time when there is no default config' do
        expect do
          DeploymentPlan::UpdateConfig.new(
            'canaries' => 2,
            'max_in_flight' => 4,
            'update_watch_time' => 30_000,
          )
        end.to raise_error(ValidationMissingField)
      end

      describe 'serial' do
        let(:other_opts) do
          {
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => 60_000,
            'update_watch_time' => 30_000,
          } end

        it 'raises an error if property is not TrueClass/FalseClass' do
          expect do
            DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => double))
          end.to raise_error(ValidationInvalidType, /serial/)
        end

        context 'when default config is nil' do
          let(:default_config) { nil }

          it 'can be set to be serial' do
            config = DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => true), default_config)
            expect(config).to be_serial
          end

          it 'can be set to be not serial (parallel)' do
            config = DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => false), default_config)
            expect(config).to_not be_serial
          end

          it 'is serial (not parallel) if serial option is not set' do
            other_opts.delete('serial')
            config = DeploymentPlan::UpdateConfig.new(other_opts, default_config)
            expect(config).to be_serial
          end
        end

        context 'when default config specifies serial to be true' do
          let(:default_config) { DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => true)) }

          it 'can be set to be serial' do
            config = DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => true), default_config)
            expect(config).to be_serial
          end

          it 'can be set to be not serial (parallel)' do
            config = DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => false), default_config)
            expect(config).to_not be_serial
          end

          it 'is serial if serial option is not set' do
            other_opts.delete('serial')
            config = DeploymentPlan::UpdateConfig.new(other_opts, default_config)
            expect(config).to be_serial
          end
        end

        context 'when default config specifies serial to be false' do
          let(:default_config) { DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => false)) }

          it 'can be set to be serial' do
            config = DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => true), default_config)
            expect(config).to be_serial
          end

          it 'can be set to be not serial (parallel)' do
            config = DeploymentPlan::UpdateConfig.new(other_opts.merge('serial' => false), default_config)
            expect(config).to_not be_serial
          end

          it 'is not serial (parallel) if serial option is not set' do
            other_opts.delete('serial')
            config = DeploymentPlan::UpdateConfig.new(other_opts, default_config)
            expect(config).to_not be_serial
          end

          context 'when the hash is nil' do
            it 'returns false' do
              config = DeploymentPlan::UpdateConfig.new(nil, default_config)
              expect(config.to_hash['serial']).to be(false)
            end
          end
        end
      end

      describe 'defaults' do
        let(:default_config) do
          DeploymentPlan::UpdateConfig.new(
            'canaries' => 1,
            'max_in_flight' => 2,
            'canary_watch_time' => 10_000,
            'update_watch_time' => 5000,
          )
        end

        it 'should allow values as string' do
          config = DeploymentPlan::UpdateConfig.new({
            'canaries' => '2',
            'max_in_flight' => '4',
          }, default_config)
          expect(config.canaries_before_calculation).to eq('2')
          expect(config.max_in_flight_before_calculation).to eq('4')
          expect(config.canaries(10)).to eq(2)
          expect(config.max_in_flight(10)).to eq(4)
        end

        it 'should let you override all defaults' do
          config = DeploymentPlan::UpdateConfig.new({
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => 60_000,
            'update_watch_time' => 30_000,
          }, default_config)

          expect(config.canaries_before_calculation).to eq('2')
          expect(config.max_in_flight_before_calculation).to eq('4')
          expect(config.min_canary_watch_time).to eq(60_000)
          expect(config.max_canary_watch_time).to eq(60_000)
          expect(config.min_update_watch_time).to eq(30_000)
          expect(config.max_update_watch_time).to eq(30_000)
        end

        it 'should inherit settings from default config' do
          config = DeploymentPlan::UpdateConfig.new({}, default_config)
          expect(config.canaries_before_calculation).to eq('1')
          expect(config.max_in_flight_before_calculation).to eq('2')
          expect(config.canaries(10)).to eq(1)
          expect(config.max_in_flight(10)).to eq(2)
          expect(config.min_canary_watch_time).to eq(10_000)
          expect(config.max_canary_watch_time).to eq(10_000)
          expect(config.min_update_watch_time).to eq(5000)
          expect(config.max_update_watch_time).to eq(5000)
        end
      end

      context 'vm_strategy' do
        it 'should return the vm_strategy configuration from the spec' do
          config = DeploymentPlan::UpdateConfig.new(
            'vm_strategy' => 'create-swap-delete',
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => 60_000,
            'update_watch_time' => 30_000,
          )

          expect(config.vm_strategy).to eq('create-swap-delete')
        end

        context 'when vm_strategy has a wrong format' do
          it 'raises an error' do
            expect do
              DeploymentPlan::UpdateConfig.new(
                'vm_strategy' => 'incorrect-strategy-value',
                'canaries' => 2,
                'max_in_flight' => 4,
                'canary_watch_time' => 60_000,
                'update_watch_time' => 30_000,
              )
            end.to raise_error(Bosh::Director::ValidationInvalidValue, /Invalid vm_strategy 'incorrect-strategy-value', valid strategies are: create-swap-delete, delete-create/)
          end
        end

        context 'when vm_strategy is created from previously created vm_strategy (such as happens in cck)' do
          let(:old_config) do
            DeploymentPlan::UpdateConfig.new(
              'canaries' => 2,
              'max_in_flight' => 4,
              'canary_watch_time' => 60_000,
              'update_watch_time' => 30_000,
            )
          end

          it 'can make an update from the hash of the old config' do
            expect { DeploymentPlan::UpdateConfig.new(old_config.to_hash) }.to_not raise_error
          end
        end

        context 'when default update_config is provided and vm_strategy is not provided' do
          let(:default_config) do
            DeploymentPlan::UpdateConfig.new(
              'vm_strategy' => 'create-swap-delete',
              'canaries' => 2,
              'max_in_flight' => 4,
              'canary_watch_time' => 60_000,
              'update_watch_time' => 30_000,
            )
          end

          it 'should use vm_strategy value from default_update_config' do
            config = DeploymentPlan::UpdateConfig.new({}, default_config)

            expect(config.vm_strategy).to eq('create-swap-delete')
          end

          context 'when vm_strategy has a wrong format' do
            it 'raises an error' do
              expect do
                DeploymentPlan::UpdateConfig.new(
                  {
                    'vm_strategy' => '',
                    'canaries' => 2,
                    'max_in_flight' => 4,
                    'canary_watch_time' => 60_000,
                    'update_watch_time' => 30_000,
                  }, default_config
                )
              end.to raise_error(Bosh::Director::ValidationInvalidValue, /Invalid vm_strategy '', valid strategies are: create-swap-delete, delete-create/)
            end
          end
        end
      end

      context 'initial_deploy_az_update_strategy' do
        it 'should return the value specified in the spec' do
          spec = {
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => 60_000,
            'update_watch_time' => 30_000,
          }
          expect(DeploymentPlan::UpdateConfig.new(spec).update_azs_in_parallel_on_initial_deploy?).to eq(false)

          spec['initial_deploy_az_update_strategy'] = 'parallel'
          expect(DeploymentPlan::UpdateConfig.new(spec).update_azs_in_parallel_on_initial_deploy?).to eq(true)

          spec['initial_deploy_az_update_strategy'] = 'serial'
          expect(DeploymentPlan::UpdateConfig.new(spec).update_azs_in_parallel_on_initial_deploy?).to eq(false)

          spec['initial_deploy_az_update_strategy'] = 'nonsense'
          expect { DeploymentPlan::UpdateConfig.new(spec) }.to raise_error
        end
      end
    end

    describe '#parse_watch_times' do
      let(:basic_config) do
        DeploymentPlan::UpdateConfig.new(
          'canaries' => 1,
          'max_in_flight' => 2,
          'canary_watch_time' => 10_000,
          'update_watch_time' => 5000,
        )
      end

      it('should parse literals') { expect(basic_config.parse_watch_times(1000)).to eq([1000, 1000]) }
      it('should parse ranges') { expect(basic_config.parse_watch_times('100 - 1000')).to eq([100, 1000]) }

      it 'should fail parsing garbage' do
        expect do
          basic_config.parse_watch_times('100 - 1000 - 5000')
        end.to raise_error(/Watch time should be/)
      end

      it 'should fail parsing ranges with a higher min than max value' do
        expect do
          basic_config.parse_watch_times('1001 - 100')
        end.to raise_error(/Min watch time cannot/)
      end
    end

    describe '#to_hash' do
      it 'should create a valid hash' do
        config = DeploymentPlan::UpdateConfig.new(
          'vm_strategy' => 'create-swap-delete',
          'canaries' => 2,
          'max_in_flight' => 4,
          'canary_watch_time' => 60_000,
          'update_watch_time' => 30_000,
        )

        config_hash = config.to_hash
        expect(config_hash).to eq(
          'vm_strategy' => 'create-swap-delete',
          'canaries' => '2',
          'max_in_flight' => '4',
          'canary_watch_time' => '60000-60000',
          'update_watch_time' => '30000-30000',
          'serial' => true,
        )
      end
    end

    context 'when max_in_flight or canaries have wrong format' do
      it 'raises an error' do
        config = DeploymentPlan::UpdateConfig.new(
          'canaries' => 'blala',
          'max_in_flight' => 'blabla',
          'canary_watch_time' => 60_000,
          'update_watch_time' => 30_000,
        )
        expect do
          config.canaries(10)
        end.to raise_error(/cannot be calculated/)
        expect do
          config.max_in_flight(10)
        end.to raise_error(/cannot be calculated/)
      end
    end

    context 'when max_in_flight or canaries are percents' do
      let(:default_config) do
        DeploymentPlan::UpdateConfig.new(
          'canaries' => canaries_before_calculation,
          'max_in_flight' => max_in_flight_before_calculation,
          'canary_watch_time' => 60_000,
          'update_watch_time' => 30_000,
        )
      end
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
        config = DeploymentPlan::UpdateConfig.new({}, default_config)
        expect(config.canaries_before_calculation).to eq(canaries_before_calculation)
        expect(config.max_in_flight_before_calculation).to eq(max_in_flight_before_calculation)
      end

      it 'should let you override all defaults' do
        config = DeploymentPlan::UpdateConfig.new(
          {
            'canaries' => 1,
            'max_in_flight' => 2,
            'canary_watch_time' => 60_000,
            'update_watch_time' => 30_000,
          }, default_config
        )

        expect(config.canaries_before_calculation).to eq('1')
        expect(config.max_in_flight_before_calculation).to eq('2')

        config = DeploymentPlan::UpdateConfig.new(
          {
            'canaries' => '30%',
            'max_in_flight' => '50%',
            'canary_watch_time' => 60_000,
            'update_watch_time' => 30_000,
          }, default_config
        )
        expect(config.canaries_before_calculation).to eq('30%')
        expect(config.max_in_flight_before_calculation).to eq('50%')
      end
    end
  end
end
