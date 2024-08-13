require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::DeployedVariablesController do
      include IpUtil
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }

      let(:config) do
        config = Config.load_hash(SpecHelper.spec_get_director_config)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end

      before { basic_authorize 'admin', 'admin' }

      describe '/:name' do
        before do
          Models::Variable.make(
            id: 1,
            variable_id: 'var_id_1',
            variable_name: '/Test Director/test_deployment/var_name_1',
            variable_set_id: deployment_1_variable_set.id,
          )
          Models::Variable.make(
            id: 2,
            variable_id: 'var_id_2',
            variable_name: '/Test Director/test_deployment/var_name_2',
            variable_set_id: deployment_1_variable_set.id,
          )
          Models::Variable.make(
            id: 3,
            variable_id: 'var_id_1',
            variable_name: '/Test Director/test_deployment/var_name_1',
            variable_set_id: deployment_2_variable_set.id,
          )
          Models::Variable.make(
            id: 5,
            variable_id: 'var_id_3',
            variable_name: '/Test Director/test_deployment/var_name_3',
            variable_set_id: deployment_2_variable_set.id,
          )
        end

        let(:deployment_1_manifest) do
          {
            'name' => 'test_deployment',
            'variables' => [
              { 'name' => 'var_name_1' },
              { 'name' => 'var_name_2' },
            ],
          }
        end

        let(:deployment_2_manifest) do
          {
            'name' => 'test_deployment_2',
            'variables' => [
              { 'name' => 'var_name_1' },
              { 'name' => 'var_name_3' },
            ],
          }
        end

        let!(:deployment_1) do
          FactoryBot.create(:models_deployment, name: 'test_deployment_1', manifest: deployment_1_manifest.to_yaml)
        end

        let!(:deployment_2) do
          FactoryBot.create(:models_deployment, name: 'test_deployment_2', manifest: deployment_2_manifest.to_yaml)
        end

        let!(:deployment_1_variable_set) do
          Models::VariableSet.make(id: 1, deployment: deployment_1, deployed_successfully: true)
        end

        let!(:deployment_2_variable_set) do
          Models::VariableSet.make(id: 2, deployment: deployment_2, deployed_successfully: true)
        end

        it 'returns an empty array if there are no matching deployments' do
          get '/foo'
          expect(last_response.status).to eq(200)
          vars = JSON.parse(last_response.body)
          expect(vars['deployments']).to be_empty
        end

        it 'returns a list of all the deployments that are using the queried variable name' do
          get '/%2FTest%20Director%2Ftest_deployment%2Fvar_name_1' # CGI.escape full variable path
          expect(last_response.status).to eq(200)
          vars = JSON.parse(last_response.body)
          expect(vars['deployments']).to match_array(
            [
              { 'name' => 'test_deployment_1', 'version' => 'var_id_1' },
              { 'name' => 'test_deployment_2', 'version' => 'var_id_1' },
            ],
          )

          get '/%2FTest%20Director%2Ftest_deployment%2Fvar_name_2'
          expect(last_response.status).to eq(200)
          vars = JSON.parse(last_response.body)
          expect(vars['deployments']).to match_array(
            [
              { 'name' => 'test_deployment_1', 'version' => 'var_id_2' },
            ],
          )

          get '/%2FTest%20Director%2Ftest_deployment%2Fvar_name_3'
          expect(last_response.status).to eq(200)
          vars = JSON.parse(last_response.body)
          expect(vars['deployments']).to match_array(
            [
              { 'name' => 'test_deployment_2', 'version' => 'var_id_3' },
            ],
          )
        end

        context 'with a user with team permissions' do
          before do
            deployment_1.teams = [Models::Team.make(name: 'dev')]
            deployment_2.teams = [Models::Team.make(name: 'TheEvilTeam')]
            basic_authorize 'dev-team-member', 'dev-team-member'
          end

          it 'only returns variables for deployments that the user is authorized to see' do
            get '/%2FTest%20Director%2Ftest_deployment%2Fvar_name_1' # CGI.escape full variable path
            expect(last_response.status).to eq(200)
            vars = JSON.parse(last_response.body)
            expect(vars['deployments']).to match_array(
              [
                { 'name' => 'test_deployment_1', 'version' => 'var_id_1' },
              ],
            )
          end
        end

        context 'when a deployment has no successful variable set' do
          before do
            deployment_1.cleanup_variable_sets([])
          end

          it 'still returns the relevant deployments' do
            get '/%2FTest%20Director%2Ftest_deployment%2Fvar_name_1' # CGI.escape full variable path
            expect(last_response.status).to eq(200)
            vars = JSON.parse(last_response.body)
            expect(vars['deployments']).to match_array(
              [
                { 'name' => 'test_deployment_2', 'version' => 'var_id_1' },
              ],
            )
          end
        end
      end
    end
  end
end
