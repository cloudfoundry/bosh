require File.dirname(__FILE__) + '/../../spec_helper'

describe VimSdk::Soap::SoapSerializer do
  it "should serialize a simple object" do
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

    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class, "test_version").and_return(test_class)
    VimSdk::VmomiSupport.stub!(:wsdl_namespace).with("test_version").and_return("urn:test")

    writer = StringIO.new
    serializer = VimSdk::Soap::SoapSerializer.new(writer, "test_version", VimSdk::SOAP_NAMESPACE_MAP.dup)

    property = VimSdk::Property.new("test", test_class, "test_version")
    value = test_class.new(:byte_test => 1, :short_test => 2, :long_test => 3, :int_test => 4, :float_test => 1.0,
                           :double_test => 2.0, :bool_test => true, :string_test => "test value")

    serializer.serialize(value, property)
    writer.string.should == "<test xmlns=\"urn:test\"><byte_test>1</byte_test><short_test>2</short_test>" +
        "<long_test>3</long_test><int_test>4</int_test><float_test>1.0</float_test><double_test>2.0</double_test>" +
        "<bool_test>true</bool_test><string_test>test value</string_test></test>"
  end

  it "should serialize time" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["time_test", Time, "test_version"]
      ])
    end
    test_class.finalize

    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class, "test_version").and_return(test_class)
    VimSdk::VmomiSupport.stub!(:wsdl_namespace).with("test_version").and_return("urn:test")

    writer = StringIO.new
    serializer = VimSdk::Soap::SoapSerializer.new(writer, "test_version", VimSdk::SOAP_NAMESPACE_MAP.dup)

    property = VimSdk::Property.new("test", test_class, "test_version")
    value = test_class.new(:time_test => Time.at(1301174932))

    serializer.serialize(value, property)
    writer.string.should == "<test xmlns=\"urn:test\"><time_test>2011-03-26T21:28:52Z</time_test></test>"
  end

  it "should serialize binary" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["binary_test", VimSdk::SoapBinary, "test_version"]
      ])
    end
    test_class.finalize

    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class, "test_version").and_return(test_class)
    VimSdk::VmomiSupport.stub!(:wsdl_namespace).with("test_version").and_return("urn:test")

    writer = StringIO.new
    serializer = VimSdk::Soap::SoapSerializer.new(writer, "test_version", VimSdk::SOAP_NAMESPACE_MAP.dup)

    property = VimSdk::Property.new("test", test_class, "test_version")
    value = test_class.new(:binary_test => "some binary string")

    serializer.serialize(value, property)
    writer.string.should == "<test xmlns=\"urn:test\"><binary_test>c29tZSBiaW5hcnkgc3RyaW5n\n</binary_test></test>"
  end

  it "should serialize classes" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["class_test", VimSdk::Vmodl::TypeName, "test_version"],
        ["type_name_test", VimSdk::Vmodl::TypeName, "test_version"]
      ])
    end
    test_class.finalize

    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class, "test_version").and_return(test_class)
    VimSdk::VmomiSupport.stub!(:wsdl_namespace).with("test_version").and_return("urn:test")

    writer = StringIO.new
    serializer = VimSdk::Soap::SoapSerializer.new(writer, "test_version", VimSdk::SOAP_NAMESPACE_MAP.dup)

    property = VimSdk::Property.new("test", test_class, "test_version")
    value = test_class.new(:class_test => String, :type_name_test => VimSdk::Vmodl::TypeName.new("DataObject"))

    serializer.serialize(value, property)
    writer.string.should == "<test xmlns=\"urn:test\"><class_test>string</class_test>" +
        "<type_name_test>DataObject</type_name_test></test>"
  end

  it "should serialize arrays" do
    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["array_test", String::TypedArray, "test_version"]
      ])
    end
    test_class.finalize

    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class, "test_version").and_return(test_class)
    VimSdk::VmomiSupport.stub!(:wsdl_namespace).with("test_version").and_return("urn:test")

    writer = StringIO.new
    serializer = VimSdk::Soap::SoapSerializer.new(writer, "test_version", VimSdk::SOAP_NAMESPACE_MAP.dup)

    property = VimSdk::Property.new("test", test_class, "test_version")
    value = test_class.new(:array_test => ["foo", "bar"])

    serializer.serialize(value, property)
    writer.string.should == "<test xmlns=\"urn:test\"><array_test>foo</array_test><array_test>bar</array_test></test>"
  end

  it "should serialize managed objects" do
    test_managed_class = Class.new(VimSdk::Vmodl::ManagedObject) do
      @type_info = VimSdk::ManagedType.new("test.ManagedTest", "ManagedTest", "ManagedObject", "test_version", [], [])
    end
    test_managed_class.finalize

    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["mob_test", test_managed_class, "test_version"]
      ])
    end
    test_class.finalize

    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class, "test_version").and_return(test_class)
    VimSdk::VmomiSupport.stub!(:wsdl_namespace).with("test_version").and_return("urn:test")

    writer = StringIO.new
    serializer = VimSdk::Soap::SoapSerializer.new(writer, "test_version", VimSdk::SOAP_NAMESPACE_MAP.dup)

    property = VimSdk::Property.new("test", test_class, "test_version")
    value = test_class.new(:mob_test => test_managed_class.new("some mob id"))

    serializer.serialize(value, property)
    writer.string.should == "<test xmlns=\"urn:test\"><mob_test type=\"ManagedTest\">some mob id</mob_test></test>"
  end

  it "should serialize any type" do
    test_managed_class = Class.new(VimSdk::Vmodl::ManagedObject) do
      @type_info = VimSdk::ManagedType.new("test.ManagedTest", "ManagedTest", "ManagedObject", "test_version", [], [])
    end
    test_managed_class.finalize

    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["byte_test", Object, "test_version"],
        ["short_test", Object, "test_version"],
        ["long_test", Object, "test_version"],
        ["int_test", Object, "test_version"],
        ["float_test", Object, "test_version"],
        ["double_test", Object, "test_version"],
        ["bool_test", Object, "test_version"],
        ["string_test", Object, "test_version"],
        ["time_test", Object, "test_version"],
        ["binary_test", Object, "test_version"],
        ["mob_test", Object, "test_version"]
      ])
    end
    test_class.finalize

    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class, "test_version").and_return(test_class)
    VimSdk::VmomiSupport.stub!(:wsdl_namespace).with("test_version").and_return("urn:test")

    writer = StringIO.new
    serializer = VimSdk::Soap::SoapSerializer.new(writer, "test_version", VimSdk::SOAP_NAMESPACE_MAP.dup)

    property = VimSdk::Property.new("test", test_class, "test_version")
    value = test_class.new(:byte_test => VimSdk::SoapByte.new(1), :short_test => VimSdk::SoapShort.new(2),
                           :long_test => VimSdk::SoapLong.new(3), :int_test => 4, :float_test => 1.0,
                           :double_test => VimSdk::SoapDouble.new(2.0), :bool_test => true,
                           :string_test => "test value", :time_test => Time.at(1301174932),
                           :binary_test => VimSdk::SoapBinary.new("some binary string"),
                           :mob_test => test_managed_class.new("some mob id"))

    serializer.serialize(value, property)
    writer.string.should == "<test xmlns=\"urn:test\"><byte_test xsi:type=\"xsd:byte\">1</byte_test>" +
        "<short_test xsi:type=\"xsd:short\">2</short_test><long_test xsi:type=\"xsd:long\">3</long_test>" +
        "<int_test xsi:type=\"xsd:int\">4</int_test><float_test xsi:type=\"xsd:float\">1.0</float_test>" +
        "<double_test xsi:type=\"xsd:double\">2.0</double_test><bool_test xsi:type=\"xsd:boolean\">true</bool_test>" +
        "<string_test xsi:type=\"xsd:string\">test value</string_test>" +
        "<time_test xsi:type=\"xsd:dateTime\">2011-03-26T21:28:52Z</time_test>" +
        "<binary_test xsi:type=\"xsd:base64Binary\">c29tZSBiaW5hcnkgc3RyaW5n\n</binary_test>" +
        "<mob_test xmlns:vim25=\"urn:vim25\" xsi:type=\"vim25:ManagedObject\" type=\"ManagedTest\">" +
        "some mob id</mob_test></test>"
  end

  it "should serialize any type array" do
    test_managed_class = Class.new(VimSdk::Vmodl::ManagedObject) do
      @type_info = VimSdk::ManagedType.new("test.ManagedTest", "ManagedTest", "ManagedObject", "test_version", [], [])
    end
    test_managed_class.finalize

    test_class = Class.new(VimSdk::Vmodl::DataObject) do
      @type_info = VimSdk::DataType.new("test.Test", "Test", "DataObject", "test_version", [
        ["basic_test", Object, "test_version"],
        ["class_test", Object, "test_version"],
        ["mob_test", Object, "test_version"]
      ])
    end
    test_class.finalize

    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class, "test_version").and_return(test_class)
    VimSdk::VmomiSupport.stub!(:wsdl_namespace).with("test_version").and_return("urn:test")

    writer = StringIO.new
    serializer = VimSdk::Soap::SoapSerializer.new(writer, "test_version", VimSdk::SOAP_NAMESPACE_MAP.dup)

    property = VimSdk::Property.new("test", test_class, "test_version")
    value = test_class.new(:basic_test => ["hello", "world"], :class_test => [String, Float, VimSdk::Vmodl::DataObject],
                           :mob_test => [test_managed_class.new("some mob id")])

    serializer.serialize(value, property)
    writer.string.should == "<test xmlns=\"urn:test\">" +
        "<basic_test xmlns:vim25=\"urn:vim25\" xsi:type=\"vim25:ArrayOfString\"><string>hello</string>" +
        "<string>world</string></basic_test><class_test xmlns:vim25=\"urn:vim25\" xsi:type=\"vim25:ArrayOfString\">" +
        "<string>string</string><string>float</string><string>DataObject</string></class_test>" +
        "<mob_test xmlns:vim25=\"urn:vim25\" xsi:type=\"vim25:ArrayOfManagedObject\">" +
        "<ManagedObjectReference type=\"ManagedTest\">some mob id</ManagedObjectReference></mob_test></test>"
  end

  it "should serialize inherited types" do
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

    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class, "test_version").and_return(test_class)
    VimSdk::VmomiSupport.stub!(:compatible_type).with(test_class2, "test_version").and_return(test_class2)
    VimSdk::VmomiSupport.stub!(:wsdl_namespace).with("test_version").and_return("urn:test")

    writer = StringIO.new
    serializer = VimSdk::Soap::SoapSerializer.new(writer, "test_version", VimSdk::SOAP_NAMESPACE_MAP.dup)

    property = VimSdk::Property.new("test", test_class, "test_version")
    value = test_class2.new(:test => "foo", :test2 => "bar")
    serializer.serialize(value, property)
    writer.string.should == "<test xmlns=\"urn:test\" xsi:type=\"Test2\"><test>foo</test><test2>bar</test2></test>"
  end

  it "should fail serializing native ruby arrays as any type"

  it "should serialize a fault"
end
