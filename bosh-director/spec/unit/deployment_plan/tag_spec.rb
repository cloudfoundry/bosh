require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Tag do
  def make(spec)
    BD::DeploymentPlan::Tag.parse(spec)
  end

  def make_tag(key, value)
    BD::Models::Tag.make(:key => key, :value => value)
  end

  let(:valid_spec) do
    {
      'key' => 'mytag',
      'value' => 'foobar'
    }
  end

  let(:missing_key_spec) do
    {
      'value' => 'foobar'
    }
  end

  let(:missing_value_spec) do
    {
      'key' => 'my-tag'
    }
  end

  let(:not_string_key_spec) do
    {
      'key' => {'bad' => 'key, not string'},
      'value' => 'foobar'
    }
  end

  let(:not_string_value_spec) do
    {
      'key' => 'my-tag',
      'value' => {'bad' => 'value, not string'}
    }
  end

  describe '#parse' do
    it 'parses key and value' do
      tag = make(valid_spec)
      expect(tag.key).to eq(:mytag)
      expect(tag.value).to eq('foobar')
    end

    context 'key' do
      context 'when it is missing' do
        it 'raises ValidationMissingField error' do
          expect{ make(missing_key_spec) }.to raise_error BD::ValidationMissingField
        end
      end

      context 'when it is not a String' do
        it 'ValidationInvalidType error' do
          expect {make(not_string_key_spec) }.to raise_error Bosh::Director::ValidationInvalidType
        end
      end
    end

    context 'value' do
      context 'when it is missing' do
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
