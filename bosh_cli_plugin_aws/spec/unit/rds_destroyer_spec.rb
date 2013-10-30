require 'spec_helper'

module Bosh::Aws
  describe RdsDestroyer do
    subject(:rds_destroyer) { Bosh::Aws::RdsDestroyer.new(ui, config) }
    let(:ui) { instance_double('Bosh::Cli::Command::AWS') }
    let(:config) { { 'aws' => { fake: 'aws config' } } }

    before { rds_destroyer.stub(:sleep) }

    describe '#delete_all' do
      before { Bosh::Aws::EC2.stub(:new).with(fake: 'aws config').and_return(ec2) }
      let(:ec2) { instance_double('Bosh::Aws::EC2') }

      before { Bosh::Aws::RDS.stub(:new).and_return(rds) }
      let(:rds) { instance_double('Bosh::Aws::RDS') }

      context 'when there is at least 1 database' do
        before { rds.stub(databases: [], database_names: { 'i1' => 'db1-name', 'i2' => 'db2-name' }) }

        it 'warns the user that the operation is destructive and list the databases' do
          ui.should_receive(:say).with(/DESTRUCTIVE OPERATION/)
          ui.should_receive(:say).with("Database Instances:\n\ti1\t(database_name: db1-name)\n\ti2\t(database_name: db2-name)")

          ui
            .should_receive(:confirmed?)
            .with('Are you sure you want to delete all databases?')
            .and_return(false)

          rds_destroyer.delete_all
        end

        context 'when user confirms deletion' do
          before { ui.stub(confirmed?: true) }

          it 'deletes all databases and associated resources' do
            rds.should_receive(:delete_databases)
            rds.should_receive(:delete_subnet_groups)
            rds.should_receive(:delete_security_groups)
            rds.should_receive(:delete_db_parameter_group).with('utf8')
            rds_destroyer.delete_all
          end

          context 'when not all database instances could be deleted' do
            let(:bosh_rds) { double('instance1', db_name: 'bosh_db', endpoint_port: 1234, db_instance_status: :irrelevant) }

            before { ignore_deletion }

            context 'when databases do not go away after few tries' do
              it 'raises an error' do
                rds.stub(databases: [bosh_rds])
                expect {
                  rds_destroyer.delete_all
                }.to raise_error(/not all rds instances could be deleted/)
              end
            end

            context 'when database goes away while printing status' do
              it 'succeeds eventually' do
                rds.should_receive(:databases).and_return([bosh_rds], [bosh_rds], [])
                bosh_rds.should_receive(:db_name).and_raise(::AWS::RDS::Errors::DBInstanceNotFound)
                rds_destroyer.delete_all
              end
            end
          end
        end

        context 'when does not confirm deletion' do
          before { ui.stub(confirmed?: false) }

          it 'does not terminate any databases' do
            rds.should_not_receive(:delete_databases)
            rds.should_not_receive(:delete_subnet_groups)
            rds.should_not_receive(:delete_security_groups)
            rds.should_not_receive(:delete_db_parameter_group)
            rds_destroyer.delete_all
          end
        end
      end

      context 'when there are no databases' do
        before { rds.stub(database_names: [], databases: []) }

        before { ignore_deletion }

        context 'wehn user confirmed deletion' do
          before { ui.stub(confirmed?: true) }

          it 'does not try to delete databases' do
            rds.should_not_receive(:delete_databases)
            rds_destroyer.delete_all
          end

          it 'deletes db subnets, sec groups, and paramater groups' do
            rds.should_receive(:delete_subnet_groups)
            rds.should_receive(:delete_security_groups)
            rds.should_receive(:delete_db_parameter_group)
            rds_destroyer.delete_all
          end
        end

        context 'wehn user did not confirme deletion' do
          before { ui.stub(confirmed?: false) }

          it 'does not try to delete databases' do
            rds.should_not_receive(:delete_databases)
            rds_destroyer.delete_all
          end

          it 'does not delete db subnets, sec groups, and paramater groups' do
            rds.should_not_receive(:delete_subnet_groups)
            rds.should_not_receive(:delete_security_groups)
            rds.should_not_receive(:delete_db_parameter_group)
            rds_destroyer.delete_all
          end
        end
      end

      def ignore_deletion
        rds.stub(:delete_databases)
        rds.stub(:delete_subnet_groups)
        rds.stub(:delete_security_groups)
        rds.stub(:delete_db_parameter_group)
      end
    end
  end
end
