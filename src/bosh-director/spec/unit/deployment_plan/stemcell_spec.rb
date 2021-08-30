require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Stemcell do
  def make(spec)
    BD::DeploymentPlan::Stemcell.parse(spec)
  end

  def make_stemcell(name, version, os = 'os1', params = {})
    BD::Models::Stemcell.make({ name: name, operating_system: os, version: version }.merge(params))
  end

  let(:valid_spec) do
    {
      'name' => 'stemcell-name',
      'version' => '0.5.2',
    }
  end

  let(:deployment) { BD::Models::Deployment.make(name: 'mycloud') }

  describe 'creating' do
    it 'parses name and version' do
      stemcell = make(valid_spec)
      expect(stemcell.name).to eq('stemcell-name')
      expect(stemcell.version).to eq('0.5.2')
    end

    it 'requires version' do
      valid_spec.delete('version')
      expect do
        make(valid_spec)
      end.to raise_error(BD::ValidationMissingField,
                         "Required property 'version' was not specified in object ({\"name\"=>\"stemcell-name\"})")
    end

    context 'os and name' do
      context 'when only os is specified' do
        it 'is valid' do
          valid_spec.delete('name')
          valid_spec['os'] = 'os1'
          expect { make(valid_spec) }.to_not raise_error
        end
      end

      context 'when only name is specified' do
        it 'is valid' do
          valid_spec.delete('os')
          valid_spec['name'] = 'stemcell-name'
          expect { make(valid_spec) }.to_not raise_error
        end
      end

      context 'when neither os or name are specified' do
        it 'raises' do
          valid_spec.delete('name')
          valid_spec.delete('os')
          expect { make(valid_spec) }.to raise_error(
            BD::ValidationMissingField,
            "Required property 'os' or 'name' was not specified in object ({\"version\"=>\"0.5.2\"})",
          )
        end
      end
      context 'when both os and name are specified' do
        it 'raises' do
          valid_spec['name'] = 'stemcell-name'
          valid_spec['os'] = 'os1'
          expect { make(valid_spec) }.to raise_error(
            BD::StemcellBothNameAndOS,
            "Properties 'os' and 'name' are both specified for stemcell, choose one. "\
            '({"name"=>"stemcell-name", "version"=>"0.5.2", "os"=>"os1"})',
          )
        end
      end
    end

    context 'stemcell with latest version' do
      let(:valid_spec) do
        {
          'name' => 'stemcell-name',
          'version' => 'latest',
        }
      end

      it 'should return string latest version' do
        stemcell = make(valid_spec)
        expect(stemcell.version).to eq('latest')
      end
    end
  end

  describe '#spec' do
    context "when there's a single CPI (default CPI)" do
      it 'returns stemcell spec as Hash' do
        stemcell = make(valid_spec)
        expect(stemcell.spec).to eq(valid_spec)
      end
    end
    context 'when there are multiple CPIs' do
      let(:multi_cpi_spec) do
        {
          'os' => 'ubuntu-bionic',
          'version' => '1.24.0',
        }
      end
      it 'returns the first stemcell (arbitrarily) in a backwards-compatible manner' do
        make_stemcell('aws', '1.24.0', 'ubuntu-bionic', 'cid' => 'cid1', 'cpi' => 'aws')
        make_stemcell('vsphere', '1.24.0', 'ubuntu-bionic', 'cid' => 'cid2', 'cpi' => 'vsphere')
        stemcell = make(multi_cpi_spec)
        stemcell.bind_model(deployment)
        expect(stemcell.spec).to eq(
          'name' => 'aws',
          'version' => '1.24.0',
        )
      end
      context 'when a CPI is passed in' do
        it 'returns the appropriate stemcell for that CPI' do
          make_stemcell('aws', '1.24.0', 'ubuntu-bionic', 'cid' => 'cid1', 'cpi' => 'aws')
          make_stemcell('vsphere', '1.24.0', 'ubuntu-bionic', 'cid' => 'cid2', 'cpi' => 'vsphere-1')
          make_stemcell('vsphere', '1.24.0', 'ubuntu-bionic', 'cid' => 'cid3', 'cpi' => 'vsphere-2')
          stemcell = make(multi_cpi_spec)
          stemcell.bind_model(deployment)
          expect(stemcell.spec('vsphere-1')).to eq(
            'name' => 'vsphere',
            'version' => '1.24.0',
          )
        end
      end
    end
  end

  it 'can not create multiple stemcells with same name and version' do
    make_stemcell('foo', '42-dev', 'os1', 'cid' => 'cid1', 'cpi' => '')
    expect do
      make_stemcell('foo', '42-dev', 'os1', 'cid' => 'cid2', 'cpi' => '')
    end.to raise_error Sequel::ValidationFailed, 'name and version and cpi unique'
  end

  describe 'binding stemcell model' do
    it 'should bind stemcell models' do
      stemcell_model1 = make_stemcell('stemcell-name', '0.5.2', 'os1', 'cpi' => 'cpi1')
      stemcell_model2 = make_stemcell('stemcell-name', '0.5.2', 'os1', 'cpi' => 'cpi2')

      stemcell = make(valid_spec)
      stemcell.bind_model(deployment)

      expect(stemcell.models[0]).to eq(stemcell_model1)
      expect(stemcell.models[1]).to eq(stemcell_model2)
      expect(stemcell_model1.deployments).to eq([deployment])
      expect(stemcell_model2.deployments).to eq([deployment])
    end

    it 'should bind to stemcell with specified OS and version' do
      stemcell_model = make_stemcell('stemcell-name', '0.5.0', 'os2')
      make_stemcell('stemcell-name', '0.5.2', 'os2')

      stemcell = make(
        'os' => 'os2',
        'version' => '0.5.0',
      )
      stemcell.bind_model(deployment)

      expect(stemcell.models.first).to eq(stemcell_model)
      expect(stemcell_model.deployments).to eq([deployment])
    end

    context 'when stemcell cannot be found' do
      it 'returns error out if specified OS and version is not found' do
        make_stemcell('stemcell-name', '0.5.0', 'os2')
        make_stemcell('stemcell-name', '0.5.2', 'os2')

        stemcell = make(
          'os' => 'os2',
          'version' => '0.5.5',
        )
        expect { stemcell.bind_model(deployment) }.to raise_error BD::StemcellNotFound
      end

      it 'returns error out if name and version is not found' do
        make_stemcell('stemcell-name1', '0.5.0')
        make_stemcell('stemcell-name2', '0.5.2')

        stemcell = make(
          'name' => 'stemcell-name3',
          'version' => '0.5.2',
        )
        expect { stemcell.bind_model(deployment) }.to raise_error BD::StemcellNotFound
      end

      it "fails if stemcell doesn't exist at all" do
        stemcell = make(valid_spec)
        expect do
          stemcell.bind_model(deployment)
        end.to raise_error(BD::StemcellNotFound)
      end
    end

    it 'binds stemcell to the first stemcell found when multiple stemcells match with OS and version' do
      make_stemcell('stemcell0', '0.5.0', 'os2')
      make_stemcell('stemcell2', '0.5.2', 'os2')

      make_stemcell('stemcell1', '0.5.2', 'os2')

      stemcell = make('os' => 'os2', 'version' => '0.5.2')

      stemcell.bind_model(deployment)

      expect(stemcell.models.first[:operating_system]).to eq('os2')
      expect(stemcell.models.first[:version]).to eq('0.5.2')
    end

    it 'binds stemcells to the deployment DB' do
      stemcell1 = make_stemcell('foo', '42-dev')
      stemcell2 = make_stemcell('bar', '55-dev')

      spec1 = { 'name' => 'foo', 'version' => '42-dev' }
      spec2 = { 'name' => 'bar', 'version' => '55-dev' }

      make(spec1).bind_model(deployment)
      make(spec2).bind_model(deployment)

      expect(deployment.stemcells).to match_array([stemcell1, stemcell2])
    end

    it "doesn't bind model if deployment plan has unbound deployment" do
      expect do
        stemcell = make('name' => 'foo', 'version' => '42')
        stemcell.bind_model(nil)
      end.to raise_error(BD::DirectorError, 'Deployment not bound in the deployment plan')
    end
  end

  describe '#model_for_az' do
    let(:cloud_factory) { instance_double(BD::AZCloudFactory) }

    it 'raises an error if no stemcell model was bound' do
      stemcell = make('name' => 'does-not-exist', 'version' => 'non-existent-version')
      expect { stemcell.model_for_az('doesntmatter', cloud_factory) }.to raise_error(/please bind model first/)
    end

    context 'when the stemcell for the default cpi does not exist' do
      let!(:stemcell_model_with_cpi1) { make_stemcell('foo', '42-dev', 'os1', cpi: 'cpi1') }

      it 'raises an error if no stemcell for the default cpi exists' do
        stemcell = make('name' => 'foo', 'version' => '42-dev')
        stemcell.bind_model(deployment)
        expect { stemcell.model_for_az(nil, cloud_factory) }.to raise_error BD::StemcellNotFound
      end
    end

    context 'when the stemcell models exist' do
      let!(:stemcell_with_default_cpi) { make_stemcell('foo', '42-dev', 'os1', cpi: '') }
      let!(:stemcell_model_with_cpi1) { make_stemcell('foo', '42-dev', 'os1', cpi: 'cpi1') }
      let!(:stemcell_model_with_cpi2) { make_stemcell('foo', '42-dev', 'os1', cpi: 'cpi2') }
      let(:stemcell) { make('name' => 'foo', 'version' => '42-dev') }

      before do
        stemcell.bind_model(deployment)
      end

      context 'when not using cpi config' do
        before do
          allow(cloud_factory).to receive(:get_name_for_az).with('az-example').and_return('')
          allow(cloud_factory).to receive(:get_cpi_aliases).with('').and_return([''])
        end

        it 'returns the model of the default stemcell when not using AZs' do
          expect(stemcell.model_for_az(nil, cloud_factory)).to eq(stemcell_with_default_cpi)
        end

        it 'returns the model of the default stemcell when using AZs without CPI' do
          expect(stemcell.model_for_az('az-example', cloud_factory)).to eq(stemcell_with_default_cpi)
        end
      end

      context 'if using cpi config' do
        let(:cpi) { 'cpi2' }
        let(:cpi_aliases) { ['cpi2'] }

        before do
          allow(cloud_factory).to receive(:get_name_for_az).with('az-example').and_return(cpi)
          allow(cloud_factory).to receive(:get_cpi_aliases).with(cpi).and_return(cpi_aliases)
        end

        it 'returns the model of the stemcell of the given az' do
          expect(stemcell.model_for_az('az-example', cloud_factory)).to eq(stemcell_model_with_cpi2)
        end

        context 'when the cpi associated with the az does not exist' do
          let(:cpi) { 'garbage' }
          let(:cpi_aliases) { ['garbage'] }

          it 'raises an error if the required stemcell for the given AZ does not exist' do
            expect { stemcell.model_for_az('az-example', cloud_factory) }.to raise_error BD::StemcellNotFound
          end
        end

        context 'when the cpi associated with the stemcell is in the list of cpi aliases' do
          let(:cpi_aliases) { ['cpi1'] }

          it 'can return a model for stemcell associated with migrated_from names' do
            expect(stemcell.model_for_az('az-example', cloud_factory)).to eq(stemcell_model_with_cpi1)
          end

          context 'when the cpi also has a stemcell' do
            let(:cpi_aliases) { ['cpi1', ''] }

            it 'returns the model for the specified cpi' do
              expect(stemcell.model_for_az('az-example', cloud_factory)).to eq(stemcell_model_with_cpi1)
            end
          end
        end
      end
    end
  end
end
