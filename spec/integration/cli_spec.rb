require "spec_helper"

describe Bosh::Spec::IntegrationTest::CliUsage do

  def regexp(string)
    Regexp.compile(Regexp.escape(string))
  end

  def format_output(out)
    out.gsub(/^\s*/, '').gsub(/\s*$/, '')
  end

  def expect_output(cmd, expected_output)
    format_output(run_bosh(cmd)).should == format_output(expected_output)
  end

  it "has help message" do
    run_bosh("help")
    $?.should == 0
  end

  it "shows status" do
    expect_output("status", <<-OUT)
     Director
       not set

     Deployment
       not set
    OUT
  end

  it "whines on inaccessible target" do
    out = run_bosh("target http://nowhere.com")
    out.should =~ /cannot access director/i

    expect_output("target", <<-OUT)
      Target not set
    OUT
  end

  it "sets correct target" do
    expect_output("target http://localhost:57523", <<-OUT)
      Target set to `Test Director'
    OUT

    message = "http://localhost:57523"
    expect_output("target", message)
    Dir.chdir("/tmp") do
      expect_output("target", message)
    end
  end

  it "allows omitting http" do
    expect_output("target localhost:57523", <<-OUT)
      Target set to `Test Director'
    OUT
  end

  it "doesn't let user use deployment with target anymore (needs uuid)" do
    out = run_bosh("deployment vmforce")
    out.should =~ regexp("Please upgrade your deployment manifest")
  end

  it "remembers deployment when switching targets" do
    run_bosh("target localhost:57523")
    run_bosh("deployment test2")

    expect_output("target http://localhost:57523", <<-OUT)
      Target already set to `Test Director'
    OUT

    expect_output("target http://127.0.0.1:57523", <<-OUT)
      Target set to `Test Director'
    OUT

    expect_output("deployment", "Deployment not set")
    run_bosh("target localhost:57523")
    out = run_bosh("deployment")
    out.should =~ regexp("test2")
  end

  it "keeps track of user associated with target" do
    run_bosh("target http://localhost:57523 foo")
    run_bosh("login admin admin")

    run_bosh("target http://127.0.0.1:57523 bar")

    run_bosh("login admin admin")
    run_bosh("status").should =~ /user\s+admin/i

    run_bosh("target foo")
    run_bosh("status").should =~ /user\s+admin/i
  end

  it "verifies a sample valid stemcell" do
    stemcell_filename = spec_asset("valid_stemcell.tgz")
    success = regexp("#{stemcell_filename}' is a valid stemcell")
    run_bosh("verify stemcell #{stemcell_filename}").should =~ success
  end

  it "points to an error when verifying an invalid stemcell" do
    stemcell_filename = spec_asset("stemcell_invalid_mf.tgz")
    failure = regexp("`#{stemcell_filename}' is not a valid stemcell")
    run_bosh("verify stemcell #{stemcell_filename}").should =~ failure
  end

  it "uses cache when verifying stemcell for the second time" do
    stemcell_filename = spec_asset("valid_stemcell.tgz")
    run_1 = run_bosh("verify stemcell #{stemcell_filename}")
    run_2 = run_bosh("verify stemcell #{stemcell_filename}")

    run_1.should =~ /Manifest not found in cache, verifying tarball/
    run_1.should =~ /Writing manifest to cache/

    run_2.should =~ /Using cached manifest/
  end

  it "doesn't allow purging when using non-default directory" do
    run_bosh("purge").should =~ regexp("please remove manually")
  end

  it "verifies a sample valid release" do
    release_filename = spec_asset("valid_release.tgz")
    out = run_bosh("verify release #{release_filename}")
    out.should =~ regexp("`#{release_filename}' is a valid release")
  end

  it "points to an error on invalid release" do
    release_filename = spec_asset("release_invalid_checksum.tgz")
    out = run_bosh("verify release #{release_filename}")
    out.should =~ regexp("`#{release_filename}' is not a valid release")
  end

  it "requires login when talking to director" do
    run_bosh("properties").should =~ /please choose target first/i
    run_bosh("target http://localhost:57523")
    run_bosh("properties").should =~ /please log in first/i
  end

  it "creates a user when correct target accessed" do
    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    run_bosh("create user john pass").should =~ /user `john' has been created/i
  end

  it "can log in as a freshly created user and issue commands" do
    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    run_bosh("create user jane pass")
    run_bosh("login jane pass")

    success = /User `tester' has been created/i
    run_bosh("create user tester testpass").should =~ success
  end

  it "cannot log in if password is invalid" do
    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    run_bosh("create user jane pass")
    run_bosh("logout")
    expect_output("login jane foo", <<-OUT)
      Cannot log in as `jane'
    OUT
  end

  it "can upload a stemcell" do
    stemcell_filename = spec_asset("valid_stemcell.tgz")
    # That's the contents of image file:
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n")

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    out = run_bosh("upload stemcell #{stemcell_filename}")

    out.should =~ /Stemcell uploaded and created/
    File.exists?(CLOUD_DIR + "/stemcell_#{expected_id}").should be_true

    out = run_bosh("stemcells")
    out.should =~ /stemcells total: 1/i
    out.should =~ /ubuntu-stemcell.+1/
    out.should =~ regexp(expected_id.to_s)
  end

  it "can delete a stemcell" do
    stemcell_filename = spec_asset("valid_stemcell.tgz")
    # That's the contents of image file:
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n")

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    out = run_bosh("upload stemcell #{stemcell_filename}")
    out.should =~ /Stemcell uploaded and created/

    File.exists?(CLOUD_DIR + "/stemcell_#{expected_id}").should be_true
    out = run_bosh("delete stemcell ubuntu-stemcell 1")
    out.should =~ /Deleted stemcell `ubuntu-stemcell\/1'/
    File.exists?(CLOUD_DIR + "/stemcell_#{expected_id}").should be_false
  end

  it "can't create a final release without the blobstore secret" do
    assets_dir = File.dirname(spec_asset("foo"))

    Dir.chdir(File.join(assets_dir, "test_release")) do
      FileUtils.rm_rf("dev_releases")

      out = run_bosh("create release --final", Dir.pwd)
      out.should match(/Can't create final release without blobstore secret/)
    end
  end

  it "can upload a release" do
    release_filename = spec_asset("valid_release.tgz")

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    out = run_bosh("upload release #{release_filename}")

    out.should =~ /release uploaded/i

    out = run_bosh("releases")
    out.should =~ /releases total: 1/i
    out.should =~ /appcloud.+0\.1/
  end

  it "uploads the latest generated release if no release path given" do
    assets_dir = File.dirname(spec_asset("foo"))

    Dir.chdir(File.join(assets_dir, "test_release")) do
      FileUtils.rm_rf("dev_releases")

      run_bosh("create release", Dir.pwd)
      run_bosh("target http://localhost:57523")
      run_bosh("login admin admin")
      run_bosh("upload release", Dir.pwd)
    end

    out = run_bosh("releases")
    out.should =~ /releases total: 1/i
    out.should =~ /bosh-release.+0\.1\-dev/
  end

  it "sparsely uploads the release" do
    assets_dir = File.dirname(spec_asset("foo"))
    release_1 = spec_asset("test_release/dev_releases/bosh-release-0.1-dev.tgz")
    release_2 = spec_asset("test_release/dev_releases/bosh-release-0.2-dev.tgz")

    Dir.chdir(File.join(assets_dir, "test_release")) do
      FileUtils.rm_rf("dev_releases")
      run_bosh("create release --with-tarball", Dir.pwd)
      File.exists?(release_1).should be_true
    end

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    run_bosh("upload release #{release_1}")

    Dir.chdir(File.join(assets_dir, "test_release")) do
      new_file = File.join("src", "bar", "bla")
      begin
        FileUtils.touch(new_file)
        run_bosh("create release --with-tarball", Dir.pwd)
        File.exists?(release_2).should be_true
      ensure
        FileUtils.rm_rf(new_file)
      end
    end

    out = run_bosh("upload release #{release_2}")
    out.should =~ regexp("foo (0.1-dev)                 SKIP\n")
    # No job skipping for the moment (because of rebase),
    # will be added back once job matching is implemented
    out.should =~ regexp("foobar (0.1-dev)              UPLOAD\n")
    out.should =~ regexp("bar (0.2-dev)                 UPLOAD\n")
    out.should =~ regexp("Checking if can repack release for faster upload")
    out.should =~ regexp("Release repacked")
    out.should =~ /Release uploaded/

    out = run_bosh("releases")
    out.should =~ /releases total: 1/i
    out.should =~ /bosh-release.+0\.1\-dev, 0\.2\-dev/
  end

  it "release lifecycle: create, upload, update (w/sparse upload), delete" do
    assets_dir = File.dirname(spec_asset("foo"))
    release_1 = spec_asset("test_release/dev_releases/bosh-release-0.1-dev.yml")
    release_2 = spec_asset("test_release/dev_releases/bosh-release-0.2-dev.yml")

    release_dir = File.join(assets_dir, "test_release")

    Dir.chdir(release_dir) do
      run_bosh("reset release")
      run_bosh("create release", Dir.pwd)
      File.exists?(release_1).should be_true

      run_bosh("target http://localhost:57523")
      run_bosh("login admin admin")
      run_bosh("upload release #{release_1}", Dir.pwd)

      new_file = File.join("src", "bar", "bla")
      begin
        FileUtils.touch(new_file)
        run_bosh("create release", Dir.pwd)
        File.exists?(release_2).should be_true
      ensure
        FileUtils.rm_rf(new_file)
      end

      out = run_bosh("upload release #{release_2}", Dir.pwd)
      out.should =~ regexp("Building tarball")
      out.should_not =~ regexp("Checking if can repack")
      out.should_not =~ regexp("Release repacked")
      out.should =~ /Release uploaded/
    end

    out = run_bosh("releases")
    out.should =~ /releases total: 1/i
    out.should =~ /bosh-release.+0\.1\-dev, 0\.2\-dev/

    run_bosh("delete release bosh-release 0.2-dev")
    expect_output("releases", <<-OUT )
    +--------------+----------+
    | Name         | Versions |
    +--------------+----------+
    | bosh-release | 0.1-dev  |
    +--------------+----------+

    Releases total: 1
    OUT

    run_bosh("delete release bosh-release 0.1-dev")
    expect_output("releases", <<-OUT )
    No releases
    OUT
  end

  it "can't upload malformed release" do
    release_filename = spec_asset("release_invalid_checksum.tgz")

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    out = run_bosh("upload release #{release_filename}")

    out.should =~ /Release is invalid, please fix, verify and upload again/
  end

  it "allows deleting a whole release" do
    release_filename = spec_asset("valid_release.tgz")

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    run_bosh("upload release #{release_filename}")

    out = run_bosh("delete release appcloud")
    out.should =~ regexp("Deleted `appcloud")

    expect_output("releases", <<-OUT)
    No releases
    OUT
  end

  it "allows deleting a particular release version" do
    release_filename = spec_asset("valid_release.tgz")

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    run_bosh("upload release #{release_filename}")

    out = run_bosh("delete release appcloud 0.1")
    out.should =~ regexp("Deleted `appcloud/0.1")
  end

  describe "deployment prerequisites" do
    it "requires target and login" do
      run_bosh("deploy").should =~ /Please choose target first/
      run_bosh("target http://localhost:57523")
      run_bosh("deploy").should =~ /Please log in first/
    end

    it "requires deployment to be chosen" do
      run_bosh("target http://localhost:57523")
      run_bosh("login admin admin")
      run_bosh("deploy").should =~ /Please choose deployment first/
    end
  end

  describe "deployment process" do
    it "successfully performed with minimal manifest" do
      release_filename = spec_asset("valid_release.tgz")
      deployment_manifest = yaml_file(
        "minimal", Bosh::Spec::Deployments.minimal_manifest)

      run_bosh("target localhost:57523")
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("login admin admin")
      run_bosh("upload release #{release_filename}")

      out = run_bosh("deploy")
      filename = File.basename(deployment_manifest.path)
      out.should =~ regexp("Deployed `#{filename}' to `Test Director'")
    end

    it "generates release and deploys it via simple manifest" do
      assets_dir = File.dirname(spec_asset("foo"))
      # Test release created with bosh (see spec/assets/test_release_template)
      release_file = "test_release/dev_releases/bosh-release-0.1-dev.tgz"
      release_filename = spec_asset(release_file)
      # Dummy stemcell (ubuntu-stemcell 1)
      stemcell_filename = spec_asset("valid_stemcell.tgz")

      Dir.chdir(File.join(assets_dir, "test_release")) do
        FileUtils.rm_rf("dev_releases")
        run_bosh("create release --with-tarball", Dir.pwd)
      end

      deployment_manifest = yaml_file(
        "simple", Bosh::Spec::Deployments.simple_manifest)

      File.exists?(release_filename).should be_true
      File.exists?(deployment_manifest.path).should be_true

      run_bosh("target localhost:57523")
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("login admin admin")
      run_bosh("upload stemcell #{stemcell_filename}")
      run_bosh("upload release #{release_filename}")

      out = run_bosh("deploy")
      filename = File.basename(deployment_manifest.path)
      out.should =~ regexp("Deployed `#{filename}' to `Test Director'")

      run_bosh("cloudcheck --report").should =~ regexp("No problems found")
      $?.should == 0
      # TODO: figure out which artefacts should be created by the given manifest
    end

    it "can delete deployment" do
      release_filename = spec_asset("valid_release.tgz")
      deployment_manifest = yaml_file(
        "minimal", Bosh::Spec::Deployments.minimal_manifest)

      run_bosh("target localhost:57523")
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("login admin admin")
      run_bosh("upload release #{release_filename}")

      run_bosh("deploy")
      failure = regexp("Deleted deployment `minimal'")
      run_bosh("delete deployment minimal").should =~ failure
      # TODO: test that we don't have artefacts,
      # possibly upgrade to more featured deployment,
      # possibly merge to the previous spec
    end
  end

  describe "property management" do

    it "can get/set/delete deployment properties" do
      release_filename = spec_asset("valid_release.tgz")
      deployment_manifest = yaml_file(
        "minimal", Bosh::Spec::Deployments.minimal_manifest)

      run_bosh("target localhost:57523")
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("login admin admin")
      run_bosh("upload release #{release_filename}")

      run_bosh("deploy")

      run_bosh("set property foo bar").should =~ regexp(
        "Property `foo' set to `bar'")
      run_bosh("get property foo").should =~ regexp(
        "Property `foo' value is `bar'")
      run_bosh("set property foo baz").should =~ regexp(
        "Property `foo' set to `baz'")
      run_bosh("unset property foo").should =~ regexp(
        "Property `foo' has been unset")

      run_bosh("set property nats.user admin")
      run_bosh("set property nats.password pass")

      props = run_bosh("properties --terse")
      props.should =~ regexp("nats.user\tadmin")
      props.should =~ regexp("nats.password\tpass")
    end

  end

end
