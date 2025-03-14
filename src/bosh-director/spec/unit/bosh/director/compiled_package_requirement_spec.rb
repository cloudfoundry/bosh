require 'spec_helper'

module Bosh::Director
  describe CompiledPackageRequirement do
    include Support::StemcellHelpers

    let(:instance_group) { double('instance_group').as_null_object }
    let(:precompiled_package) { nil }

    def new_compiled_package_requirement(package, stemcell)
      CompiledPackageRequirement.new(
        package: package,
        stemcell: stemcell,
        initial_instance_group: instance_group,
        dependency_key: 'fake-dependency-key',
        cache_key: 'fake-cache-key',
        compiled_package: precompiled_package,
      )
    end

    describe 'creation' do
      let(:package_name) { 'package_name' }
      let(:package_fingerprint) { 'fingerprint' }
      let(:stemcell_sha1) { 'sha1' }
      let(:stemcell) { double('stemcell', sha1: stemcell_sha1) }
      let(:package) { double('package', name: package_name, fingerprint: package_fingerprint) }
      let(:dep_pkg2) { double('dependent package 2', fingerprint: 'dp_fingerprint2', version: '9.2-dev', name: 'zyx') }
      let(:dep_pkg1) { double('dependent package 1', fingerprint: 'dp_fingerprint1', version: '10.1-dev', name: 'abc') }

      let(:dep_requirement2) { new_compiled_package_requirement(dep_pkg2, stemcell) }
      let(:dep_requirement1) { new_compiled_package_requirement(dep_pkg1, stemcell) }

      let(:dependent_packages) { [] }

      subject(:requirement) do
        new_compiled_package_requirement(package, stemcell)
      end

      context 'with an initial instance_group' do
        let(:instance_group) { double('instance_group') }

        it 'can create' do
          expect(requirement.instance_groups).to eq([instance_group])
        end
      end

      context 'with a compiled package' do
        let(:precompiled_package) { double('compiled_package') }

        it 'is compiled' do
          expect(requirement.compiled?).to eq(true)
        end
      end
    end

    describe 'compilation readiness' do
      let(:package) { FactoryBot.create(:models_package, name: 'foo') }
      let(:stemcell) { FactoryBot.create(:models_stemcell, operating_system: 'chrome-os', version: 'latest') }
      let(:compiled_package) { FactoryBot.create(:models_compiled_package, package: package, stemcell_os: 'chrome-os', stemcell_version: 'latest') }

      it 'can tell if compiled' do
        requirement = new_compiled_package_requirement(package, stemcell)
        expect(requirement.ready_to_compile?).to be(true)
        expect(requirement.compiled?).to be(false)

        requirement.use_compiled_package(compiled_package)
        expect(requirement.compiled?).to be(true)
        expect(requirement.ready_to_compile?).to be(false) # Already compiled!
      end

      it 'is ready to compile when all dependencies are compiled' do
        dep1 = FactoryBot.create(:models_package, name: 'bar')
        dep2 = FactoryBot.create(:models_package, name: 'baz')

        requirement = new_compiled_package_requirement(package, stemcell)
        dep1_requirement = new_compiled_package_requirement(dep1, stemcell)
        dep2_requirement = new_compiled_package_requirement(dep2, stemcell)

        requirement.add_dependency(dep1_requirement)
        requirement.add_dependency(dep2_requirement)

        expect(requirement.all_dependencies_compiled?).to be(false)
        dep1_requirement.use_compiled_package(compiled_package)
        expect(requirement.all_dependencies_compiled?).to be(false)
        dep2_requirement.use_compiled_package(compiled_package)
        expect(requirement.all_dependencies_compiled?).to be(true)
        expect(requirement.ready_to_compile?).to be(true)
      end
    end

    describe 'adding dependencies' do
      it 'works both ways' do
        stemcell = FactoryBot.create(:models_stemcell)
        foo = FactoryBot.create(:models_package, name: 'foo')
        bar = FactoryBot.create(:models_package, name: 'bar')
        baz = FactoryBot.create(:models_package, name: 'baz')

        foo_requirement = new_compiled_package_requirement(foo, stemcell)
        bar_requirement = new_compiled_package_requirement(bar, stemcell)
        baz_requirement = new_compiled_package_requirement(baz, stemcell)

        expect(foo_requirement.dependencies).to eq([])
        expect(bar_requirement.dependent_requirements).to eq([])

        foo_requirement.add_dependency(bar_requirement)
        expect(foo_requirement.dependencies).to eq([bar_requirement])
        expect(bar_requirement.dependent_requirements).to eq([foo_requirement])

        baz_requirement.add_dependent_requirement(foo_requirement)
        expect(baz_requirement.dependent_requirements).to eq([foo_requirement])
        expect(foo_requirement.dependencies).to eq([bar_requirement, baz_requirement])
      end
    end

    describe 'using compiled package' do
      let(:instance_group) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup') }

      it 'registers compiled package with instance_group' do
        package = FactoryBot.create(:models_package)
        stemcell = FactoryBot.create(:models_stemcell)

        cp = FactoryBot.create(:models_compiled_package, stemcell_os: 'firefox_os', stemcell_version: '2')
        cp2 = FactoryBot.create(:models_compiled_package, stemcell_os: 'firefox_os', stemcell_version: '2')

        requirement = new_compiled_package_requirement(package, stemcell)

        instance_group_a = instance_group
        instance_group_b = instance_double('Bosh::Director::DeploymentPlan::InstanceGroup')

        expect(instance_group_a).to receive(:use_compiled_package).with(cp)
        expect(instance_group_b).to receive(:use_compiled_package).with(cp)

        requirement.use_compiled_package(cp)
        requirement.add_instance_group(instance_group_a)
        requirement.add_instance_group(instance_group_b)

        expect(requirement.instance_groups).to eq([instance_group_a, instance_group_b])

        expect(instance_group_a).to receive(:use_compiled_package).with(cp2)
        expect(instance_group_b).to receive(:use_compiled_package).with(cp2)
        requirement.use_compiled_package(cp2)
      end
    end

    describe 'generating dependency spec' do
      it 'generates dependency spec' do
        stemcell = FactoryBot.create(:models_stemcell)
        foo = FactoryBot.create(:models_package, name: 'foo')
        bar = FactoryBot.create(:models_package, name: 'bar', version: '42')
        cp = FactoryBot.create(:models_compiled_package, package: bar, build: 152, sha1: 'deadbeef', blobstore_id: 'deadcafe', stemcell_os: 'linux', stemcell_version: '2.6.11')

        foo_requirement = new_compiled_package_requirement(foo, stemcell)
        bar_requirement = new_compiled_package_requirement(bar, stemcell)

        foo_requirement.add_dependency(bar_requirement)

        expect do
          foo_requirement.dependency_spec
        end.to raise_error(DirectorError, /'bar' hasn't been compiled yet/i)

        bar_requirement.use_compiled_package(cp)

        expect(foo_requirement.dependency_spec).to eq(
          'bar' => {
            'name' => 'bar',
            'version' => '42.152',
            'sha1' => 'deadbeef',
            'blobstore_id' => 'deadcafe',
          },
        )
      end

      it "doesn't include nested dependencies" do
        stemcell = FactoryBot.create(:models_stemcell)
        foo = FactoryBot.create(:models_package, name:  'foo')
        bar = FactoryBot.create(:models_package, name:  'bar', version: '42')
        baz = FactoryBot.create(:models_package, name:  'baz', version: '17')

        cp_bar = FactoryBot.create(:models_compiled_package, package: bar, build: 152, sha1: 'deadbeef', blobstore_id: 'deadcafe', stemcell_os: 'chrome-os', stemcell_version: 'latest')

        foo_requirement = new_compiled_package_requirement(foo, stemcell)
        bar_requirement = new_compiled_package_requirement(bar, stemcell)
        baz_requirement = new_compiled_package_requirement(baz, stemcell)

        foo_requirement.add_dependency(bar_requirement)
        bar_requirement.add_dependency(baz_requirement)

        expect(foo_requirement.dependencies).to eq([bar_requirement]) # only includes immediate deps!
        expect(bar_requirement.dependencies).to eq([baz_requirement])

        bar_requirement.use_compiled_package(cp_bar)

        expect(foo_requirement.dependency_spec).to eq(
          'bar' => {
            'name' => 'bar',
            'version' => '42.152',
            'sha1' => 'deadbeef',
            'blobstore_id' => 'deadcafe',
          },
        )
      end
    end
  end
end
