require File.expand_path('../../../spec_helper', __FILE__)

describe Bosh::Director::DeploymentPlan::CompilationConfig do
  describe :initialize do

    context 'when availability zone is specified' do
      let(:az1) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('az1', {}) }
      it 'should parse the basic properties' do
        config = BD::DeploymentPlan::CompilationConfig.new({
            'workers' => 2,
            'network' => 'foo',
            'az' => 'az1'
          }, { 'az1' => az1})

        expect(config.availability_zone).to eq(az1)
      end

      it 'should raise CompilationConfigInvalidAvailabilityZone when availability zone does not exist' do
        expect{BD::DeploymentPlan::CompilationConfig.new({
            'workers' => 2,
            'network' => 'foo',
            'az' => 'az2'
          }, { 'az1' => az1})}.to raise_error(Bosh::Director::CompilationConfigInvalidAvailabilityZone,
            "Compilation config references unknown az 'az2'. Known azs are: [az1]")
      end

      it 'should raise CompilationConfigInvalidAvailabilityZone when availability zone not in deployment' do
        expect{BD::DeploymentPlan::CompilationConfig.new({
            'workers' => 2,
            'network' => 'foo',
            'az' => 'az2'
          }, {})}.to raise_error(Bosh::Director::CompilationConfigInvalidAvailabilityZone)
      end
    end

    context 'when cloud_properties are configured' do
      it 'should parse the property' do
        config = BD::DeploymentPlan::CompilationConfig.new(
          {
            'workers' => 2,
            'network' => 'foo',
            'cloud_properties' => {'instance_type' => 'super-large'}
          },
          {},
          []
        )

        expect(config.cloud_properties).to eq({'instance_type' => 'super-large'})
      end
    end

    context 'when vm_type is configured' do
      let(:vm_type) { BD::DeploymentPlan::VmType.new({'name' => 'my-foo-compilation'}) }

      it 'should parse the property' do
        config = BD::DeploymentPlan::CompilationConfig.new(
          {
            'workers' => 2,
            'network' => 'foo',
            'vm_type' => 'my-foo-compilation',
          },
          {},
          [vm_type]
        )

        expect(config.vm_type).to eq(vm_type)
      end

      it 'it should error if the vm_type is not actually configured' do
        expect {
          BD::DeploymentPlan::CompilationConfig.new(
            {
              'workers' => 2,
              'network' => 'foo',
              'vm_type' => 'undefined-vm',
            },
            {},
            [vm_type]
          )
        }.to raise_error BD::CompilationConfigInvalidVmType,
          "Compilation config references unknown vm type 'undefined-vm'. Known vm types are: my-foo-compilation"
      end

      it 'it should error if both vm_type and cloud_properties are configured' do
        expect {
          BD::DeploymentPlan::CompilationConfig.new(
            {
              'workers' => 2,
              'network' => 'foo',
              'vm_type' => 'my-foo-compilation',
              'cloud_properties' => {
                'instance_type' => 'super-large',
              },
            },
            {},
            [vm_type]
          )
        }.to raise_error BD::CompilationConfigCloudPropertiesNotAllowed,
          "Compilation config is using vm type 'my-foo-compilation' and should not be configuring cloud_properties."
      end

      context 'when vm_extensions are configured' do
        let(:vm_extension_1) {BD::DeploymentPlan::VmExtension.new({'name' => 'my-foo-compilation-extension'})}
        let(:vm_extensions) { [vm_extension_1] }

        it 'should parse the property' do
          config = BD::DeploymentPlan::CompilationConfig.new(
              {
                  'workers' => 2,
                  'network' => 'foo',
                  'vm_type' => 'my-foo-compilation',
                  'vm_extensions' => ['my-foo-compilation-extension']
              },
              {},
              [vm_type],
              vm_extensions
          )

          expect(config.vm_extensions).to eq(vm_extensions)
        end

        it 'it should error if the vm_extension is not actually configured' do
          expect {
            BD::DeploymentPlan::CompilationConfig.new(
                {
                    'workers' => 2,
                    'network' => 'foo',
                    'vm_type' => 'my-foo-compilation',
                    'vm_extensions' => ['my-foo-compilation-extension', 'undefined-vm']
                },
                {},
                [vm_type],
                [vm_extension_1]
            )
          }.to raise_error BD::CompilationConfigInvalidVmExtension,
                           "Compilation config references unknown vm extension 'undefined-vm'. Known vm extensions are: my-foo-compilation-extension"
        end


      end
    end

    context 'when vm_type is not configured' do
      context 'when vm_extensions are configured' do
        let(:vm_extension_1) { BD::DeploymentPlan::VmExtension.new({'name' => 'my-foo-compilation-extension'}) }
        let(:vm_extensions) { [vm_extension_1] }

        it 'should parse the property' do
          expect {
            BD::DeploymentPlan::CompilationConfig.new(
                {
                    'workers' => 2,
                    'network' => 'foo',
                    'cloud_properties' => {'instance_type' => 'super-large'},
                    'vm_extensions' => ['my-foo-compilation-extension']
                },
                {},
                [],
                vm_extensions
            ) }.to raise_error BD::CompilationConfigVmTypeRequired,
                               "Compilation config is using vm extension 'my-foo-compilation-extension' and must configure a vm type."
        end
      end
    end

    context 'when availability zone is not specified' do
      it 'should parse the basic properties' do
        config = BD::DeploymentPlan::CompilationConfig.new({
            'workers' => 2,
            'network' => 'foo',
            'cloud_properties' => {
              'foo' => 'bar'
            }
          }, {})

        expect(config.workers).to eq(2)
        expect(config.cloud_properties).to eq({'foo' => 'bar'})
        expect(config.env).to eq({})
      end

      it 'should require workers to be specified' do
        expect {
          BD::DeploymentPlan::CompilationConfig.new({
              'network' => 'foo',
              'cloud_properties' => {
                'foo' => 'bar'
              }
            }, {})
        }.to raise_error(BD::ValidationMissingField)
      end

      it 'should require there to be at least 1 worker' do
        expect {
          BD::DeploymentPlan::CompilationConfig.new({
              'workers' => 0,
              'network' => 'foo',
              'cloud_properties' => {
                'foo' => 'bar'
              }
            }, {})
        }.to raise_error(BD::ValidationViolatedMin)
      end

      it 'should require a network to be specified' do
        expect {
          BD::DeploymentPlan::CompilationConfig.new({
              'workers' => 1,
              'cloud_properties' => {
                'foo' => 'bar'
              }
            }, {})
        }.to raise_error(BD::ValidationMissingField)
      end

      it 'defaults resource pool cloud properties to empty hash' do
        config = BD::DeploymentPlan::CompilationConfig.new({
            'workers' => 1,
            'network' => 'foo'
          }, {})
        expect(config.cloud_properties).to eq({})
      end

      it 'should allow an optional environment to be set' do
        config = BD::DeploymentPlan::CompilationConfig.new({
            'workers' => 1,
            'network' => 'foo',
            'cloud_properties' => {
              'foo' => 'bar'
            },
            'env' => {
              'password' => 'password1'
            }
          }, {})
        expect(config.env).to eq({'password' => 'password1'})
      end

      it 'should allow reuse_compilation_vms to be set' do
        config = BD::DeploymentPlan::CompilationConfig.new({
            'workers' => 1,
            'network' => 'foo',
            'cloud_properties' => {
              'foo' => 'bar'
            },
            'reuse_compilation_vms' => true
          }, {})
        expect(config.reuse_compilation_vms).to eq(true)
      end

      it 'should throw an error when a boolean property isnt boolean' do
        expect {
          BD::DeploymentPlan::CompilationConfig.new({
              'workers' => 1,
              'network' => 'foo',
              'cloud_properties' => {
                'foo' => 'bar'
              },
              # the non-boolean boolean
              'reuse_compilation_vms' => 1
            }, {})
        }.to raise_error(Bosh::Director::ValidationInvalidType)

      end
    end
  end
end
