require 'spec_helper'

describe Bosh::Clouds::Config do
  it 'should configure a logger' do
    Bosh::Clouds::Config.logger.should be_kind_of(Logger)
  end

  it 'should configure a uuid' do
    Bosh::Clouds::Config.uuid.should be_kind_of(String)
  end

  it 'should not have a db configured' do
    Bosh::Clouds::Config.db.should be_nil
  end

  it 'should configure a task_checkpoint' do
    Bosh::Clouds::Config.respond_to?(:task_checkpoint).should be(true)
  end
end
