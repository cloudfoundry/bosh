require File.dirname(__FILE__) + '/../spec_helper'

describe VimSdk::VmodlHelper do
  describe :camelize do
    it "should camelize simple forms" do
      VimSdk::VmodlHelper.camelize("Foo").should == "Foo"
      VimSdk::VmodlHelper.camelize("foo").should == "Foo"
      VimSdk::VmodlHelper.camelize("foo_bar").should == "FooBar"
    end
  end

  describe :underscore do
    it "should underscore simple forms" do
      VimSdk::VmodlHelper.underscore("test").should == "test"
      VimSdk::VmodlHelper.underscore("thisIsAProperty").should == "this_is_a_property"
    end

    it "should underscore exceptional forms" do
      VimSdk::VmodlHelper.underscore("numCPUs").should == "num_cpus"
    end
  end

  describe :vmodl_type_to_ruby do
    it "should convert VMODL type name to ruby" do
      VimSdk::VmodlHelper.vmodl_type_to_ruby("vmodl.query.PropertyCollector.Change.Op").should ==
          "Vmodl.Query.PropertyCollector.Change.Op"
    end
  end

  describe :vmodl_property_to_ruby do
    it "should convert VMODL property name to ruby" do
      VimSdk::VmodlHelper.vmodl_property_to_ruby("testProperty").should == "test_property"
    end
  end
end

