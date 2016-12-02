require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Stemcell do
  def make(spec)
    BD::DeploymentPlan::Stemcell.parse(spec)
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  def make_stemcell(name, version, os = 'os1', params = {})
    BD::Models::Stemcell.make({:name => name, :operating_system=>os, :version => version}.merge(params))
  end

  let(:valid_spec) do
    {
      'name' => 'stemcell-name',
      'version' => '0.5.2'
    }
  end

  describe 'creating' do
    it 'parses name and version' do
      stemcell = make(valid_spec)
      expect(stemcell.name).to eq('stemcell-name')
      expect(stemcell.version).to eq('0.5.2')
    end

    it 'requires version' do
        valid_spec.delete('version')
        expect {
          make(valid_spec)
        }.to raise_error(BD::ValidationMissingField,
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
          expect { make(valid_spec) }.to raise_error(BD::ValidationMissingField,
              "Required property 'os' or 'name' was not specified in object ({\"version\"=>\"0.5.2\"})")
        end
      end
      context 'when both os and name are specified' do
        it 'raises' do
          valid_spec['name'] = 'stemcell-name'
          valid_spec['os'] = 'os1'
          expect { make(valid_spec) }.to raise_error(BD::StemcellBothNameAndOS,
              "Properties 'os' and 'name' are both specified for stemcell, choose one. ({\"name\"=>\"stemcell-name\", \"version\"=>\"0.5.2\", \"os\"=>\"os1\"})")
        end
      end
    end

    context 'stemcell with latest version' do
      let(:valid_spec) do
        {
          'name' => 'stemcell-name',
          'version' => 'latest'
        }
      end

      it 'should return string latest version' do
        stemcell = make(valid_spec)
        expect(stemcell.version).to eq('latest')
      end
    end
  end

  it 'returns stemcell spec as Hash' do
    stemcell = make(valid_spec)
    expect(stemcell.spec).to eq(valid_spec)
  end

  describe 'binding stemcell model' do
    it 'should bind stemcell models' do
      deployment = make_deployment('mycloud')
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
      deployment = make_deployment('mycloud')
      stemcell_model = make_stemcell('stemcell-name', '0.5.0', 'os2')
      make_stemcell('stemcell-name', '0.5.2', 'os2')

      stemcell = make({
        'os' => 'os2',
        'version' => '0.5.0'
      })
      stemcell.bind_model(deployment)

      expect(stemcell.models.first).to eq(stemcell_model)
      expect(stemcell_model.deployments).to eq([deployment])
    end

    context 'when stemcell cannot be found' do

      it 'returns error out if specified OS and version is not found' do
        deployment = make_deployment('mycloud')

        make_stemcell('stemcell-name', '0.5.0', 'os2')
        make_stemcell('stemcell-name', '0.5.2', 'os2')

        stemcell = make({
          'os' => 'os2',
          'version' => '0.5.5'
        })
        expect { stemcell.bind_model(deployment) }.to raise_error BD::StemcellNotFound
      end

      it 'returns error out if name and version is not found' do
        deployment = make_deployment('mycloud')

        make_stemcell('stemcell-name1', '0.5.0')
        make_stemcell('stemcell-name2', '0.5.2')

        stemcell = make({
          'name' => 'stemcell-name3',
          'version' => '0.5.2'
        })
        expect { stemcell.bind_model(deployment) }.to raise_error BD::StemcellNotFound
      end

      it "fails if stemcell doesn't exist at all" do
        deployment = make_deployment('mycloud')

        stemcell = make(valid_spec)
        expect {
          stemcell.bind_model(deployment)
        }.to raise_error(BD::StemcellNotFound)
      end
    end

    it 'binds stemcell to the first stemcell found when multiple stemcells match with OS and version' do
      deployment = make_deployment('mycloud')

      make_stemcell('stemcell0', '0.5.0', 'os2')
      make_stemcell('stemcell2', '0.5.2', 'os2')

      make_stemcell('stemcell1', '0.5.2', 'os2')

      stemcell = make({'os' => 'os2', 'version' => '0.5.2'})

      stemcell.bind_model(deployment)

      expect(stemcell.models.first[:operating_system]).to eq('os2')
      expect(stemcell.models.first[:version]).to eq('0.5.2')
    end

    it 'binds stemcells to the deployment DB' do
      deployment = make_deployment('mycloud')

      stemcell_1 = make_stemcell('foo', '42-dev')
      stemcell_2 = make_stemcell('bar', '55-dev')

      spec_1 = {'name' => 'foo', 'version' => '42-dev'}
      spec_2 = {'name' => 'bar', 'version' => '55-dev'}

      make(spec_1).bind_model(deployment)
      make(spec_2).bind_model(deployment)

      expect(deployment.stemcells).to match_array([stemcell_1, stemcell_2])
    end

    it "doesn't bind model if deployment plan has unbound deployment" do
      expect {
        stemcell = make({'name' => 'foo', 'version' => '42'})
        stemcell.bind_model(nil)
      }.to raise_error(BD::DirectorError, 'Deployment not bound in the deployment plan')
    end
  end

  describe '#cid_for_az' do
    let(:cloud_factory) { instance_double(BD::CloudFactory) }
    before {
      allow(BD::CloudFactory).to receive(:new).and_return(cloud_factory)
    }

    it 'raises an error if no stemcell model was bound' do
      stemcell = make({'name' => 'foo', 'version' => '42-dev'})
      expect {  stemcell.cid_for_az('doesntmatter')  }.to raise_error /please bind model first/
    end

    context 'if not using cpi config' do
      it 'can not create multiple stemcells with same name and version' do
        make_stemcell('foo', '42-dev', 'os1', 'cid' => 'cid1', 'cpi' => '')
        expect {
          make_stemcell('foo', '42-dev', 'os1', 'cid' => 'cid2', 'cpi' => '')
        }.to raise_error Sequel::ValidationFailed, "name and version and cpi unique"
      end

      it 'raises an error if no stemcell for the default cpi exists' do
        deployment = make_deployment('mycloud')

        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi1', 'cid' => 'cid1') # there's only a stemcell for another cpi

        stemcell = make({'name' => 'foo', 'version' => '42-dev'})
        stemcell.bind_model(deployment)

        expect {  stemcell.cid_for_az(nil)  }.to raise_error BD::StemcellNotFound
      end

      it 'returns the cid of the default stemcell when not using AZs' do
        deployment = make_deployment('mycloud')

        make_stemcell('foo', '42-dev', 'os1', 'cpi' => '', 'cid' => 'cid1') # stemcell without cpi config
        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi1', 'cid' => 'cid2')
        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi2', 'cid' => 'cid3')

        stemcell = make({'name' => 'foo', 'version' => '42-dev'})
        stemcell.bind_model(deployment)

        expect(stemcell.cid_for_az(nil)).to eq('cid1')
      end

      it 'returns the cid of the default stemcell when using AZs without CPI' do
        deployment = make_deployment('mycloud')

        make_stemcell('foo', '42-dev', 'os1', 'cpi' => '', 'cid' => 'cid1') # stemcell without cpi config
        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi1', 'cid' => 'cid2')
        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi2', 'cid' => 'cid3')

        stemcell = make({'name' => 'foo', 'version' => '42-dev'})
        stemcell.bind_model(deployment)

        allow(cloud_factory).to receive(:lookup_cpi_for_az).with('az-example').and_return(nil)
        expect(stemcell.cid_for_az('az-example')).to eq('cid1')
      end
    end

    context 'if using cpi config' do
      it 'returns the cid of the stemcell of the given az' do
        deployment = make_deployment('mycloud')

        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi1', 'cid' => 'cid1')
        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi2', 'cid' => 'cid2')

        stemcell = make({'name' => 'foo', 'version' => '42-dev'})
        stemcell.bind_model(deployment)

        allow(cloud_factory).to receive(:lookup_cpi_for_az).with('az-example').and_return('cpi2')
        expect(stemcell.cid_for_az('az-example')).to eq('cid2')
      end

      it 'raises an error if the required stemcell for the given AZ does not exist' do
        deployment = make_deployment('mycloud')

        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi1', 'cid' => 'cid1')

        stemcell = make({'name' => 'foo', 'version' => '42-dev'})
        stemcell.bind_model(deployment)

        allow(cloud_factory).to receive(:lookup_cpi_for_az).with('az-example').and_return('cpi-notexisting')
        expect {  stemcell.cid_for_az('az-example')  }.to raise_error BD::StemcellNotFound
      end
    end

    context 'if switching to cpi config with prior stemcells' do
      it 'returns the cid of the stemcell of the given az' do
        deployment = make_deployment('mycloud')

        make_stemcell('foo', '42-dev', 'os1', 'cpi' => '', 'cid' => 'cid1') # stemcell without cpi config
        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi1', 'cid' => 'cid2')
        make_stemcell('foo', '42-dev', 'os1', 'cpi' => 'cpi2', 'cid' => 'cid3')

        stemcell = make({'name' => 'foo', 'version' => '42-dev'})
        stemcell.bind_model(deployment)

        allow(cloud_factory).to receive(:lookup_cpi_for_az).with('az-example').and_return('cpi2')
        expect(stemcell.cid_for_az('az-example')).to eq('cid3')
      end
    end
  end
end
