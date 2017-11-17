require 'spec_helper'

module Bosh::Director
  describe PermissionAuthorizer do
    before do
      Bosh::Director::Models::DirectorAttribute.make(name: 'uuid', value: 'fake-director-uuid')
    end
    let(:config) { double(:config, :uuid => 'fake-director-uuid') }
    subject(:app) { Bosh::Director::PermissionAuthorizer.new(Api::DirectorUUIDProvider.new(config)) }

    describe '#is_granted?' do
      describe 'director subject' do
        let(:acl_subject) { :director }

        describe 'checking admin rights' do
          let(:acl_right) { :admin }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin',   # other director-specific admin scope
                  'bosh.teams.security.admin',    # team specific admins
                  'bosh.read',                    # read != admin
                  'bosh.fake-director-uuid.read', # other director-specific read != admin
                ])).to eq(false)
          end
        end

        describe 'checking read rights' do
          let(:acl_right) { :read }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows global read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.read'])).to eq(true)
          end

          it 'allows director-specific read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.read'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin', # other director-specific admin scope
                  'bosh.unexpected-uuid.read',  # other director-specific read != admin
                  'bosh.teams.security.admin',  # team specific admins
                ])).to eq(false)
          end
        end

        describe 'checking for create_deployment rights' do
          let(:acl_right) { :create_deployment }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows team admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.read', # denies global read scope
                  'bosh.fake-director-uuid.read', # denies director-specific read scope
                  'bosh.unexpected-uuid.admin', # other director-specific admin scope
                  'bosh.unexpected-uuid.read',  # other director-specific read != admin
                  'bosh.teams.security.read',  # team specific reads
                ])).to eq(false)
          end
        end

        shared_examples :admin_read_team_admin_scopes do
          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows global read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.read'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows director-specific read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.read'])).to eq(true)
          end

          it 'allows team admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin', # other director-specific admin scope
                  'bosh.unexpected-uuid.read',  # other director-specific read != admin
                  'bosh.teams.security.unexpected',  # abnormal team-specific scope
                ])).to eq(false)
          end
        end

        describe 'checking for read_releases rights' do
          let(:acl_right) { :read_releases }
          it_behaves_like :admin_read_team_admin_scopes
        end

        describe 'checking for list_deployments rights' do
          let(:acl_right) { :list_deployments }
          it_behaves_like :admin_read_team_admin_scopes
        end

        describe 'checking for read_stemcells rights' do
          let(:acl_right) { :read_stemcells }
          it_behaves_like :admin_read_team_admin_scopes
        end

        describe 'checking upload_releases rights' do
          let(:acl_right) { :upload_releases }
          it 'allows bosh.releases.upload scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.releases.upload'])).to eq(true)
          end

          it 'allows generic admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
              'bosh.read',
              'bosh.fake-director-uuid.read',
              'bosh.unexpected-uuid.admin',
              'bosh.teams.security.unexpected',
            ])).to eq(false)
          end
        end

        describe 'checking upload_stemcells rights' do
          let(:acl_right) { :upload_stemcells }
          it 'allows upload_stemcell scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.stemcells.upload'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
              'bosh.unexpected-uuid.admin',
              'bosh.unexpected-uuid.read',
              'bosh.teams.security.unexpected',
            ])).to eq(false)
          end
        end

        describe 'checking read_events rights' do
          let(:acl_right) { :read_events }
          it 'allows bosh.read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.read'])).to eq(true)
          end

          it 'allows bosh.teams.X.read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.anything.read'])).to eq(true)
          end

          it 'allows bosh.X.read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.read'])).to eq(true)
          end

          it 'allows bosh.admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows bosh.teams.X.admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.anything.admin'])).to eq(true)
          end

          it 'allows bosh.X.admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
              'bosh.unexpected-uuid.admin',
              'bosh.unexpected-uuid.read',
              'bosh.teams.security.unexpected',
            ])).to eq(false)
          end
        end

        describe 'checking for list_tasks rights' do
          let(:acl_right) { :list_tasks }
          it_behaves_like :admin_read_team_admin_scopes
        end

        describe 'checking for invalid rights' do
          let(:acl_right) { :what_I_fancy }

          it 'raises an exception' do
            expect{
              subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])
            }.to raise_error ArgumentError, "Unexpected permission for director: #{acl_right}"
          end
        end
      end

      describe 'task' do
        describe 'deployment-specific' do
          let(:teams) { [ Models::Team.make(name: 'security') ] }
          let(:acl_subject) {
            task = Models::Task.make(id: 1, deployment_name: 'test-deployment')
            task.teams = teams
            task
          }

          describe 'admin rights' do
            let(:acl_right) { :admin }

            it 'allows global scopes' do
              expect(subject.is_granted?(acl_subject, acl_right, [ 'bosh.admin' ])).to eq(true)
            end

            it 'allows director-specific scopes' do
              expect(subject.is_granted?(acl_subject, acl_right, [ 'bosh.fake-director-uuid.admin' ])).to eq(true)
            end

            it 'allows team scope' do
              expect(subject.is_granted?(acl_subject, acl_right, [ 'bosh.teams.security.admin' ])).to eq(true)
            end

            it 'denies others' do
              expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin',   # other director-specific admin scope
                  'bosh.teams.fraud.admin',       # unrelated team specific admins
                  'bosh.teams.security.haha',     # team specific unsupported scope
              ])).to eq(false)
            end
          end

          describe 'read rights' do
            let(:acl_right) { :read }

            it 'allows global admin scope' do
              expect(subject.is_granted?(acl_subject, acl_right, [ 'bosh.admin' ])).to eq(true)
            end

            it 'allows global read scope' do
              expect(subject.is_granted?(acl_subject, acl_right, [ 'bosh.read' ])).to eq(true)
            end

            it 'allows director-specific admin scope' do
              expect(subject.is_granted?(acl_subject, acl_right, [ 'bosh.fake-director-uuid.admin' ])).to eq(true)
            end

            it 'allows director-specific read scope' do
              expect(subject.is_granted?(acl_subject, acl_right, [ 'bosh.fake-director-uuid.read' ])).to eq(true)
            end

            it 'allows team scope' do
              expect(subject.is_granted?(acl_subject, acl_right, [ 'bosh.teams.security.admin' ])).to eq(true)
            end

            it 'denies others' do
              expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin',   # other director-specific admin scope
                  'bosh.teams.fraud.admin',       # unrelated team specific admins
                  'bosh.teams.security.haha',     # team specific unsupported scope
              ])).to eq(false)
            end
          end
        end
      end

      describe 'deployment' do
        let(:teams) { [ Models::Team.make(name: 'security'), Models::Team.make(name: 'bosh') ] }
        let(:acl_subject) do
          deployment = Models::Deployment.make(name: 'favorite')
          deployment.teams = teams
          deployment
        end

        describe 'checking admin rights' do
          let(:acl_right) { :admin }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows team admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.admin'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin',   # other director-specific admin scope
                  'bosh.teams.fraud.admin',       # unrelated team specific admins
                  'bosh.teams.security.read',     # team specific read
                  'bosh.read',                    # read != admin
                  'bosh.fake-director-uuid.read', # other director-specific read != admin
                ])).to eq(false)
          end
        end

        describe 'checking read rights' do
          let(:acl_right) { :read }

          it 'allows global admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])).to eq(true)
          end

          it 'allows director-specific admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.admin'])).to eq(true)
          end

          it 'allows global read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.read'])).to eq(true)
          end

          it 'allows director-specific read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.fake-director-uuid.read'])).to eq(true)
          end

          it 'allows team admin scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.admin'])).to eq(true)
          end

          it 'allows team read scope' do
            expect(subject.is_granted?(acl_subject, acl_right, ['bosh.teams.security.read'])).to eq(true)
          end

          it 'denies others' do
            expect(subject.is_granted?(acl_subject, acl_right, [
                  'bosh.unexpected-uuid.admin', # other director-specific admin scope
                  'bosh.unexpected-uuid.read',  # other director-specific read != admin
                  'bosh.teams.fraud.admin',     # unrelated team specific scope
                ])).to eq(false)
          end
        end

        describe 'checking for invalid rights' do
          let(:acl_right) { :what_I_fancy }

          it 'raises an exception' do
            expect{
              subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])
            }.to raise_error ArgumentError, "Unexpected permission for deployment: #{acl_right}"
          end
        end
      end

      describe 'unexpected subject' do
        let(:acl_subject) { :subject_I_fancy }
        let(:acl_right) { :read }

        it 'raises an exception' do
          expect{
            subject.is_granted?(acl_subject, acl_right, ['bosh.admin'])
          }.to raise_error ArgumentError, "Unexpected subject: #{acl_subject}"
        end
      end
    end
  end
end
