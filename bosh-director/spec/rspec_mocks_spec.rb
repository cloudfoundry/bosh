require 'spec_helper'

class ClassToStub
  def self.method_with_1_arg(arg); end
  def      method_with_1_arg(arg); end
end

describe 'instance_double' do
  describe '#initialize' do
    context 'when trying to initialize with non-existent class' do
      it 'raises an error' do
        expect {
          instance_double('ClassToStubThatDoesNotExist')
        }.to raise_error(/NamedObjectReference/m) # error in Rspec should be NameError
      end
    end

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
end

describe 'class_double' do
  describe '#initialize' do
    context 'when trying to initialize with non-existent class' do
      it 'raises an error' do
        expect {
          class_double('ClassToStubThatDoesNotExist')
        }.to raise_error(/NamedObjectReference/m) # error in Rspec should be NameError
      end
    end
  end
end

describe 'allow().to receive(method)' do
  context 'when trying to stub non-existent instance method' do
    it 'raises an error' do
      expect {
        allow(instance_double('ClassToStub')).to receive(:no_method)
      }.to raise_error(/ClassToStub does not implement.*no_method/m)
    end
  end

  context 'when trying to stub non-existent class method' do
    it 'raises an error' do
      expect {
        allow(class_double('ClassToStub')).to receive(:no_method)
      }.to raise_error(/ClassToStub does not implement.*no_method/m)
    end
  end
end

describe 'expect().to receive(method)' do
  context 'when trying to expect on non-existent instance method' do
    it 'raises an error' do
      expect {
        expect(instance_double('ClassToStub')).to receive(:no_method)
      }.to raise_error(/ClassToStub does not implement.*no_method/m)
    end
  end

  context 'when trying to expect on non-existent class method' do
    it 'raises an error' do
      expect {
        expect(class_double('ClassToStub')).to receive(:no_method)
      }.to raise_error(/ClassToStub does not implement.*no_method/m)
    end
  end

  context 'when trying to expect on class method with wrong number of args (no args)' do
    it 'raises an error' do
      expect {
        expect(class_double('ClassToStub')).to receive(:method_with_1_arg).with(no_args)
      }.to raise_error(/Wrong number of arguments. Expected 1, got 0./m)
    end
  end

  context 'when trying to expect on class method with wrong number of args (too many)' do
    it 'raises an error' do
      expect {
        expect(class_double('ClassToStub')).to receive(:method_with_1_arg).with(1, 2)
      }.to raise_error(/Wrong number of arguments. Expected 1, got 2./m)
    end
  end

  context 'when trying to expect on .new class method with wrong number of args' do
    xit 'raises an error' do
      # .new class method takes variable number of arguments
      # so when rspec-mocks verifies arity fails to realize that
      # #initialize instance method takes different number of args.
      expect {
        expect(class_double('ClassToStub')).to receive(:new).with(1, 2, 3)
      }.to raise_error(/Wrong number of arguments. Expected 0, got 3./m)
    end
  end
end
