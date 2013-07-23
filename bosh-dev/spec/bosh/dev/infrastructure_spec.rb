require 'spec_helper'
require 'bosh/dev/infrastructure'

module Bosh::Dev
  describe Infrastructure do
    describe '#initialize' do
      it 'sets name' do
        expect(Infrastructure.new('openstack').name).to eq('openstack')
      end

      context 'with an invalid infrastructure_name' do
        it 'raises an ArgumentError' do
          expect {
            Infrastructure.new('BAD_INFRASTRUCTURE')
          }.to raise_error(ArgumentError, /invalid infrastructure: BAD_INFRASTRUCTURE/)
        end
      end
    end

    describe '#light?' do
      subject { Infrastructure.new('aws')}

      context 'when infrastructure_name is "aws"' do
        it { should be_light }
      end

      (Infrastructure::ALL - [Infrastructure::AWS]).each do |infrastracture_name|
        context "when infrastructure_name is '#{infrastracture_name}'" do
          subject { Infrastructure.new(infrastracture_name)}

          it { should_not be_light }
        end
      end
    end
  end
end
