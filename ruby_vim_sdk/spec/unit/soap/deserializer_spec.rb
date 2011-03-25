require File.dirname(__FILE__) + '/../../spec_helper'

describe VimSdk::Soap::SoapDeserializer do
  it "should deserialize a basic object" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["byte_test", VimSdk::SoapByte, "test_version"],
        ["short_test", VimSdk::SoapShort, "test_version"],
        ["long_test", VimSdk::SoapLong, "test_version"],
        ["int_test", VimSdk::SoapInteger, "test_version"],
        ["float_test", VimSdk::SoapFloat, "test_version"],
        ["double_test", VimSdk::SoapDouble, "test_version"],
        ["bool_test", VimSdk::SoapBoolean, "test_version"],
        ["string_test", String, "test_version"]
      ])
    end
    test_class.finalize

    stub = mock("stub")
    deserializer = VimSdk::Soap::SoapDeserializer.new(stub, "test_version")
    deserializer.deserialize(VimSdk::Soap::DelegatedDocument.new, test_class, false)
    parser = Nokogiri::XML::SAX::Parser.new(deserializer)
    parser.parse("<test xmlns=\"urn:test\"><byte_test>1</byte_test><short_test>2</short_test>" +
        "<long_test>3</long_test><int_test>4</int_test><float_test>1.0</float_test><double_test>2.0</double_test>" +
        "<bool_test>true</bool_test><string_test>test value</string_test></test>")

    result = deserializer.result

    {
      :byte_test => 1,
      :short_test => 2,
      :long_test => 3,
      :int_test => 4,
      :float_test => 1.0,
      :double_test => 2.0,
      :bool_test => true,
      :string_test => "test value"
    }.each do |key, value|
      result.send(key).should == value
    end
  end

  it "should deserialize time" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["time_test", Time, "test_version"]
      ])
    end
    test_class.finalize

    stub = mock("stub")
    deserializer = VimSdk::Soap::SoapDeserializer.new(stub, "test_version")
    deserializer.deserialize(VimSdk::Soap::DelegatedDocument.new, test_class, false)
    parser = Nokogiri::XML::SAX::Parser.new(deserializer)
    parser.parse("<test xmlns=\"urn:test\"><time_test>2011-03-26T21:28:52Z</time_test></test>")

    result = deserializer.result

    {
      :time_test => Time.at(1301174932)
    }.each do |key, value|
      result.send(key).should == value
    end
  end

  it "should deserialize binary" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["binary_test", VimSdk::SoapBinary, "test_version"]
      ])
    end
    test_class.finalize

    stub = mock("stub")
    deserializer = VimSdk::Soap::SoapDeserializer.new(stub, "test_version")
    deserializer.deserialize(VimSdk::Soap::DelegatedDocument.new, test_class, false)
    parser = Nokogiri::XML::SAX::Parser.new(deserializer)
    parser.parse("<test xmlns=\"urn:test\"><binary_test>c29tZSBiaW5hcnkgc3RyaW5n\n</binary_test></test>")

    result = deserializer.result

    {
      :binary_test => "some binary string"
    }.each do |key, value|
      result.send(key).should == value
    end
  end

  it "should deserialize an array" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["array_test", String::TypedArray, "test_version"]
      ])
    end
    test_class.finalize

    stub = mock("stub")
    deserializer = VimSdk::Soap::SoapDeserializer.new(stub, "test_version")
    deserializer.deserialize(VimSdk::Soap::DelegatedDocument.new, test_class, false)
    parser = Nokogiri::XML::SAX::Parser.new(deserializer)
    parser.parse("<test xmlns=\"urn:test\"><array_test>foo</array_test><array_test>bar</array_test></test>")

    result = deserializer.result

    {
      :array_test => ["foo", "bar"]
    }.each do |key, value|
      result.send(key).should == value
    end
  end

  it "should deserialize a class" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
          ["class_test", VimSdk::Vmodl::TypeName, "test_version"],
          ["type_name_test", VimSdk::Vmodl::TypeName, "test_version"]
      ])
    end
    test_class.finalize

    stub = mock("stub")
    deserializer = VimSdk::Soap::SoapDeserializer.new(stub, "test_version")
    deserializer.deserialize(VimSdk::Soap::DelegatedDocument.new, test_class, false)
    parser = Nokogiri::XML::SAX::Parser.new(deserializer)
    parser.parse("<test xmlns=\"urn:test\"><class_test>string</class_test>" +
        "<type_name_test>DataObject</type_name_test></test>")

    result = deserializer.result

    {
      :class_test => String,
      :type_name_test => VimSdk::Vmodl::DataObject
    }.each do |key, value|
      result.send(key).should == value
    end
  end

  it "should deserialize an inherited type" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["test", String, "test_version"]
      ])
    end
    test_class.finalize

    test_class2 = Class.new(test_class) do
      @type_info = VimSdk::DataType.new("test.Test2", "Test2", "test.Test", "test_version", [
        ["test2", String, "test_version"]
      ])
    end
    test_class2.finalize
    VimSdk::VmomiSupport.stub!(:loaded_wsdl_type).with("urn:test", "Test2").and_return(test_class2)

    stub = mock("stub")
    deserializer = VimSdk::Soap::SoapDeserializer.new(stub, "test_version")
    deserializer.deserialize(VimSdk::Soap::DelegatedDocument.new, test_class, false)
    parser = Nokogiri::XML::SAX::Parser.new(deserializer)
    parser.parse("<test xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"urn:test\" xsi:type=\"Test2\"><test>foo</test><test2>bar</test2></test>")

    result = deserializer.result

    {
      :test => "foo",
      :test2 => "bar"
    }.each do |key, value|
      result.send(key).should == value
    end
  end

  it "should deserialize a managed object"

  it "should deserialize an enum"

  it "should fail to deserialize a bad boolean value"
end

describe VimSdk::Soap::SoapResponseDeserializer do
  it "should deserialize a fault"
  it "should deserialize a response"
end
