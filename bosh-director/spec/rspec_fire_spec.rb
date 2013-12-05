require 'spec_helper'

class ClassToStub; end

describe 'instance_double (Rspec::Fire::FireObjectDouble)' do
  describe '#initialize' do
    context 'when trying to stub non-existent method' do
      it 'raises an error' do
        expect {
          instance_double('ClassToStub', no_method: nil)
        }.to raise_error(/ClassToStub does not implement.*no_method/m)
      end
    end
  end

  describe '#stub' do
    subject { instance_double('ClassToStub') }

    context 'when using shortcut stub syntax (.stub(method: returned))' do
      context 'when trying to stub non-existent method' do
        it 'raises an error' do
          expect {
            subject.stub(no_method: nil)
          }.to raise_error(/ClassToStub does not implement.*no_method/m)
        end
      end
    end
  end

  #describe 'allow to receive' do
  #  subject { instance_double('ClassToStub') }
  #
  #  context 'when using allow().to receive(mehtod)' do
  #    context 'when trying to stub non-existent method' do
  #      it 'raises an error' do
  #        expect {
  #          allow(subject).to receive(:no_method)
  #        }.to raise_error(/ClassToStub does not implement.*no_method/m)
  #      end
  #    end
  #  end
  #end
end
