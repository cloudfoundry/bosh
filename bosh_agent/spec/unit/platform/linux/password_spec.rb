# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'bosh_agent/platform/linux/password'

describe Bosh::Agent::Platform::Linux::Password do
  let(:password) { subject }
  let(:encrypted_password) { '$6$salt$password' }

  it 'should update passwords' do

    Bosh::Exec.should_receive(:sh).with("usermod -p '#{encrypted_password}' root 2>%")
    Bosh::Exec.should_receive(:sh).with("usermod -p '#{encrypted_password}' vcap 2>%")

    password.update({ 'env' => { 'bosh' => { 'password' => encrypted_password } } })
  end

end
