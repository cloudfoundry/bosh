require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DeploymentFeaturesParser do
    subject(:deployment_features_parser) { described_class.new(per_spec_logger) }

    describe '#parse' do
      context 'when features spec passed is nil' do
        it 'should return an empty DeploymentFeatures object' do
          features = deployment_features_parser.parse(nil)
          expect(features.use_dns_addresses).to be_nil
        end
      end

      context 'when features spec passed is NOT nil' do
        context 'when features spec is NOT a HASH' do
          it 'should return an error' do
            expect do
              deployment_features_parser.parse('vroom')
            end.to raise_error(
              FeaturesInvalidFormat,
              "Key 'features' expects a Hash, but received 'String'",
            )
          end
        end

        context 'when features spec is a HASH' do
          describe 'use_dns_addresses' do
            context 'when use_dns_addresses is NOT specified' do
              it 'defaults use_dns_addresses value to the value of `use_link_dns_names`' do
                features = deployment_features_parser.parse('use_link_dns_names' => true)
                expect(features.use_dns_addresses).to be_truthy
              end
            end

            context 'when use_dns_addresses is specified' do
              context 'when use_dns_addresses is NOT a boolean' do
                it 'raises an error' do
                  expect do
                    deployment_features_parser.parse('use_dns_addresses' => 'vroom')
                  end.to raise_error(
                    FeaturesInvalidFormat,
                    "Key 'use_dns_addresses' in 'features' expected to be a boolean, but received 'String'",
                  )
                end
              end

              context 'when use_dns_addresses is a boolean' do
                it 'sets the use_dns_addresses value to the features object' do
                  features = deployment_features_parser.parse('use_dns_addresses' => true)
                  expect(features.use_dns_addresses).to eq(true)

                  features = deployment_features_parser.parse('use_dns_addresses' => false)
                  expect(features.use_dns_addresses).to eq(false)
                end
              end
            end
          end

          describe 'use_link_dns_names' do
            context 'when use_link_dns_names is NOT specified' do
              it 'defaults use_link_dns_names value to nil' do
                features = deployment_features_parser.parse({})
                expect(features.use_link_dns_names).to be_nil
              end
            end

            context 'when use_link_dns_names is specified' do
              context 'when use_link_dns_names is NOT a boolean' do
                it 'raises an error' do
                  expect do
                    deployment_features_parser.parse('use_link_dns_names' => 'vroom')
                  end.to raise_error(
                    FeaturesInvalidFormat,
                    "Key 'use_link_dns_names' in 'features' expected to be a boolean, but received 'String'",
                  )
                end
              end

              context 'when use_link_dns_names is a boolean' do
                it 'sets the use_link_dns_names value to the features object' do
                  features = deployment_features_parser.parse('use_link_dns_names' => true)
                  expect(features.use_link_dns_names).to eq(true)

                  features = deployment_features_parser.parse('use_link_dns_names' => false)
                  expect(features.use_link_dns_names).to eq(false)
                end

                context 'when `use_short_dns_addresses` is FALSE' do
                  it 'does not raise error if not trying to enable use_link_dns_names' do
                    expect do
                      deployment_features_parser.parse('use_link_dns_names' => false, 'use_short_dns_addresses' => false)
                    end.not_to raise_error
                  end

                  it 'raises an error when trying to enable use_link_dns_names' do
                    expect do
                      deployment_features_parser.parse('use_link_dns_names' => true, 'use_short_dns_addresses' => false)
                    end.to raise_error(
                      IncompatibleFeatures,
                      'cannot enable `use_link_dns_names` when `use_short_dns_addresses` is explicitly disabled',
                    )
                  end
                end

                context 'when `use_dns_address` is FALSE' do
                  it 'does not raise error if not trying to enable use_link_dns_names' do
                    expect do
                      deployment_features_parser.parse('use_link_dns_names' => false, 'use_dns_addresses' => false)
                    end.not_to raise_error
                  end

                  it 'raises an error when trying to enable use_link_dns_names' do
                    expect do
                      deployment_features_parser.parse('use_link_dns_names' => true, 'use_dns_addresses' => false)
                    end.to raise_error(
                      IncompatibleFeatures,
                      'cannot enable `use_link_dns_names` when `use_dns_addresses` is explicitly disabled',
                    )
                  end
                end
              end
            end
          end

          describe 'use_short_dns_addresses' do
            context 'when use_short_dns_addresses is NOT specified' do
              it 'defaults use_short_dns_addresses value to the value of `use_link_dns_names`' do
                features = deployment_features_parser.parse('use_link_dns_names' => true)
                expect(features.use_short_dns_addresses).to be_truthy
              end
            end

            context 'when use_short_dns_addresses is specified' do
              context 'when use_short_dns_addresses is NOT a boolean' do
                it 'raises an error' do
                  expect do
                    deployment_features_parser.parse('use_short_dns_addresses' => 'vroom')
                  end.to raise_error(
                    FeaturesInvalidFormat,
                    "Key 'use_short_dns_addresses' in 'features' expected to be a boolean, but received 'String'",
                  )
                end
              end

              context 'when use_short_dns_addresses is a boolean' do
                it 'sets the use_short_dns_addresses value to the features object' do
                  features = deployment_features_parser.parse('use_short_dns_addresses' => true)
                  expect(features.use_short_dns_addresses).to eq(true)

                  features = deployment_features_parser.parse('use_short_dns_addresses' => false)
                  expect(features.use_short_dns_addresses).to eq(false)
                end
              end
            end
          end

          describe 'randomize_az_placement' do
            context 'when randomize_az_placement is NOT specified' do
              it 'defaults randomize_az_placement to nil' do
                features = deployment_features_parser.parse({})
                expect(features.randomize_az_placement).to be_nil
              end
            end

            context 'when randomize_az_placement is specified' do
              context 'when randomize_az_placement is NOT a boolean' do
                it 'raises an error' do
                  expect do
                    deployment_features_parser.parse('randomize_az_placement' => 'vroom')
                  end.to raise_error(
                    FeaturesInvalidFormat,
                    "Key 'randomize_az_placement' in 'features' expected to be a boolean, but received 'String'",
                  )
                end
              end

              context 'when randomize_az_placement is a boolean' do
                it 'sets the randomize_az_placement value to the features object' do
                  features = deployment_features_parser.parse('randomize_az_placement' => true)
                  expect(features.randomize_az_placement).to eq(true)

                  features = deployment_features_parser.parse('randomize_az_placement' => false)
                  expect(features.randomize_az_placement).to eq(false)
                end
              end
            end
          end

          describe 'converge_variables' do
            context 'when converge_variables is not a boolean' do
              it 'raises an error' do
                expect do
                  deployment_features_parser.parse('converge_variables' => 'vroom')
                end.to raise_error(
                  FeaturesInvalidFormat,
                  "Key 'converge_variables' in 'features' expected to be a boolean, but received 'String'",
                )
              end
            end

            context 'when converge_variables is not present' do
              it 'should default to false' do
                features = deployment_features_parser.parse({})
                expect(features.converge_variables).to eq(false)
              end
            end

            context 'when converge_variables is set' do
              it 'should reflect the set value' do
                features = deployment_features_parser.parse('converge_variables' => true)
                expect(features.converge_variables).to eq(true)

                features = deployment_features_parser.parse('converge_variables' => false)
                expect(features.converge_variables).to eq(false)
              end
            end
          end

          describe 'use_tmpfs_config' do
            context 'when use_tmpfs_config is not a boolean' do
              it 'raises an error' do
                expect do
                  deployment_features_parser.parse('use_tmpfs_config' => 'vroom')
                end.to raise_error(
                  FeaturesInvalidFormat,
                  "Key 'use_tmpfs_config' in 'features' expected to be a boolean, but received 'String'",
                )
              end
            end

            context 'when use_tmpfs_config is not present' do
              it 'should default to nil' do
                features = deployment_features_parser.parse({})
                expect(features.use_tmpfs_config).to eq(nil)
              end
            end

            context 'when use_tmpfs_config is set' do
              it 'should reflect the set value' do
                features = deployment_features_parser.parse('use_tmpfs_config' => true)
                expect(features.use_tmpfs_config).to eq(true)

                features = deployment_features_parser.parse('use_tmpfs_config' => false)
                expect(features.use_tmpfs_config).to eq(false)
              end
            end
          end
        end
      end
    end
  end
end
