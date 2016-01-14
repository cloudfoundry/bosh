require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Stemcell do
  def make(spec)
    BD::DeploymentPlan::Stemcell.new(spec)
  end

  def make_plan(deployment = nil)
    instance_double('Bosh::Director::DeploymentPlan::Planner', :model => deployment)
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  def make_stemcell(name, version, os = 'os1')
    BD::Models::Stemcell.make(:name => name, :operating_system=>os, :version => version)
  end

  let(:valid_spec) do
    {
      "name" => "stemcell-name",
      "version" => "0.5.2"
    }
  end

  describe "creating" do
    it "parses name and version" do
      sc = make(valid_spec)
      expect(sc.name).to eq("stemcell-name")
      expect(sc.version).to eq("0.5.2")
    end

    it "requires version" do
        valid_spec.delete('version')
        expect {
          make(valid_spec)
        }.to raise_error(BD::ValidationMissingField,
            "Required property `version' was not specified in object ({\"name\"=>\"stemcell-name\"})")
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
              "Required property `os' or `name' was not specified in object ({\"version\"=>\"0.5.2\"})")
        end
      end
      context 'when both os and name are specified' do
        it 'raises' do
          valid_spec['name'] = 'stemcell-name'
          valid_spec['os'] = 'os1'
          expect { make(valid_spec) }.to raise_error(BD::StemcellBothNameAndOS,
              "Properties `os' and `name' are both specified for stemcell, choose one. ({\"name\"=>\"stemcell-name\", \"version\"=>\"0.5.2\", \"os\"=>\"os1\"})")
        end
      end
    end

    context 'stemcell with latest version' do
      let(:valid_spec) do
        {
          "name" => "stemcell-name",
          "version" => "latest"
        }
      end

      it 'should return string latest version' do
        sc = make(valid_spec)
        expect(sc.version).to eq('latest')
      end
    end
  end

  it "returns stemcell spec as Hash" do
    sc = make(valid_spec)
    expect(sc.spec).to eq(valid_spec)
  end

  describe "binding stemcell model" do
    it "should bind stemcell model" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)
      stemcell = make_stemcell("stemcell-name", "0.5.2")

      sc = make(valid_spec)
      sc.bind_model(plan)

      expect(sc.model).to eq(stemcell)
      expect(stemcell.deployments).to eq([deployment])
    end

    it "should bind to stemcell with specified OS and version" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)

      stemcell1 = make_stemcell("stemcell-name", "0.5.0", 'os2')
      make_stemcell("stemcell-name", "0.5.2", 'os2')

      sc = make({
          'os' => 'os2',
          "version" => "0.5.0"})
      sc.bind_model(plan)

      expect(sc.model).to eq(stemcell1)
      expect(stemcell1.deployments).to eq([deployment])
    end

    context "when stemcell cannot be found" do

      it "returns error out if specified OS and version is not found" do
        deployment = make_deployment("mycloud")
        plan = make_plan(deployment)

        make_stemcell("stemcell-name", "0.5.0", 'os2')
        make_stemcell("stemcell-name", "0.5.2", 'os2')

        sc = make({
            'os' => 'os2',
            "version" => "0.5.5"})
        expect { sc.bind_model(plan) }.to raise_error BD::StemcellNotFound
      end

      it "returns error out if name and version is not found" do
        deployment = make_deployment("mycloud")
        plan = make_plan(deployment)

        make_stemcell("stemcell-name1", "0.5.0")
        make_stemcell("stemcell-name2", "0.5.2")

        sc = make({
            'name' => 'stemcell-name3',
            "version" => "0.5.2"})
        expect { sc.bind_model(plan) }.to raise_error BD::StemcellNotFound
      end

      it "fails if stemcell doesn't exist at all" do
        deployment = make_deployment("mycloud")
        plan = make_plan(deployment)

        sc = make(valid_spec)
        expect {
          sc.bind_model(plan)
        }.to raise_error(BD::StemcellNotFound)
      end
    end

    it "binds stemcell to the first stemcell found when multiple stemcells match with OS and version" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)

      make_stemcell("stemcell0", "0.5.0", 'os2')
      make_stemcell("stemcell2", "0.5.2", 'os2')

      stemcell_model1 = make_stemcell("stemcell1", "0.5.2", 'os2')

      stemcell = make({"os" => "os2", "version" => "0.5.2"})

      stemcell.bind_model(plan)

      expect(stemcell.model[:operating_system]).to eq('os2')
      expect(stemcell.model[:version]).to eq('0.5.2')
    end

    it "binds stemcells to the deployment DB" do
      deployment = make_deployment("mycloud")
      plan = make_plan(deployment)

      sc1 = make_stemcell("foo", "42-dev")
      sc2 = make_stemcell("bar", "55-dev")

      spec1 = {"name" => "foo", "version" => "42-dev"}
      spec2 = {"name" => "bar", "version" => "55-dev"}

      make(spec1).bind_model(plan)
      make(spec2).bind_model(plan)

      expect(deployment.stemcells).to match_array([sc1, sc2])
    end

    it "doesn't bind model if deployment plan has unbound deployment" do
      plan = make_plan(nil)
      expect {
        sc = make({"name" => "foo", "version" => "42"})
        sc.bind_model(plan)
      }.to raise_error(BD::DirectorError,
                       "Deployment not bound in the deployment plan")
    end
  end
end
