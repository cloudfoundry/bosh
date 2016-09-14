require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Tag do
  def make(spec)
    BD::DeploymentPlan::Tag.parse(spec)
  end

  let(:valid_spec) do
    {
      'mytag' => 'foobar'
    }
  end

  let(:missing_value_spec) do
    {
      'mytag' => nil
    }
  end

  let(:not_string_key_spec) do
    {
      {'bad' => 'key, not string'} => 'wontwork',
    }
  end

  let(:not_string_value_spec) do
    {
      'my-tag' => {'bad' => 'value, not string'}
    }
  end

  describe '#parse' do
    it 'parses key and value' do
      tag = make(valid_spec)
      expect(tag.key).to eq('mytag')
      expect(tag.value).to eq('foobar')
    end

    context 'key' do
      context 'when it is not a String' do
        it 'ValidationInvalidType error' do
          expect {make(not_string_key_spec) }.to raise_error Bosh::Director::ValidationInvalidType
        end
      end
    end

    context 'value' do
      context 'when it is empty' do
        it 'raises ValidationMissingField error' do
          expect{ make(missing_value_spec) }.to raise_error BD::ValidationMissingField
        end
      end

      context 'when it is not a String' do
        it 'ValidationInvalidType error' do
          expect {make(not_string_value_spec) }.to raise_error Bosh::Director::ValidationInvalidType
        end
      end
    end
  end
end
