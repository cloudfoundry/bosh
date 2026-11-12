require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe SubnetDistribution do
    describe '.build' do
      let(:networks) { {} }

      it 'builds the least-loaded strategy for "least_loaded"' do
        expect(described_class.build('least_loaded', networks: networks))
          .to be_a(SubnetDistribution::LeastLoaded)
      end

      it 'builds the first-fit strategy for "first_fit"' do
        expect(described_class.build('first_fit', networks: networks))
          .to be_a(SubnetDistribution::FirstFit)
      end

      it 'defaults to first-fit when the value is nil (unset)' do
        expect(described_class.build(nil, networks: networks)).to be_a(SubnetDistribution::FirstFit)
      end

      it 'raises ValidationInvalidValue for a non-nil unknown value instead of silently defaulting' do
        expect { described_class.build('bogus', networks: networks) }
          .to raise_error(Bosh::Director::ValidationInvalidValue, /Invalid dynamic_subnet_strategy 'bogus'/)
      end
    end

    it 'exposes the allowed strategy names with first_fit as the default' do
      expect(described_class::ALLOWED).to contain_exactly('first_fit', 'least_loaded')
      expect(described_class::DEFAULT).to eq('first_fit')
    end
  end
end
