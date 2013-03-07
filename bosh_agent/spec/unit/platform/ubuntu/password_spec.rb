# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'bosh_agent/platform/ubuntu/password'

describe Bosh::Agent::Platform::Ubuntu::Password do

  it 'should update passwords' do
    passwd = Bosh::Agent::Platform::Ubuntu::Password.new
    settings = { 'env' => { 'bosh' => { 'password' => '$6$salt$password' } } }

    passwd.stub!(:update_password)
    passwd.should_receive(:update_password).with('root', '$6$salt$password')
    passwd.should_receive(:update_password).with('vcap', '$6$salt$password')

    passwd.update(settings)
  end

end
