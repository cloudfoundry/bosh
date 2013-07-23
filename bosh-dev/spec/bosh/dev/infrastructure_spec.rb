require 'spec_helper'
require 'bosh/dev/infrastructure'

module Bosh::Dev
  describe Infrastructure do
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
