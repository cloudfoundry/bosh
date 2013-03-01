require "spec_helper"
$:.unshift(File.expand_path("../../lib", __FILE__))

describe Bosh::Clouds::Provider do
  it "should create a provider instance" do

    provider = Bosh::Clouds::Provider.create("spec", {})
    provider.should be_kind_of(Bosh::Clouds::Spec)

  end

  it "should successfully load an aws cloud plugin" do

    aws_options =  {
        "aws" => {
            "access_key_id" =>'foo_key_id' ,
            "secret_access_key"=>'foo_secret_key',
            "region"=> 'us',
            "default_key_name"=> 'foo'
        },
        "registry" => {
            "endpoint"=>'foo',
            "user"=>'foouser',
            "password"=>'foopass'
        }
    }
    provider = Bosh::Clouds::Provider.create("aws", aws_options)
    provider.should be_kind_of(Bosh::Clouds::Aws)

  end


  it "should fail to create an invalid provider" do

    expect {
      Bosh::Clouds::Provider.create("enoent", {})
    }.to raise_error(Bosh::Clouds::CloudError, /Could not load Cloud Provider Plugin: enoent/)

  end
end
