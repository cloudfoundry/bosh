require "spec_helper"

describe Bosh::Spec::IntegrationTest::CliUsage do

  def rx(string)
    Regexp.compile(Regexp.escape(string))
  end

  def format_output(out)
    out.gsub(/^\s*/, '').gsub(/\s*$/, '')
  end

  def expect_output(cmd, expected_output)
    format_output(run_bosh(cmd)).should == format_output(expected_output)
  end

  it "shows status" do
    expect_output("status", <<-OUT)
      Target:     not set
      User:       not set
      Deployment: not set
    OUT
  end

  it "whines on inaccessible target" do
    out = run_bosh("target http://nowhere.com")
    out.should =~ /Error 103: cannot access director/

    expect_output("target", <<-OUT)
      Target not set
    OUT
  end

  it "sets correct target" do
    expect_output("target http://localhost:57523", <<-OUT)
      Target set to 'Test Director (http://localhost:57523)'
    OUT

    expect_output("target", <<-OUT)
      Current target is 'Test Director (http://localhost:57523)'
    OUT

    Dir.chdir("/tmp") do
      expect_output("target", <<-OUT)
        Current target is 'Test Director (http://localhost:57523)'
      OUT
    end
  end

  it "allows omitting http" do
    expect_output("target localhost:57523", <<-OUT)
      Target set to 'Test Director (http://localhost:57523)'
    OUT
  end

  it "sets and reads existing deployment (also updating target in process, even if it cannot be accessed!)" do
    deployment_manifest_path = spec_asset("bosh_work_dir/deployments/vmforce.yml")

    expect_output("deployment vmforce", <<-OUT)
      WARNING! Your target has been changed to 'http://vmforce-target:2560'
      Deployment set to '#{deployment_manifest_path}'
    OUT

    expect_output("deployment", <<-OUT)
      Current deployment is '#{deployment_manifest_path}'
    OUT

    expect_output("target", <<-OUT)
      Current target is 'http://vmforce-target:2560'
    OUT
  end

  it "unsets deployment when target is changed" do
    run_bosh("deployment 'vmforce'")
    expect_output("target http://localhost:57523", <<-OUT)
      WARNING! Your deployment has been unset
      Target set to 'Test Director (http://localhost:57523)'
    OUT
    expect_output("target", "Current target is 'Test Director (http://localhost:57523)'")
    expect_output("deployment", "Deployment not set")
  end

  it "keeps track of user associated with target" do
    run_bosh("--force target foo")
    run_bosh("--force login john pass")

    run_bosh("--force target bar")
    run_bosh("--force login jane pass")

    expect_output("status", <<-OUT)
      Target:     Unknown Director (http://bar)
      User:       jane
      Deployment: not set
    OUT

    run_bosh("--skip-director-checks target foo")
    expect_output("status", <<-OUT)
      Target:     Unknown Director (http://foo)
      User:       john
      Deployment: not set
    OUT
  end

  it "verifies a sample valid stemcell" do
    stemcell_filename = spec_asset("valid_stemcell.tgz")
    expect_output("verify stemcell #{stemcell_filename}", <<-OUT)
      Verifying stemcell...
      File exists and readable                                     OK
      Manifest not found in cache, verifying tarball...
      Extract tarball                                              OK
      Manifest exists                                              OK
      Stemcell image file                                          OK
      Writing manifest to cache...
      Stemcell properties                                          OK

      Stemcell info
      -------------
      Name:    ubuntu-stemcell
      Version: 1

     '#{stemcell_filename}' is a valid stemcell
    OUT
  end

  it "points to an error when verifying an invalid stemcell" do
    stemcell_filename = spec_asset("stemcell_invalid_mf.tgz")
    expect_output("verify stemcell #{stemcell_filename}", <<-OUT)
      Verifying stemcell...
      File exists and readable                                     OK
      Manifest not found in cache, verifying tarball...
      Extract tarball                                              OK
      Manifest exists                                              OK
      Stemcell image file                                          OK
      Writing manifest to cache...
      Stemcell properties                                          FAILED

      Stemcell info
      -------------
      Name:    ubuntu-stemcell
      Version: missing

      '#{stemcell_filename}' is not a valid stemcell:
      - Manifest should contain valid name, version and cloud properties
    OUT
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
    run_bosh("purge").should =~ Regexp.new(Regexp.escape("Cache directory '#{BOSH_CACHE_DIR}' differs from default, please remove manually"))
  end

  it "verifies a sample valid release" do
    release_filename = spec_asset("valid_release.tgz")
    out = run_bosh("verify release #{release_filename}")
    out.should =~ Regexp.new(Regexp.escape("'#{release_filename}' is a valid release"))
  end

  it "points to an error on invalid release" do
    release_filename = spec_asset("release_invalid_checksum.tgz")
    out = run_bosh("verify release #{release_filename}")
    out.should =~ Regexp.new(Regexp.escape("'#{release_filename}' is not a valid release"))
  end

  it "asks to login if no user set and operation requires talking to director" do
    expect_output("create user john pass", <<-OUT)
      Please choose target first
    OUT

    run_bosh("target http://localhost:57523")
    expect_output("create user john pass", <<-OUT)
      Please log in first
    OUT
  end

  it "creates a user when correct target accessed" do
    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")

    expect_output("create user john pass", <<-OUT)
      User john has been created
    OUT
  end

  it "can log in as a freshly created user and issue commands" do
    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    run_bosh("create user jane pass")
    run_bosh("login jane pass")

    expect_output("create user tester testpass", <<-OUT)
      User tester has been created
    OUT
  end

  it "cannot log in if password is invalid" do
    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    run_bosh("create user jane pass")
    run_bosh("logout")
    expect_output("login jane foo", <<-OUT)
      Cannot log in as 'jane', please try again
    OUT
  end

  it "can upload a stemcell" do
    stemcell_filename = spec_asset("valid_stemcell.tgz")
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n") # That's the contents of image file

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    out = run_bosh("upload stemcell #{stemcell_filename}")

    out.should =~ /Stemcell uploaded and created/
    File.exists?(CLOUD_DIR + "/stemcell_#{expected_id}").should be_true

    expect_output("stemcells", <<-OUT )
    +-----------------+---------+------------------------------------------+
    | Name            | Version | CID                                      |
    +-----------------+---------+------------------------------------------+
    | ubuntu-stemcell | 1       | #{expected_id} |
    +-----------------+---------+------------------------------------------+

    Stemcells total: 1
    OUT
  end

  it "can delete a stemcell" do
    stemcell_filename = spec_asset("valid_stemcell.tgz")
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n") # That's the contents of image file

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    out = run_bosh("upload stemcell #{stemcell_filename}")
    out.should =~ /Stemcell uploaded and created/

    File.exists?(CLOUD_DIR + "/stemcell_#{expected_id}").should be_true
    out = run_bosh("delete stemcell ubuntu-stemcell 1")
    out.should =~ /Deleted stemcell ubuntu-stemcell \(1\)/
    File.exists?(CLOUD_DIR + "/stemcell_#{expected_id}").should be_false
  end

  it "can upload a release" do
    release_filename = spec_asset("valid_release.tgz")

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    out = run_bosh("upload release #{release_filename}")

    out.should =~ /Release uploaded and updated/

    expect_output("releases", <<-OUT )
    +----------+----------+
    | Name     | Versions |
    +----------+----------+
    | appcloud | 0.1      |
    +----------+----------+

    Releases total: 1
    OUT
  end

  it "sparsely uploads the release" do
    assets_dir = File.dirname(spec_asset("foo"))
    release_1 = spec_asset("test_release/dev_releases/test_release-1.tgz")
    release_2 = spec_asset("test_release/dev_releases/test_release-2.tgz")

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
    out.should =~ rx("foo (0.1-dev)                 SKIP\n")
    out.should =~ rx("foobar (0.1-dev)              SKIP\n")
    out.should =~ rx("bar (0.2-dev)                 UPLOAD\n")
    out.should =~ rx("Checking if can repack release for faster upload")
    out.should =~ rx("Release repacked")
    out.should =~ /Release uploaded and updated/

    expect_output("releases", <<-OUT )
    +--------------+----------+
    | Name         | Versions |
    +--------------+----------+
    | test_release | 1, 2     |
    +--------------+----------+

    Releases total: 1
    OUT
  end

  it "supports sparse uploading release via manifest" do
    assets_dir = File.dirname(spec_asset("foo"))
    release_1 = spec_asset("test_release/dev_releases/test_release-1.yml")
    release_2 = spec_asset("test_release/dev_releases/test_release-2.yml")

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
      out.should =~ rx("Building tarball")
      out.should_not =~ rx("Checking if can repack release for faster upload")
      out.should_not =~ rx("Release repacked")
      out.should =~ /Release uploaded and updated/
    end

    expect_output("releases", <<-OUT )
    +--------------+----------+
    | Name         | Versions |
    +--------------+----------+
    | test_release | 1, 2     |
    +--------------+----------+

    Releases total: 1
    OUT
  end

  it "can't upload malformed release" do
    release_filename = spec_asset("release_invalid_checksum.tgz")

    run_bosh("target http://localhost:57523")
    run_bosh("login admin admin")
    out = run_bosh("upload release #{release_filename}")

    out.should =~ /Release is invalid, please fix, verify and upload again/
  end

  describe "deployment prequisites" do
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
      release_filename = spec_asset("valid_release.tgz") # It's a dummy release (appcloud 0.1)
      deployment_manifest = yaml_file("minimal", Bosh::Spec::Deployments.minimal_manifest)

      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("login admin admin")
      run_bosh("upload release #{release_filename}")

      out = run_bosh("deploy")
      out.should =~ rx("Deployed to Test Director using '#{deployment_manifest.path}' deployment manifest")
    end

    it "generates release and deploys it via simple manifest" do
      assets_dir = File.dirname(spec_asset("foo"))
      release_filename = spec_asset("test_release/dev_releases/test_release-1.tgz") # It's a test release created with bosh (see spec/assets/test_release)
      stemcell_filename = spec_asset("valid_stemcell.tgz") # It's a dummy stemcell (ubuntu-stemcell 1)

      Dir.chdir(File.join(assets_dir, "test_release")) do
        FileUtils.rm_rf("dev_releases")
        run_bosh("create release --with-tarball", Dir.pwd)
      end

      deployment_manifest = yaml_file("simple", Bosh::Spec::Deployments.simple_manifest)

      File.exists?(release_filename).should be_true
      File.exists?(deployment_manifest.path).should be_true

      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("login admin admin")
      run_bosh("upload stemcell #{stemcell_filename}")
      run_bosh("upload release #{release_filename}")

      run_bosh("deploy").should =~ rx("Deployed to Test Director using '#{deployment_manifest.path}' deployment manifest")
      # TODO: figure out which artefacts should be created by the given manifest
    end

    it "can delete deployment" do
      release_filename = spec_asset("valid_release.tgz")
      deployment_manifest = yaml_file("minimal", Bosh::Spec::Deployments.minimal_manifest)

      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh("login admin admin")
      run_bosh("upload release #{release_filename}")

      run_bosh("deploy")
      run_bosh("delete deployment minimal").should =~ rx("Deleted deployment 'minimal'")
      # TODO: test that we don't have artefacts, possibly upgrade to more featured deployment, possibly merge to the previous spec
    end
  end

end
