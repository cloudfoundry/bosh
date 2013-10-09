# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Agent::Platform::Linux::Password do
  let(:password) { subject }
  let(:encrypted_password) { '$6$salt$password' }
  let(:partial_settings) {
    Yajl::Parser.new.parse %q[{
                              "vm":{"name":"vm-678aa22e-f193-4db4-b69b-cdafb361f53c"},
                              "env":{"bosh":{"password":"$6$salt$password"}}]
  }

  it 'should update passwords' do
    Bosh::Exec.should_receive(:sh).with("usermod -p '#{encrypted_password}' root 2>%")
    Bosh::Exec.should_receive(:sh).with("usermod -p '#{encrypted_password}' vcap 2>%")

    password.update(partial_settings)
  end

end
