require 'spec_helper'

describe Bosh::Director::DeploymentPlan::ReleaseVersion do
  def make(plan, spec)
    BD::DeploymentPlan::ReleaseVersion.new(plan, spec)
  end

  def make_plan(deployment)
    instance_double('Bosh::Director::DeploymentPlan::Planner', :model => deployment)
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
      spec = {'name' => 'foo', 'version' => '42-dev'}
      deployment = make_deployment('mycloud')
      plan = make_plan(deployment)
      rv1 = make_version('foo', '42-dev')

      release = make(plan, spec)
      release.bind_model

      release.model.should == rv1
      deployment.release_versions.should == [rv1]
    end

    it "should fail if release doesn't exist" do
      deployment = make_deployment('mycloud')
      plan = make_plan(deployment)
      spec = {'name' => 'foo', 'version' => '42-dev'}

      expect {
        release = make(plan, spec)
        release.bind_model
      }.to raise_error(BD::ReleaseNotFound)
    end

    it "should fail if release version doesn't exist" do
      deployment = make_deployment('mycloud')
      plan = make_plan(deployment)
      spec = {'name' => 'foo', 'version' => '42-dev'}
      make_version('foo', '55-dev')

      expect {
        release = make(plan, spec)
        release.bind_model
      }.to raise_error(BD::ReleaseVersionNotFound)
    end

    it 'binds release versions to the deployment in DB' do
      deployment = make_deployment('mycloud')
      plan = make_plan(deployment)

      rv1 = make_version('foo', '42-dev')
      rv2 = make_version('bar', '55-dev')

      spec1 = {'name' => 'foo', 'version' => '42-dev'}
      spec2 = {'name' => 'bar', 'version' => '55-dev'}

      make(plan, spec1).bind_model
      make(plan, spec2).bind_model

      deployment.release_versions.should =~ [rv1, rv2]
    end

    it "doesn't bind model if deployment plan has unbound deployment" do
      plan = make_plan(nil)

      expect {
        release = make(plan, {'name' => 'foo', 'version' => '42'})
        release.bind_model
      }.to raise_error(BD::DirectorError,
                       'Deployment not bound in the deployment plan')
    end
  end

  describe 'looking up/adding templates' do
    it 'registers templates used in the release' do
      plan = make_plan(nil)
      spec = {'name' => 'foo', 'version' => '42-dev'}

      release = make(plan, spec)
      release.templates.should == []
      release.use_template_named('foobar')
      release.templates.size.should == 1
      template = release.templates[0]
      release.template('foobar').should == template
      template.name.should == 'foobar'
      template.release.should == release
      template.model.should be_nil
    end

    it 'finds template/package models by name' do
      deployment = make_deployment('mycloud')
      plan = make_plan(deployment)
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

      release = make(plan, {'name' => 'foo', 'version' => '42'})
      release.bind_model
      release.get_template_model_by_name('dea').should == t1
      release.get_template_model_by_name('stager').should == nil

      release.get_package_model_by_name('ruby18').should == p1
      expect { release.get_package_model_by_name('ruby19') }.to raise_error /key not found/
      expect { release.get_package_model_by_name('ruby20') }.to raise_error /key not found/

      release = make(plan, {'name' => 'bar', 'version' => '55'})
      release.bind_model
      release.get_template_model_by_name('dea').should == nil
      release.get_template_model_by_name('stager').should == t2
      expect { release.get_package_model_by_name('ruby18') }.to raise_error /key not found/
      release.get_package_model_by_name('ruby19').should == p2
      release.get_package_model_by_name('ruby20').should == p3
    end
  end

  describe 'binding templates' do
    it 'delegates binding to individual template spec classes' do
      deployment = make_deployment('mycloud')
      plan = make_plan(deployment)

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

      release = make(plan, {'name' => 'bar', 'version' => '42'})
      release.use_template_named('dea')

      release.bind_model
      release.bind_templates

      release.template('dea').model.should == t_dea
      release.template('dea').package_models.should =~ [p_ruby, p_node]

      # Making sure once bound template stays bound if we call
      # #use_template_named again
      release.use_template_named('dea')
      release.template('dea').model.should == t_dea
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

      plan = make_plan(make_deployment('mycloud'))

      bar_42 =
        BD::Models::ReleaseVersion.make(:release => r_bar, :version => '42')
      bar_42.add_template(t_dea)

      release = make(plan, {'name' => 'bar', 'version' => 42})
      release.use_template_named('dea')
      template = release.template('dea')

      [:version, :blobstore, :sha1, :logs].each do |method|
        expect {
          template.send(method)
        }.to raise_error
      end

      release.bind_model
      release.bind_templates

      template.version.should == '522'
      template.blobstore_id.should == 'deadbeef'
      template.sha1.should == 'deadcafe'
      template.logs.should == %w(a b c)
    end
  end
end
