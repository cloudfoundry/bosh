require 'spec_helper'

describe Bosh::Director::DeploymentPlan::ReleaseVersion do
  def make(deployment, spec)
    Bosh::Director::DeploymentPlan::ReleaseVersion.parse(deployment, spec)
  end

  def find_release(name)
    Bosh::Director::Models::Release.find(name: name)
  end

  def make_deployment(name)
    FactoryBot.create(:models_deployment, name: name)
  end

  def make_release(name)
    FactoryBot.create(:models_release, name: name)
  end

  def make_version(name, version)
    release = make_release(name)
    FactoryBot.create(:models_release_version, release: release, version: version)
  end

  describe '#parse' do
    it 'should correctly parse the release and create a new release version object' do
      deployment = make_deployment('my-deployment')
      spec = {
        'name' => 'my-release',
        'version' => '1.2.3+dev',
        'exported_from' => [
          { 'os' => 'ubuntu-xenial', 'version' => '250.9' },
          { 'os' => 'windows-2012R2', 'version' => '2012.r10' },
        ],
      }
      release_version = Bosh::Director::DeploymentPlan::ReleaseVersion.parse(deployment, spec)

      expect(release_version.name).to eq('my-release')
      expect(release_version.version).to eq('1.2.3+dev')
      expect(release_version.exported_from.length).to eq(2)

      stemcell1 = release_version.exported_from[0]
      expect(stemcell1.os).to eq('ubuntu-xenial')
      expect(stemcell1.version).to eq('250.9')

      stemcell2 = release_version.exported_from[1]
      expect(stemcell2.os).to eq('windows-2012R2')
      expect(stemcell2.version).to eq('2012.r10')
    end
  end

  describe 'binding release version model' do
    it 'should bind release version model' do
      spec = {'name' => 'foo', 'version' => '42.1-dev'}
      deployment = make_deployment('mycloud')
      rv1 = make_version('foo', '42+dev.1')

      release = make(deployment, spec)
      release.bind_model

      expect(release.model).to eq(rv1)
      expect(deployment.release_versions).to eq([rv1])
    end

    it "should fail if release doesn't exist" do
      deployment = make_deployment('mycloud')
      spec = {'name' => 'foo', 'version' => '42.1-dev'}

      expect {
        release = make(deployment, spec)
        release.bind_model
      }.to raise_error(Bosh::Director::ReleaseNotFound)
    end

    it "should fail if release version doesn't exist" do
      deployment = make_deployment('mycloud')
      spec = {'name' => 'foo', 'version' => '42.1-dev'}
      make_version('foo', '55.1-dev')

      expect {
        release = make(deployment, spec)
        release.bind_model
      }.to raise_error(Bosh::Director::ReleaseVersionNotFound)
    end

    it 'binds release versions to the deployment in DB' do
      deployment = make_deployment('mycloud')

      rv1 = make_version('foo', '42.1-dev')
      rv2 = make_version('bar', '55.1-dev')

      spec1 = {'name' => 'foo', 'version' => '42.1-dev'}
      spec2 = {'name' => 'bar', 'version' => '55.1-dev'}

      make(deployment, spec1).bind_model
      make(deployment, spec2).bind_model

      expect(deployment.release_versions).to match_array([rv1, rv2])
    end

    it "doesn't bind model if deployment plan has unbound deployment" do
      expect {
        release = make(nil, {'name' => 'foo', 'version' => '42'})
        release.bind_model
      }.to raise_error(Bosh::Director::DirectorError,
                       'Deployment not bound in the deployment plan')
    end
  end

  describe 'looking up/adding templates' do
    it 'registers templates used in the release' do
      spec = {'name' => 'foo', 'version' => '42.1-dev'}
      deployment = make_deployment('mycloud')

      release = make(deployment, spec)
      expect(release.templates).to eq([])
      release.get_or_create_template('foobar')
      expect(release.templates.size).to eq(1)
      template = release.templates[0]
      expect(release.template('foobar')).to eq(template)
      expect(template.name).to eq('foobar')
      expect(template.release).to eq(release)
      expect(template.model).to be_nil
    end

    it 'finds template/package models by name' do
      deployment = make_deployment('mycloud')
      r1 = make_release('foo')
      r2 = make_release('bar')
      rv1 = FactoryBot.create(:models_release_version, release: r1, version: '42')
      rv2 = FactoryBot.create(:models_release_version, release: r2, version: '55')

      t1 = FactoryBot.create(:models_template, release: r1, name: 'dea')
      t2 = FactoryBot.create(:models_template, release: r2, name: 'stager')
      rv1.add_template(t1)
      rv2.add_template(t2)

      p1 = FactoryBot.create(:models_package, release: r1, name: 'ruby18')
      p2 = FactoryBot.create(:models_package, release: r2, name: 'ruby19')
      p3 = FactoryBot.create(:models_package, release: r2, name: 'ruby20')
      rv1.add_package(p1)
      rv2.add_package(p2)
      rv2.add_package(p3)

      release = make(deployment, {'name' => 'foo', 'version' => '42'})
      release.bind_model
      expect(release.get_template_model_by_name('dea')).to eq(t1)
      expect(release.get_template_model_by_name('stager')).to eq(nil)

      expect(release.get_package_model_by_name('ruby18')).to eq(p1)
      expect { release.get_package_model_by_name('ruby19') }.to raise_error(/Package name 'ruby19' not found in release 'foo\/42'/)
      expect { release.get_package_model_by_name('ruby20') }.to raise_error(/Package name 'ruby20' not found in release 'foo\/42'/)

      release = make(deployment, {'name' => 'bar', 'version' => '55'})
      release.bind_model
      expect(release.get_template_model_by_name('dea')).to eq(nil)
      expect(release.get_template_model_by_name('stager')).to eq(t2)
      expect { release.get_package_model_by_name('ruby18') }.to raise_error(/Package name 'ruby18' not found in release 'bar\/55'/)
      expect(release.get_package_model_by_name('ruby19')).to eq(p2)
      expect(release.get_package_model_by_name('ruby20')).to eq(p3)
    end
  end

  describe 'binding templates' do
    it 'delegates binding to individual template spec classes' do
      deployment = make_deployment('mycloud')

      r_bar = make_release('bar')
      bar_42 = FactoryBot.create(:models_release_version, release: r_bar, version: '42')

      t_dea = FactoryBot.create(:models_template, release: r_bar, name: 'dea')
      t_dea.package_names = %w(ruby node)
      t_dea.save

      bar_42.add_template(t_dea)

      p_ruby = FactoryBot.create(:models_package, release: r_bar, name: 'ruby')
      p_node = FactoryBot.create(:models_package, release: r_bar, name: 'node')
      bar_42.add_package(p_ruby)
      bar_42.add_package(p_node)

      release = make(deployment, {'name' => 'bar', 'version' => '42'})
      release.get_or_create_template('dea')

      release.bind_model
      release.bind_jobs

      expect(release.template('dea').model).to eq(t_dea)
      expect(release.template('dea').package_models).to match_array([p_ruby, p_node])

      # Making sure once bound template stays bound if we call
      # #use_template_named again
      release.get_or_create_template('dea')
      expect(release.template('dea').model).to eq(t_dea)
    end

    it 'delegates some methods to bound model' do
      r_bar = make_release('bar')

      t_attrs = {
        release: r_bar,
        name: 'dea',
        blobstore_id: 'deadbeef',
        version: '522',
        sha1: 'deadcafe',
        spec_json: JSON.generate({ 'logs' => %w(a b c) })
      }

      t_dea = FactoryBot.create(:models_template, t_attrs)


      bar_42 =
        FactoryBot.create(:models_release_version, release: r_bar, version: '42')
      bar_42.add_template(t_dea)

      release = make(make_deployment('mycloud'), {'name' => 'bar', 'version' => 42})
      release.get_or_create_template('dea')
      template = release.template('dea')

      %i[version blobstore_id sha1 logs].each do |method|
        expect {
          template.send(method)
        }.to raise_error(Bosh::Director::DirectorError, /Job 'dea' model is unbound/)
      end

      release.bind_model
      release.bind_jobs

      expect(template.version).to eq('522')
      expect(template.blobstore_id).to eq('deadbeef')
      expect(template.sha1).to eq('deadcafe')
      expect(template.logs).to eq(%w(a b c))
    end
  end
end
