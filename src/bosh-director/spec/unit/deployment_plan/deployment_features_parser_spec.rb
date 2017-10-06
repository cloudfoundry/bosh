require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DeploymentFeaturesParser do
    subject(:deployment_features_parser) { described_class.new(logger) }

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
            expect {
              deployment_features_parser.parse('vroom')
            }.to raise_error FeaturesInvalidFormat, "Key 'features' expects a Hash, but received 'String'"
          end
        end

        context 'when features spec is a HASH' do
          describe 'use_dns_addresses' do
            context 'when use_dns_addresses is NOT specified' do
              it 'defaults use_dns_addresses value to nil' do
                features = deployment_features_parser.parse({})
                expect(features.use_dns_addresses).to be_nil
              end
            end

            context 'when use_dns_addresses is specified' do
              context 'when use_dns_addresses is NOT a boolean' do
                it 'raises an error' do
                  expect {
                    deployment_features_parser.parse({'use_dns_addresses' => 'vroom'})
                  }.to raise_error FeaturesInvalidFormat, "Key 'use_dns_addresses' in 'features' expected to be a boolean, but received 'String'"
                end
              end

              context 'when use_dns_addresses is a boolean' do
                it 'sets the use_dns_addresses value to the features object' do
                  features = deployment_features_parser.parse({'use_dns_addresses' => true})
                  expect(features.use_dns_addresses).to eq(true)

                  features = deployment_features_parser.parse({'use_dns_addresses' => false})
                  expect(features.use_dns_addresses).to eq(false)
                end
              end
            end
          end

          describe 'use_short_dns_addresses' do
            context 'when use_short_dns_addresses is NOT specified' do
              it 'defaults use_short_dns_addresses value to nil' do
                features = deployment_features_parser.parse({})
                expect(features.use_short_dns_addresses).to be_nil
              end
            end

            context 'when use_short_dns_addresses is specified' do
              context 'when use_short_dns_addresses is NOT a boolean' do
                it 'raises an error' do
                  expect {
                    deployment_features_parser.parse({'use_short_dns_addresses' => 'vroom'})
                  }.to raise_error FeaturesInvalidFormat, "Key 'use_short_dns_addresses' in 'features' expected to be a boolean, but received 'String'"
                end
              end

              context 'when use_short_dns_addresses is a boolean' do
                it 'sets the use_short_dns_addresses value to the features object' do
                  features = deployment_features_parser.parse({'use_short_dns_addresses' => true})
                  expect(features.use_short_dns_addresses).to eq(true)

                  features = deployment_features_parser.parse({'use_short_dns_addresses' => false})
                  expect(features.use_short_dns_addresses).to eq(false)
                end
              end
            end
          end
        end
      end
    end
  end
end
