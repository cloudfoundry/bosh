# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Jobs::DeleteRelease do

  before(:each) do
    @blobstore = mock("blobstore")
    BD::Config.stub!(:blobstore).and_return(@blobstore)
  end

  describe "perform" do

    it "should fail for unknown releases" do
      job = BD::Jobs::DeleteRelease.new("test_release")
      job.should_receive(:with_release_lock).
          with("test_release", :timeout => 10).and_yield
      expect { job.perform }.to raise_exception(BD::ReleaseNotFound)
    end

    it "should fail if the deployments still reference this release" do
      release = BDM::Release.make(:name => "test")
      version = BDM::ReleaseVersion.make(:release => release,
                                         :version => "42-dev")
      deployment = BDM::Deployment.make(:name => "test")

      deployment.add_release_version(version)

      job = BD::Jobs::DeleteRelease.new("test")
      job.should_receive(:with_release_lock).
          with("test", :timeout => 10).and_yield
      expect { job.perform }.to raise_exception(BD::ReleaseInUse)
    end

    it "should delete the release and associated jobs, packages, " +
           "compiled packages and their metadata" do
      release = BDM::Release.make(:name => "test_release")

      job = BD::Jobs::DeleteRelease.new("test_release")
      job.should_receive(:with_release_lock).
          with("test_release", :timeout => 10).and_yield
      job.should_receive(:delete_release).with(release)
      job.perform
    end

    it "should fail if the delete was not successful" do
      release = BDM::Release.make(:name => "test_release")

      job = BD::Jobs::DeleteRelease.new("test_release")
      job.should_receive(:delete_release).with(release)
      job.should_receive(:with_release_lock).
          with("test_release", :timeout => 10).and_yield
      job.instance_eval { @errors << "bad" }
      lambda { job.perform }.should raise_exception
    end

    it "should support deleting a particular release version" do
      release = BDM::Release.make(:name => "test_release")
      rv1 = BDM::ReleaseVersion.make(:release => release, :version => "1")
      BDM::ReleaseVersion.make(:release => release, :version => "2")

      job = BD::Jobs::DeleteRelease.new("test_release",
                                        "version" => rv1.version)
      job.should_receive(:delete_release_version).with(rv1)
      job.should_receive(:with_release_lock).
          with("test_release", :timeout => 10).and_yield
      job.perform
    end

    it "should fail deleting version if there is a deployment which " +
           "uses that version" do
      release = BDM::Release.make(:name => "test_release")
      rv1 = BDM::ReleaseVersion.make(:release => release, :version => "1")
      rv2 = BDM::ReleaseVersion.make(:release => release, :version => "2")

      manifest = YAML.dump(
          "release" => {"name" => "test_release", "version" => "2"})

      deployment = BDM::Deployment.make(:name => "test_deployment",
                                        :manifest => manifest)
      deployment.add_release_version(rv2)

      job1 = BD::Jobs::DeleteRelease.new("test_release", "version" => "2")
      job1.should_receive(:with_release_lock).
          with("test_release", :timeout => 10).and_yield

      expect { job1.perform }.to raise_exception(BD::ReleaseVersionInUse)

      job2 = BD::Jobs::DeleteRelease.new("test_release", "version" => "1")
      job2.should_receive(:with_release_lock).
          with("test_release", :timeout => 10).and_yield
      job2.should_receive(:delete_release_version).with(rv1)
      job2.perform
    end

  end

  describe "delete_release" do

    before(:each) do
      @release = BDM::Release.make(:name => "test_release")
      @release_version = BDM::ReleaseVersion.make(:release => @release)
      @package = BDM::Package.make(:release => @release,
                                   :blobstore_id => "package-blb")
      @template = BDM::Template.make(:release => @release,
                                     :blobstore_id => "template-blb")
      @stemcell = BDM::Stemcell.make
      @compiled_package = BDM::CompiledPackage.make(
          :package => @package, :stemcell => @stemcell,
          :blobstore_id => "compiled-package-blb")
      @release_version.add_package(@package)
      @release_version.add_template(@template)
    end

    it "should delete release and associated objects/meta" do
      @blobstore.should_receive(:delete).with("template-blb")
      @blobstore.should_receive(:delete).with("package-blb")
      @blobstore.should_receive(:delete).with("compiled-package-blb")

      job = BD::Jobs::DeleteRelease.new("test_release")
      job.delete_release(@release)

      job.instance_eval {@errors}.should be_empty

      BDM::Release[@release.id].should be_nil
      BDM::ReleaseVersion[@release_version.id].should be_nil
      BDM::Package[@package.id].should be_nil
      BDM::Template[@template.id].should be_nil
      BDM::CompiledPackage[@compiled_package.id].should be_nil
    end

    it "should fail to delete the release if there is a blobstore error" do
      @blobstore.should_receive(:delete).with("template-blb").and_raise("bad")
      @blobstore.should_receive(:delete).with("package-blb")
      @blobstore.should_receive(:delete).with("compiled-package-blb")

      job = BD::Jobs::DeleteRelease.new("test_release")
      job.delete_release(@release)

      errors = job.instance_eval {@errors}
      errors.length.should eql(1)
      errors.first.to_s.should eql("bad")

      BDM::Release[@release.id].should_not be_nil
      BDM::ReleaseVersion[@release_version.id].should_not be_nil
      BDM::Package[@package.id].should be_nil
      BDM::Template[@template.id].should_not be_nil
      BDM::CompiledPackage[@compiled_package.id].should be_nil
    end

    it "should forcefully delete the release when requested even if there is a blobstore error" do
      @blobstore.should_receive(:delete).with("template-blb").and_raise("bad")
      @blobstore.should_receive(:delete).with("package-blb")
      @blobstore.should_receive(:delete).with("compiled-package-blb")

      job = BD::Jobs::DeleteRelease.new("test_release", "force" => true)
      job.delete_release(@release)

      errors = job.instance_eval {@errors}
      errors.length.should eql(1)
      errors.first.to_s.should eql("bad")

      BDM::Release[@release.id].should be_nil
      BDM::ReleaseVersion[@release_version.id].should be_nil
      BDM::Package[@package.id].should be_nil
      BDM::Template[@template.id].should be_nil
      BDM::CompiledPackage[@compiled_package.id].should be_nil
    end

  end

  describe "delete release version" do
    before(:each) do
      @release = BDM::Release.make(:name => "test_release")

      @rv1 = BDM::ReleaseVersion.make(:release => @release)
      @rv2 = BDM::ReleaseVersion.make(:release => @release)

      @pkg1 = BDM::Package.make(:release => @release, :blobstore_id => "pkg1")
      @pkg2 = BDM::Package.make(:release => @release, :blobstore_id => "pkg2")
      @pkg3 = BDM::Package.make(:release => @release, :blobstore_id => "pkg3")

      @tmpl1 = BDM::Template.make(:release => @release, :blobstore_id => "template1")
      @tmpl2 = BDM::Template.make(:release => @release, :blobstore_id => "template2")
      @tmpl3 = BDM::Template.make(:release => @release, :blobstore_id => "template3")

      @stemcell = BDM::Stemcell.make

      @cpkg1 = BDM::CompiledPackage.make(:package => @pkg1, :stemcell => @stemcell, :blobstore_id => "deadbeef")
      @cpkg2 = BDM::CompiledPackage.make(:package => @pkg2, :stemcell => @stemcell, :blobstore_id => "badcafe")
      @cpkg3 = BDM::CompiledPackage.make(:package => @pkg3, :stemcell => @stemcell, :blobstore_id => "feeddead")

      @rv1.add_package(@pkg1)
      @rv1.add_package(@pkg2)
      @rv1.add_package(@pkg3)

      @rv2.add_package(@pkg1)
      @rv2.add_package(@pkg2)

      @rv1.add_template(@tmpl1)
      @rv1.add_template(@tmpl2)
      @rv1.add_template(@tmpl3)

      @rv2.add_template(@tmpl1)
      @rv2.add_template(@tmpl2)
    end

    it "should delete release version without touching any shared packages/templates" do
      job = BD::Jobs::DeleteRelease.new("test_release", "version" => @rv1.version)

      @blobstore.should_receive(:delete).with("pkg3")
      @blobstore.should_receive(:delete).with("template3")
      @blobstore.should_receive(:delete).with("feeddead")

      job.delete_release_version(@rv1)

      BDM::ReleaseVersion[@rv1.id].should be_nil
      BDM::ReleaseVersion[@rv2.id].should_not be_nil

      BDM::Package[@pkg1.id].should == @pkg1
      BDM::Package[@pkg2.id].should == @pkg2
      BDM::Package[@pkg3.id].should be_nil

      BDM::Template[@tmpl1.id].should == @tmpl1
      BDM::Template[@tmpl2.id].should == @tmpl2
      BDM::Template[@tmpl3.id].should be_nil

      BDM::CompiledPackage[@cpkg1.id].should == @cpkg1
      BDM::CompiledPackage[@cpkg2.id].should == @cpkg2
      BDM::CompiledPackage[@cpkg3.id].should be_nil
    end

    it "should not leave any release/package/templates artifacts after all " +
           "release versions have been deleted" do
      job1 = BD::Jobs::DeleteRelease.new("test_release", "version" => @rv1.version)
      job2 = BD::Jobs::DeleteRelease.new("test_release", "version" => @rv2.version)

      @blobstore.stub!(:delete)

      job1.should_receive(:with_release_lock).
          with("test_release", :timeout => 10).and_yield
      job1.perform

      BDM::Release.count.should == 1

      # This assertion is very important as SQLite doesn't check integrity
      # but Postgres does and it can fail on postgres if there are any hanging
      # references to release version in packages_release_versions
      BDM::Package.db[:packages_release_versions].count.should == 2

      job2.should_receive(:with_release_lock).
          with("test_release", :timeout => 10).and_yield
      job2.perform

      BDM::ReleaseVersion.count.should == 0
      BDM::Package.count.should == 0
      BDM::Template.count.should  == 0
      BDM::CompiledPackage.count.should == 0
      BDM::Release.count.should == 0
    end

  end

end
