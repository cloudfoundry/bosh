require 'spec_helper'
require '20130412192351_create_s3'

describe CreateS3 do
  include MigrationSpecHelper

  subject { described_class.new(config, '') }

  it "should create all configured buckets" do
    s3.should_receive(:create_bucket).with("b1").ordered
    s3.should_receive(:create_bucket).with("b2").ordered

    subject.execute
  end
end