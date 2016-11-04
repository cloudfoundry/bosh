require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe LinkInfo do
      context '#spec' do
        let(:link_spec) do
          {
            "networks"=> ["default_1"],
            "properties"=> {
              "listen_port"=> "Kittens"
            },
            "instances"=> [{
                             "name"=> "provider_",
                             "index"=> 0,
                             "bootstrap"=> true,
                             "id"=> "vroom",
                             "az"=> "z1",
                             "address"=> "10.244.0.4"
                           }
            ]
          }
        end

        let(:deployment_name){ 'some_deployment_name'}

        let(:expected_link_info_spec)do
          {
            "deployment_name" => "some_deployment_name",
            "networks"=> ["default_1"],
            "properties"=> {
              "listen_port"=> "Kittens"
            },
            "instances"=> [{
                             "name"=> "provider_",
                             "index"=> 0,
                             "bootstrap"=> true,
                             "id"=> "vroom",
                             "az"=> "z1",
                             "address"=> "10.244.0.4"
                           }
            ]
          }
        end

        it 'returns spec with deployment_name merged' do
          link_info = Bosh::Director::DeploymentPlan::LinkInfo.new(deployment_name, link_spec)

          expect(link_info.spec).to eq(expected_link_info_spec)
        end
      end
    end
  end
end
