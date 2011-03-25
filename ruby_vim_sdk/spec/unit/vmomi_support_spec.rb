require File.dirname(__FILE__) + '/../spec_helper'

describe VimSdk::VmomiSupport do
  describe :qualified_wsdl_name do
    it "should provide qualified WSDL names for builtin types"
    it "should provide qualified WSDL names for array types"
    it "should provide qualified WSDL names for object types"
  end

  describe :wsdl_name do
    it "should provide WSDL names for builtin types"
    it "should provide WSDL names for array types"
    it "should provide WSDL names for object types"
  end

  describe :guess_wsdl_type do
    it "should guess the WSDL type based on an unqualified name"
  end

  describe :compatible_type do
    it "should return itself if the version is compatible"
    it "should return a compatible type if this is not available in the current version"
  end

  describe :wsdl_namespace do
    it "should provide the WSDL namespace for a version"
  end

  describe :version_namespace do
    it "should provide the version namespace"
  end
end

