require 'spec_helper'

describe Bosh::Director::DeploymentPlan::ReleaseVersion do
  def make(deployment, spec)
    BD::DeploymentPlan::ReleaseVersion.new(deployment, spec)
  end

  def find_release(name)
    BD::Models::Release.find(:name => name)
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  def make_release(name)
    BD::Models::Release.make(:name => name)
  end

  def make_version(name, version)
    release = make_release(name)
    BD::Models::ReleaseVersion.make(:release => release, :version => version)
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
      }.to raise_error(BD::ReleaseNotFound)
    end

    it "should fail if release version doesn't exist" do
      deployment = make_deployment('mycloud')
      spec = {'name' => 'foo', 'version' => '42.1-dev'}
      make_version('foo', '55.1-dev')

      expect {
        release = make(deployment, spec)
        release.bind_model
      }.to raise_error(BD::ReleaseVersionNotFound)
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
      }.to raise_error(BD::DirectorError,
                       'Deployment not bound in the deployment plan')
    end
  end

  describe 'looking up/adding templates' do
    it 'registers templates used in the release' do
      spec = {'name' => 'foo', 'version' => '42.1-dev'}

      release = make(nil, spec)
      expect(release.templates).to eq([])
      release.use_template_named('foobar')
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
      rv1 = BD::Models::ReleaseVersion.make(:release => r1, :version => '42')
      rv2 = BD::Models::ReleaseVersion.make(:release => r2, :version => '55')

      t1 = BD::Models::Template.make(:release => r1, :name => 'dea')
      t2 = BD::Models::Template.make(:release => r2, :name => 'stager')
      rv1.add_template(t1)
      rv2.add_template(t2)

      p1 = BD::Models::Package.make(:release => r1, :name => 'ruby18')
      p2 = BD::Models::Package.make(:release => r2, :name => 'ruby19')
      p3 = BD::Models::Package.make(:release => r2, :name => 'ruby20')
      rv1.add_package(p1)
      rv2.add_package(p2)
      rv2.add_package(p3)

      release = make(deployment, {'name' => 'foo', 'version' => '42'})
      release.bind_model
      expect(release.get_template_model_by_name('dea')).to eq(t1)
      expect(release.get_template_model_by_name('stager')).to eq(nil)

      expect(release.get_package_model_by_name('ruby18')).to eq(p1)
      expect { release.get_package_model_by_name('ruby19') }.to raise_error /key not found/
      expect { release.get_package_model_by_name('ruby20') }.to raise_error /key not found/

      release = make(deployment, {'name' => 'bar', 'version' => '55'})
      release.bind_model
      expect(release.get_template_model_by_name('dea')).to eq(nil)
      expect(release.get_template_model_by_name('stager')).to eq(t2)
      expect { release.get_package_model_by_name('ruby18') }.to raise_error /key not found/
      expect(release.get_package_model_by_name('ruby19')).to eq(p2)
      expect(release.get_package_model_by_name('ruby20')).to eq(p3)
    end
  end

  describe 'binding templates' do
    it 'delegates binding to individual template spec classes' do
      deployment = make_deployment('mycloud')

      r_bar = make_release('bar')
      bar_42 =
        BD::Models::ReleaseVersion.make(:release => r_bar, :version => '42')

      t_dea = BD::Models::Template.make(:release => r_bar, :name => 'dea')
      t_dea.package_names = %w(ruby node)
      t_dea.save

      bar_42.add_template(t_dea)

      p_ruby = BD::Models::Package.make(:release => r_bar, :name => 'ruby')
      p_node = BD::Models::Package.make(:release => r_bar, :name => 'node')
      bar_42.add_package(p_ruby)
      bar_42.add_package(p_node)

      release = make(deployment, {'name' => 'bar', 'version' => '42'})
      release.use_template_named('dea')

      release.bind_model
      release.bind_templates

      expect(release.template('dea').model).to eq(t_dea)
      expect(release.template('dea').package_models).to match_array([p_ruby, p_node])

      # Making sure once bound template stays bound if we call
      # #use_template_named again
      release.use_template_named('dea')
      expect(release.template('dea').model).to eq(t_dea)
    end

    it 'delegates some methods to bound model' do
      r_bar = make_release('bar')

      t_attrs = {
        :release => r_bar,
        :name => 'dea',
        :blobstore_id => 'deadbeef',
        :version => '522',
        :sha1 => 'deadcafe',
        :logs_json => Yajl::Encoder.encode(%w(a b c))
      }

      t_dea = BD::Models::Template.make(t_attrs)


      bar_42 =
        BD::Models::ReleaseVersion.make(:release => r_bar, :version => '42')
      bar_42.add_template(t_dea)

      release = make(make_deployment('mycloud'), {'name' => 'bar', 'version' => 42})
      release.use_template_named('dea')
      template = release.template('dea')

      [:version, :blobstore, :sha1, :logs].each do |method|
        expect {
          template.send(method)
        }.to raise_error
      end

      release.bind_model
      release.bind_templates

      expect(template.version).to eq('522')
      expect(template.blobstore_id).to eq('deadbeef')
      expect(template.sha1).to eq('deadcafe')
      expect(template.logs).to eq(%w(a b c))
    end
  end
end
