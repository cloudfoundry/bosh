require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.platform_name = "ubuntu"
Bosh::Agent::Config.platform

describe Bosh::Agent::Platform::Ubuntu::Password do

  it 'should update passwords' do
    settings = { 'env' => { 'bosh' => { 'password' => '$6$salt$password' } } }

    password_wrapper = Bosh::Agent::Platform::Ubuntu::Password.new
    password_wrapper.stub!(:update_password)
    password_wrapper.should_receive(:update_password).with('root', '$6$salt$password')
    password_wrapper.should_receive(:update_password).with('vcap', '$6$salt$password')
    password_wrapper.update(settings)
  end

end
