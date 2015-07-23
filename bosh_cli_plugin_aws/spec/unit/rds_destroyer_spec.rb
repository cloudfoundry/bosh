require 'spec_helper'

module Bosh::AwsCliPlugin
  describe RdsDestroyer do
    subject(:rds_destroyer) { Bosh::AwsCliPlugin::RdsDestroyer.new(ui, config) }
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }
    let(:config) { { 'aws' => { fake: 'aws config' } } }

    before { allow(rds_destroyer).to receive(:sleep) }

    describe '#delete_all' do
      before { allow(Bosh::AwsCliPlugin::EC2).to receive(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::AwsCliPlugin::EC2') }

      before { allow(Bosh::AwsCliPlugin::RDS).to receive(:new).and_return(rds) }
      let(:rds) { instance_double('Bosh::AwsCliPlugin::RDS') }

      context 'when there is at least 1 database' do
        before { allow(rds).to receive_messages(databases: [], database_names: { 'i1' => 'db1-name', 'i2' => 'db2-name' }) }

        it 'warns the user that the operation is destructive and list the databases' do
          expect(ui).to receive(:say).with(/DESTRUCTIVE OPERATION/)
          expect(ui).to receive(:say).with("Database Instances:\n\ti1\t(database_name: db1-name)\n\ti2\t(database_name: db2-name)")

          expect(ui)
            .to receive(:confirmed?)
            .with('Are you sure you want to delete all databases?')
            .and_return(false)

          rds_destroyer.delete_all
        end

        context 'when user confirms deletion' do
          before { allow(ui).to receive_messages(confirmed?: true) }

          it 'deletes all databases and associated resources' do
            expect(rds).to receive(:delete_databases)
            expect(rds).to receive(:delete_subnet_groups)
            expect(rds).to receive(:delete_security_groups)
            expect(rds).to receive(:delete_db_parameter_group).with('utf8')
            rds_destroyer.delete_all
          end

          context 'when not all database instances could be deleted' do
            let(:bosh_rds) { double('instance1', db_name: 'bosh_db', endpoint_port: 1234, db_instance_status: :irrelevant) }

            before { ignore_deletion }

            context 'when databases do not go away after few tries' do
              it 'raises an error' do
                allow(rds).to receive_messages(databases: [bosh_rds])
                expect {
                  rds_destroyer.delete_all
                }.to raise_error(/not all rds instances could be deleted/)
              end
            end

            context 'when database goes away while printing status' do
              it 'succeeds eventually' do
                expect(rds).to receive(:databases).and_return([bosh_rds], [bosh_rds], [])
                expect(bosh_rds).to receive(:db_name).and_raise(::AWS::RDS::Errors::DBInstanceNotFound)
                rds_destroyer.delete_all
              end
            end
          end
        end

        context 'when does not confirm deletion' do
          before { allow(ui).to receive_messages(confirmed?: false) }

          it 'does not terminate any databases' do
            expect(rds).not_to receive(:delete_databases)
            expect(rds).not_to receive(:delete_subnet_groups)
            expect(rds).not_to receive(:delete_security_groups)
            expect(rds).not_to receive(:delete_db_parameter_group)
            rds_destroyer.delete_all
          end
        end
      end

      context 'when there are no databases' do
        before { allow(rds).to receive_messages(database_names: [], databases: []) }

        before { ignore_deletion }

        context 'wehn user confirmed deletion' do
          before { allow(ui).to receive_messages(confirmed?: true) }

          it 'does not try to delete databases' do
            expect(rds).not_to receive(:delete_databases)
            rds_destroyer.delete_all
          end

          it 'deletes db subnets, sec groups, and paramater groups' do
            expect(rds).to receive(:delete_subnet_groups)
            expect(rds).to receive(:delete_security_groups)
            expect(rds).to receive(:delete_db_parameter_group)
            rds_destroyer.delete_all
          end
        end

        context 'wehn user did not confirme deletion' do
          before { allow(ui).to receive_messages(confirmed?: false) }

          it 'does not try to delete databases' do
            expect(rds).not_to receive(:delete_databases)
            rds_destroyer.delete_all
          end

          it 'does not delete db subnets, sec groups, and paramater groups' do
            expect(rds).not_to receive(:delete_subnet_groups)
            expect(rds).not_to receive(:delete_security_groups)
            expect(rds).not_to receive(:delete_db_parameter_group)
            rds_destroyer.delete_all
          end
        end
      end

      def ignore_deletion
        allow(rds).to receive(:delete_databases)
        allow(rds).to receive(:delete_subnet_groups)
        allow(rds).to receive(:delete_security_groups)
        allow(rds).to receive(:delete_db_parameter_group)
      end
    end
  end
end
