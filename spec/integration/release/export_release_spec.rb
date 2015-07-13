require 'spec_helper'

describe 'export release', type: :integration do
  with_reset_sandbox_before_each

  before{
    target_and_login
    upload_cloud_config

    bosh_runner.run("upload release #{spec_asset('valid_release.tgz')}")
    bosh_runner.run("upload release #{spec_asset('valid_release_2.tgz')}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell_2.tgz')}")
    set_deployment({manifest_hash: Bosh::Spec::Deployments.multiple_release_manifest})
    deploy({})
  }

  it 'compiles all packages of the release against the requested stemcell' do
    out = bosh_runner.run("export release appcloud/0.1 toronto-os/1")
    expect(out).to match /Started compiling packages/
    expect(out).to match /Started compiling packages > mutator\/2.99.7. Done/
    expect(out).to match /Started compiling packages > stuff\/0.1.17. Done/
    expect(out).to match /Task ([0-9]+) done/

    verified_packages = []

    current_sandbox.with_db_connection do |db|
      stemcell = Bosh::Director::Models::Stemcell[:operating_system => 'toronto-os', :version => '1']
      appcloud_release = Bosh::Director::Models::Release[:name => 'appcloud']
      appcloud_0_1 = Bosh::Director::Models::ReleaseVersion[:release => appcloud_release, :version => '0.1']
      appcloud_0_1.packages.each do |package|
        compiled_pacakge = Bosh::Director::Models::CompiledPackage.find({ stemcell: stemcell, package: package })
        expect(compiled_pacakge).to_not be_nil
        expect(compiled_pacakge.blobstore_id).to_not be_nil
        verified_packages << package.name
      end
    end

    expect(verified_packages).to include("mutator", "stuff")
  end

  it 'does not compile packages that were already compiled' do
    current_sandbox.with_db_connection do |db|
      stemcell = Bosh::Director::Models::Stemcell[:operating_system => 'toronto-os', :version => '1']
      appcloud_release = Bosh::Director::Models::Release[:name => 'appcloud']
      appcloud_0_1 = Bosh::Director::Models::ReleaseVersion[:release => appcloud_release, :version => '0.1']
      appcloud_0_1.packages.each do |package|
        package.add_compiled_package(
            :blobstore_id => 1000,
            :sha1 => 'sakjdfj',
            :dependency_key => '[]',
            :build => 1,
            :stemcell => stemcell,
            :dependency_key_sha1 => 1
        )
      end

      out = bosh_runner.run("export release appcloud/0.1 toronto-os/1")
      expect(out).to_not match /Started compiling packages/
      expect(out).to_not match /Started compiling packages > mutator\/2.99.7. Done/
      expect(out).to_not match /Started compiling packages > stuff\/0.1.17. Done/
      expect(out).to match /Task ([0-9]+) done/
    end
  end

  it 'make sure that the existing jobs in the deployment are not modified and the fake compilation job is not persisted in the datatbase' do
    current_sandbox.with_db_connection do |db|
      appcloud_release = Bosh::Director::Models::Release[:name => 'appcloud']

      templates_before = appcloud_release.templates
      packages_before = appcloud_release.packages

      bosh_runner.run("export release appcloud/0.1 toronto-os/1")

      templates_after = appcloud_release.templates
      packages_after = appcloud_release.packages

      expect(templates_after).to eq(templates_before)
      expect(packages_after).to eq(packages_before)
    end
  end

  it 'compiles any release that is in the targeted deployment' do
    current_sandbox.with_db_connection do |db|
      bosh_runner.run("export release appcloud_2/0.2 toronto-os/1")

      appcloud_release = Bosh::Director::Models::Release[:name => 'appcloud_2']
      appcloud_release.packages.each do |package|
        compiled_package = Bosh::Director::Models::CompiledPackage[:package_id => package.id]
        expect(compiled_package).to_not be_nil
      end
    end
  end

  it 'compiles against a stemcell that is not in the resource pool of the targeted deployment' do
    current_sandbox.with_db_connection do |db|
      bosh_runner.run("export release appcloud/0.1 toronto-centos/2")

      stemcell = Bosh::Director::Models::Stemcell[:name => 'centos-stemcell', :version => '2']

      appcloud_release = Bosh::Director::Models::Release[:name => 'appcloud']
      appcloud_release.packages.each do |package|
        compiled_package = Bosh::Director::Models::CompiledPackage[:package_id => package.id]
        expect(compiled_package).to_not be_nil
        expect(compiled_package.stemcell_id).to eq(stemcell.id)
      end
    end
  end

  it 'returns an error when the release does not exist' do
    expect {
      bosh_runner.run("export release app/1 toronto-os/1")
    }.to raise_error(RuntimeError, /Error 30005: Release `app' doesn't exist/)
  end

  it 'returns an error when the release version does not exist' do
    expect {
      bosh_runner.run("export release appcloud/1 toronto-os/1")
    }.to raise_error(RuntimeError, /Error 30006: Release version `appcloud\/1' doesn't exist/)
  end

  it 'returns an error when the stemcell os and version does not exist' do
    expect {
      bosh_runner.run("export release appcloud/0.1 nonexistos/1")
    }.to raise_error(RuntimeError, /Error 50003: Stemcell version `1' for OS `nonexistos' doesn't exist/)
  end

end
