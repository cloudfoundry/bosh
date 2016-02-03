# require 'rspec'
# require 'yaml'
# require 'bosh/template/evaluation_context'
# require 'json'
#
# describe 'postgres_ctl.erb' do
#   let(:deployment_manifest_fragment) do
#     {
#       'properties' => {
#         'postgres' => {
#           'host' => '127.0.0.1',
#           'user' => 'postgres',
#           'password' => 'postgres-password',
#           'database' => 'bosh',
#           'adapter' => 'postgres',
#
#         }
#       }
#     }
#   end
#
#   let(:postgres_upgrade_sh) { File.join(File.dirname(__FILE__), '../jobs/postgres/templates/postgres_upgrade.sh.erb') }
#
#   subject(:parsed_yaml) do
#     binding = Bosh::Template::EvaluationContext.new(deployment_manifest_fragment).get_binding
#     system(ERB.new(postgres_upgrade_sh).result(binding))
#   end
#
#   context 'given a generally valid manifest' do
#     it "should contain NATS's bare minimum" do
#       expect(parsed_yaml['net']).to eq('0.0.0.0')
#       expect(parsed_yaml['port']).to eq(4222)
#       expect(parsed_yaml['logtime']).to satisfy { |v| v == true || v == false }
#       expect(parsed_yaml['no_epoll']).to eq(false)
#       expect(parsed_yaml['no_kqueue']).to eq(false)
#       expect(parsed_yaml['ping']['interval']).to eq(5)
#       expect(parsed_yaml['ping']['max_outstanding']).to eq(10)
#       expect(parsed_yaml['pid_file']).to be_a(String)
#       expect(parsed_yaml['log_file']).to be_a(String)
#       expect(parsed_yaml['authorization']['user']).to eq('my-user')
#       expect(parsed_yaml['authorization']['password']).to eq('my-password')
#       expect(parsed_yaml['authorization']['timeout']).to eq(10)
#       expect(parsed_yaml.has_key?('http')).to eq(false)
#     end
#   end
# end
