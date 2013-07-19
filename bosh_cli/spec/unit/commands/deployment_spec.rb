require 'spec_helper'

describe Bosh::Cli::Command::Deployment do

  let(:director) { double(Bosh::Cli::Director) }
  let(:cmd) { described_class.new(nil, director) }

  before do
    cmd.add_option(:non_interactive, true)
    cmd.add_option(:target, 'test')
    cmd.add_option(:username, 'user')
    cmd.add_option(:password, 'pass')
  end

  it 'allows deleting the deployment' do
    director
      .should_receive(:delete_deployment)
      .with('foo', force: false)

    cmd.delete('foo')
  end

  it 'needs confirmation to delete deployment' do
    director.should_not_receive(:delete_deployment)
    cmd.should_receive(:ask)

    cmd.remove_option(:non_interactive)
    cmd.delete('foo')
  end

  it 'lists deployments and does not fetch manifest on new director' do
    director
      .should_receive(:list_deployments).
      and_return([{ 'name' => 'foo', 'releases' => [], 'stemcells' => [] }])
    director
      .should_not_receive(:get_deployment)

    cmd.list
  end

  it 'lists deployments and fetches manifest on old director' do
    director
      .should_receive(:list_deployments)
      .and_return([{ 'name' => 'foo' }])

    director
      .should_receive(:get_deployment)
      .with('foo')
      .and_return({})

    cmd.list
  end

  describe 'updating the target' do
    before { cmd.stub(target: 'host', username: 'user', password: 'pass') }

    before do
      Bosh::Cli::Director
        .stub(:new)
        .with('host', 'user', 'pass')
        .and_return(director)
    end

    context 'when the director uuid is set to ignore' do
      let(:manifest) { {'director_uuid' => 'ignore'} }
      before { director.stub(:get_status) }

      it 'does not change the config target' do
        expect {
          cmd.update_target(manifest)
        }.not_to change { cmd.config.target }
      end
    end

    context 'when the director uuid is set to an actual uuid' do
      let(:manifest) { {'director_uuid' => 'r3a1-uu1d'} }

      context 'when the given uuid matches the old director uuid' do
        before { director.stub(get_status: {'uuid' => 'r3a1-uu1d'}) }

        it 'does not change the config target' do
          expect {
            cmd.update_target(manifest)
          }.not_to change { cmd.config.target }
        end
      end

      context 'when the given uuid is different from the old director uuid' do
        before { director.stub(get_status: {'uuid' => 'd1ff-r3nt'}) }

        context 'when the config can resolve the given uuid' do
          before do
            cmd.config
              .stub(:resolve_alias)
              .with(:target, 'r3a1-uu1d')
              .and_return('host')
          end

          it 'changes the config target' do
            expect {
              cmd.update_target(manifest)
            }.to change { cmd.config.target }.to('host')
          end
        end

        context 'when the config cannot resolve the given uuid' do
          it 'warns the user that it does not recognize the uuid' do
            expect {
              cmd.update_target(manifest)
            }.to raise_error(/This manifest references director with UUID/i)
          end

          it 'does not change the config target' do
            expect {
              cmd.update_target(manifest) rescue nil
            }.not_to change { cmd.config.target }
          end
        end
      end
    end
  end
end
