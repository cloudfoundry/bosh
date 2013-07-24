require 'spec_helper'
require 'bosh/dev/infrastructure'

module Bosh::Dev
  describe Infrastructure do
    describe '.for' do
      it 'sets name' do
        expect(Infrastructure.for('openstack').name).to eq('openstack')
      end

      context 'with an invalid infrastructure_name' do
        it 'raises an ArgumentError' do
          expect {
            Infrastructure.for('BAD_INFRASTRUCTURE')
          }.to raise_error(ArgumentError, /invalid infrastructure: BAD_INFRASTRUCTURE/)
        end
      end
    end

    describe '#light?' do
      subject { Infrastructure.for('aws')}

      context 'when infrastructure_name is "aws"' do
        it { should be_light }
      end

      (Infrastructure::ALL - [Infrastructure::AWS]).each do |infrastracture_name|
        context "when infrastructure_name is '#{infrastracture_name}'" do
          subject { Infrastructure.for(infrastracture_name)}

          it { should_not be_light }
        end
      end
    end
  end
end
