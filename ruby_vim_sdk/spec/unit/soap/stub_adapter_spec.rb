require File.dirname(__FILE__) + '/../../spec_helper'

describe VimSdk::Soap::StubAdapter do
  before(:each) do
    @http_client = HTTPClient.new
    log_path = ""
    @host = "localhost"
    @version = "vim.version.version6"
    @http_client.send_timeout = 14400
    @http_client.receive_timeout = 14400
    @http_client.connect_timeout = 4
    @http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @http_client.set_cookie_store('./cookie.dat')
    @stub = VimSdk::Soap::StubAdapter.new(@host, @version ,@http_client)
  end

  it "should send a method invocation" do
    managed_object = double("managed_object")
    method_info = double("method_info")
    arguments = double("arguments")
    info_arguments = double("info_arguments")
    info_arguments_zip_return = double("inf_arguments_zip_return")
    hash_one = Hash.new
    arg1 = double("arg1", :version => "test_version", :type => "test_type",:wsdl_name => "test_name")
    arg2 = double("arg2", :version => "test_version", :type => "test_type",:wsdl_name => "test_name")
    hash_one[arg1] = "value1"
    hash_one[arg2] = "value2"

    info_arguments.stub(:zip).with(arguments).and_return(hash_one)
    method_info.stub(:version).and_return(@version)
    method_info.stub(:wsdl_name).and_return('test_wsdl')
    method_info.stub(:arguments).and_return(info_arguments)

    #expect this error as the hostname is not a valid or willl refuse connection on build server
    expected_result_1 = "Errno::EADDRNOTAVAIL"
    expected_result_2 = "Errno::ECONNREFUSED"
    output = ''
    begin
      @stub.invoke_method(managed_object, method_info, arguments, nil)
    rescue Exception => e
      output = e.class.to_s
    end

    expect_check = (output == expected_result_1) || (output == expected_result_2)
    expect_check.should be_true
  end

  it "should send a property invocation" do
    @stub = VimSdk::Soap::StubAdapter.new(@host, "vim.version.version1" ,@http_client)
    managed_object = double('managed_object')
    property_info = double('property_info')
    property_info.stub(:version).and_return('vim.version.version1')
    property_info.stub(:wsdl_name).and_return('test_wsdl')

    expected_result_1 = "Errno::EADDRNOTAVAIL"
    expected_result_2 = "Errno::ECONNREFUSED"

    output = ''
    begin
      @stub.invoke_property(managed_object, property_info)
   rescue Exception => e
      output = e.class.to_s
    end

    expect_check = (output == expected_result_1) || (output == expected_result_2)
    expect_check.should eq(true)
  end

  it "should expose the underlying cookie" do
    @stub.cookie.should be_nil
  end

  it "should serialize a plain argument" do
    @stub = VimSdk::Soap::StubAdapter.new(@host, "vim.version.version1" ,@http_client)
    object = "Plain Object";
    info = double("info")
    info.stub(:version).and_return('vim.version.version1')
    info.stub(:type).and_return('string')
    info.stub(:wsdl_name).and_return('test_wsdl')
    version = "vim.version.version1"
    @stub.serialize(object, info, version,  VimSdk::SOAP_NAMESPACE_MAP.dup)
  end

  it "should serialize an array argument"

  it "should return hostname set in StubAdapter constructor" do
    @stub.uri.should ==  URI.parse(@host)
  end

  it "should return the version set" do
    @stub.version.should ==  @version
  end

  it "should return the http_client set" do
    @stub.http_client.should ==  @http_client
  end
end
