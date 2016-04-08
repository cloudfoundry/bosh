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

      describe 'deployment' do
        let(:acl_subject) { Models::Deployment.make(name: 'favorite', teams: 'security') }

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
