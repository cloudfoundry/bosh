# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Bosh::Agent::Platform::Ubuntu::Password do

  it 'should update passwords' do
    settings = { 'env' => { 'bosh' => { 'password' => '$6$salt$password' } } }

    Bosh::Common.should_receive(:sh).with("usermod -p '$6$salt$password' root 2>%")
    Bosh::Common.should_receive(:sh).with("usermod -p '$6$salt$password' vcap 2>%")

    Bosh::Agent::Platform::Ubuntu::Password.new.update(settings)
  end

end
