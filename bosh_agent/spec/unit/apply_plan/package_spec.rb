# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Agent::ApplyPlan::Package do

  before :each do
    @base_dir = Dir.mktmpdir
    Bosh::Agent::Config.base_dir = @base_dir
  end

  subject { Bosh::Agent::ApplyPlan::Package.new(valid_spec) }

  def make_job(*args)
    Bosh::Agent::ApplyPlan::Job.new(*args)
  end

  let(:valid_spec) do
    {
      'name' => 'postgres',
      'version' => '2',
      'sha1' => 'deadbeef',
      'blobstore_id' => 'deadcafe'
    }
  end

  let(:template_spec) do
    {
      'name' => 'postgres',
      'version' => '2',
      'sha1' => 'badcafe',
      'blobstore_id' => 'beefdad'
    }
  end

  let(:job_spec) do
    {
      'name' => 'ccdb',
      'templates' => [ template_spec ]
    }
  end

  let(:job_spec2) do
    {
      'name' => 'dashboard',
      'templates' => [ template_spec ]
    }
  end

  describe 'initialization' do
    it 'calls #validate_spec' do
      described_class.any_instance.should_receive(:validate_spec)
      subject
    end

    it 'picks install path and link path' do
      install_path = File.join(@base_dir, 'data', 'packages', 'postgres', '2')
      link_path = File.join(@base_dir, 'packages', 'postgres')

      subject.install_path.should == install_path
      subject.link_path.should == link_path

      File.exists?(install_path).should be_false
      File.exists?(link_path).should be_false
    end
  end

  describe 'installation' do
    it 'fetches package and creates symlink in packages and jobs' do
      job = make_job(job_spec, template_spec['name'], template_spec)

      # TODO: make sure unpack_blob is tested elsewhere
      Bosh::Agent::Util.should_receive(:unpack_blob).
        with('deadcafe', 'deadbeef', subject.install_path).
        and_return { FileUtils.mkdir_p(subject.install_path) }

      subject.install_for_job(job)

      File.exists?(subject.install_path).should be_true
      File.exists?(subject.link_path).should be_true

      File.realpath(subject.link_path).
        should == File.realpath(subject.install_path)

      job_link_path = File.join(job.install_path, 'packages', 'postgres')

      File.realpath(job_link_path).
        should == File.realpath(subject.install_path)
    end

    it 'does not fetch a package more than once' do
      job = make_job(job_spec, template_spec['name'], template_spec)
      job2 = make_job(job_spec2, template_spec['name'], template_spec)

      subject.should_receive(:fetch_bits).once.
        and_return { FileUtils.mkdir_p(subject.install_path) }

      subject.install_for_job(job)
      subject.install_for_job(job2)

      job_link_path = File.join(job.install_path, 'packages', 'postgres')
      job_link_path2 = File.join(job2.install_path, 'packages', 'postgres')

      File.realpath(job_link_path).
        should == File.realpath(subject.install_path)
      File.realpath(job_link_path2).
        should == File.realpath(subject.install_path)
    end
  end

end
