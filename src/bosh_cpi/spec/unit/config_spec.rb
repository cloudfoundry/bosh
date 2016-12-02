require 'spec_helper'
require 'logging'

describe Bosh::Clouds::Config do
  it 'should configure a logger' do
    expect(Bosh::Clouds::Config.logger).to be_kind_of(Logging::Logger)
  end

  it 'should configure a uuid' do
    expect(Bosh::Clouds::Config.uuid).to be_kind_of(String)
  end

  it 'should not have a db configured' do
    expect(Bosh::Clouds::Config.db).to be_nil
  end

  it 'should configure a task_checkpoint' do
    expect(Bosh::Clouds::Config.respond_to?(:task_checkpoint)).to be(true)
  end
end
