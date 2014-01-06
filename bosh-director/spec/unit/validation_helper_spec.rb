require 'spec_helper'

describe Bosh::Director::ValidationHelper do
  let(:obj) { Object.new.tap { |o| o.extend(Bosh::Director::ValidationHelper) } }

  it 'should pass if required fields are present' do
    obj.safe_property({'test' => 1}, 'test', :required => true).should eql(1)
  end

  it 'should fail if required fields are missing' do
    lambda {
      obj.safe_property({'testing' => 1}, 'test', :required => true)
    }.should raise_error(
      Bosh::Director::ValidationMissingField,
      "Required property `test' was not specified in Object",
    )
  end

  it 'should pass if fields match their class' do
    obj.safe_property({'test' => 1}, 'test', :class => Numeric).should eql(1)
  end

  it 'should convert numbers to strings when needed' do
    obj.safe_property({'test' => 1}, 'test', :class => String).should eql('1')
  end

  it 'should fail if fields do not match their class' do
    lambda {
      obj.safe_property({'test' => 1}, 'test', :class => Array)
    }.should raise_error(
      Bosh::Director::ValidationInvalidType,
      "Property `test' (value 1) did not match the required type `Array'",
    )
  end

  it 'should pass if numbers do not have constraints' do
    obj.safe_property({'test' => 1}, 'test', :class => Numeric).should eql(1)
  end

  it 'should pass if numbers pass min constraints' do
    obj.safe_property({'test' => 3}, 'test', :min => 2).should eql(3)
  end

  it 'should pass if numbers pass max constraints' do
    obj.safe_property({'test' => 3}, 'test', :max => 4).should eql(3)
  end

  it 'should fail if numbers do not pass min constraints' do
    lambda {
      obj.safe_property({'test' => 3}, 'test', :min => 4).should eql(3)
    }.should raise_error(
      Bosh::Director::ValidationViolatedMin, 
      "`test' value (3) should be greater than 4",
    )
  end

  it 'should fail if numbers do not pass max constraints' do
    lambda {
      obj.safe_property({'test' => 3}, 'test', :max => 2).should eql(3)
    }.should raise_error(
      Bosh::Director::ValidationViolatedMax, 
      "`test' value (3) should be less than 2",
    )
  end
end
