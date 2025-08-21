require 'spec_helper'

describe Bosh::Director::ValidationHelper do
  let(:obj) { Object.new.tap { |o| o.extend(Bosh::Director::ValidationHelper) } }

  it 'should pass if required fields are present' do
    expect(obj.safe_property({ 'test' => 1 }, 'test')).to eq(1)
  end

  describe 'class equality' do
    context 'when field value matches asked class' do
      it 'returns value' do
        value = obj.safe_property({ 'test' => 1 }, 'test', class: Numeric)
        expect(value).to eq(1)
      end
    end

    context 'when field value class is a Numeric and asked class is String' do
      it 'converts value to a string' do
        value = obj.safe_property({ 'test' => 1 }, 'test', class: String)
        expect(value).to eq('1')
      end
    end

    context 'when field value does not match asked class' do
      it 'raises an error' do
        expect do
          obj.safe_property({ 'test' => 1 }, 'test', class: Array)
        end.to raise_error(
          Bosh::Director::ValidationInvalidType,
          "Property 'test' value (1) did not match the required type 'Array'",
        )
      end
    end

    context 'when the field value is not present, and the default is supplied, and the default is the wrong type' do
      it 'raises an error' do
        expect do
          obj.safe_property({}, 'test', class: Array, default: 1)
        end.to raise_error(
          Bosh::Director::ValidationInvalidType,
          "Default value for property 'test' value (1) did not match the required type 'Array'",
        )
      end
    end

    context 'when the default is supplied, and the default is nil' do
      it 'does not raise' do
        expect { obj.safe_property({}, 'test', class: Array, default: nil) }.to_not raise_error
      end
    end

    context 'when the field value is present, and the default is supplied, and the default is the wrong type' do
      it 'raises an error' do
        expect do
          obj.safe_property({ 'test' => ['a'] }, 'test', class: Array, default: 1)
        end.to raise_error(
          Bosh::Director::ValidationInvalidType,
          "Default value for property 'test' value (1) did not match the required type 'Array'",
        )
      end
    end

    context 'when the field value is present, and the min is supplied, and the default is less than the min' do
      it 'raises an error' do
        expect do
          obj.safe_property({ 'test' => 3 }, 'test', class: Numeric, default: 1, min: 2)
        end.to raise_error(
          Bosh::Director::ValidationViolatedMin,
          "Default value for property 'test' value (1) should be greater than 2",
        )
      end
    end

    context 'when the field value is present, and the max is supplied, and the default is greater than the max' do
      it 'raises an error' do
        expect do
          obj.safe_property({ 'test' => 1 }, 'test', class: Numeric, default: 3, max: 2)
        end.to raise_error(
          Bosh::Director::ValidationViolatedMax,
          "Default value for property 'test' value (3) should be less than 2",
        )
      end
    end
  end

  describe 'optionality' do
    def self.it_returns_value(hash, options, expected_value)
      it "returns #{expected_value.inspect}" do
        value = obj.safe_property(hash, 'test', options)
        expect(value).to eq(expected_value)
      end
    end

    def self.it_raises_required_property_error(hash, options)
      it 'raises an error because required property is missing' do
        expect do
          obj.safe_property(hash, 'test', options)
        end.to raise_error(
          Bosh::Director::ValidationMissingField,
          "Required property 'test' was not specified in object (#{hash.inspect})",
        )
      end
    end

    def self.it_raises_unknown_object_error(hash, options)
      it "raises an error because #{hash.inspect} cannot be used for property lookup" do
        expect do
          obj.safe_property(hash, 'test', options)
        end.to raise_error(
          Bosh::Director::ValidationInvalidType,
          %{Object (#{hash.inspect}) did not match the required type 'Hash'},
        )
      end
    end

    context 'when optional option is true' do
      options = { optional: true }

      context 'when the object is nil' do
        it_returns_value(nil, options, nil)
      end

      context 'when the object is not a hash' do
        it_raises_unknown_object_error('not-hash', options)
      end

      context 'when the property is not found' do
        it_returns_value({}, options, nil)
      end

      context 'when the property is found' do
        it_returns_value({ 'test' => 'value' }, options, 'value')
      end

      context 'when the hash is nil and the default is false and the class is boolean' do
        it_returns_value(nil, options.merge(class: :boolean, default: false), false)
      end
    end

    context 'when optional option is false' do
      options = { optional: false }

      context 'when the object is nil' do
        it_raises_required_property_error(nil, options)
      end

      context 'when the object is not a hash' do
        it_raises_unknown_object_error('not-hash', options)
      end

      context 'when the property is not found' do
        it_raises_required_property_error({}, options)
      end

      context 'when the property is found' do
        it_returns_value({ 'test' => 'value' }, options, 'value')
      end
    end

    context 'when optional option is not passed' do
      options = { optional: nil }

      context 'when the object is nil' do
        it_raises_required_property_error(nil, options)
      end

      context 'when the object is not a hash' do
        it_raises_unknown_object_error('not-hash', options)
      end

      context 'when the property is not found' do
        it_raises_required_property_error({}, options)
      end

      context 'when the property is found' do
        it_returns_value({ 'test' => 'value' }, options, 'value')
      end
    end
  end

  describe 'when length is constrained' do
    it 'should pass if strings do not have constraints' do
      expect(obj.safe_property({ 'test' => '' }, 'test', class: String)).to eql('')
    end

    it 'should pass if strings pass min constraints' do
      expect(obj.safe_property({ 'test' => 'abc' }, 'test', min_length: 2)).to eql('abc')
    end

    it 'should pass if strings pass max constraints' do
      expect(obj.safe_property({ 'test' => 'abc' }, 'test', max_length: 4)).to eql('abc')
    end

    it 'should fail if strings do not pass min constraints' do
      expect do
        expect(obj.safe_property({ 'test' => 'abc' }, 'test', min_length: 4)).to eql('abc')
      end.to raise_error(
        Bosh::Director::ValidationViolatedMin,
        "'test' length (3) should be greater than 4",
      )
    end

    it 'should fail if strings do not pass max constraints' do
      expect do
        expect(obj.safe_property({ 'test' => 'abc' }, 'test', max_length: 2)).to eql('abc')
      end.to raise_error(
        Bosh::Director::ValidationViolatedMax,
        "'test' length (3) should be less than 2",
      )
    end
  end

  describe 'when numeric constraints' do
    it 'should pass if numbers do not have constraints' do
      expect(obj.safe_property({ 'test' => 1 }, 'test', class: Numeric)).to eql(1)
    end

    it 'should pass if numbers pass min constraints' do
      expect(obj.safe_property({ 'test' => 3 }, 'test', min: 2)).to eql(3)
    end

    it 'should pass if numbers pass max constraints' do
      expect(obj.safe_property({ 'test' => 3 }, 'test', max: 4)).to eql(3)
    end

    it 'should fail if numbers do not pass min constraints' do
      expect do
        expect(obj.safe_property({ 'test' => 3 }, 'test', min: 4)).to eql(3)
      end.to raise_error(
        Bosh::Director::ValidationViolatedMin,
        "'test' value (3) should be greater than 4",
      )
    end

    it 'should fail if numbers do not pass max constraints' do
      expect do
        expect(obj.safe_property({ 'test' => 3 }, 'test', max: 2)).to eql(3)
      end.to raise_error(
        Bosh::Director::ValidationViolatedMax,
        "'test' value (3) should be less than 2",
      )
    end
  end
end
