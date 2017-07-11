require 'spec_helper'

module Bosh::Director
  describe Api::RevisionManager do
    let(:task) { '1' }
    let(:username) { 'FAKE_USER' }

    describe '#create_revision' do
      it 'creates consecutive revision_numbers per deployment in event.object_name' do
        expect(create_test_revision("deployment-A").object_name).to eq '1'
        expect(create_test_revision("deployment-B").object_name).to eq '1'
        expect(create_test_revision("deployment-A").object_name).to eq '2'
        expect(create_test_revision("deployment-B").object_name).to eq '2'
        expect(create_test_revision("deployment-B").object_name).to eq '3'
        expect(create_test_revision("deployment-A").object_name).to eq '3'
      end
    end

    describe '#revisions' do
      let!(:event) {
        create_test_revision('my-deployment', manifest_text: 'test-key: test-value')
      }

      it 'can return a previously created revision' do
        expect(subject.revisions('my-deployment')).to eq([
          {
            deployment_name:"my-deployment",
            revision_number: 1,
            user: username,
            task: task,
            started_at: event.context['started_at'],
            completed_at: event.timestamp,
            error: nil,
          }
        ])
      end

      it 'can return a previously created revision including manifest if specified' do
        expect(subject.revisions('my-deployment', include_manifest: true)).to eq([
          {
            deployment_name:"my-deployment",
            revision_number: 1,
            user: username,
            task: task,
            started_at: event.context['started_at'],
            completed_at: event.timestamp,
            manifest_text: 'test-key: test-value',
            error: nil,
          }
        ])
      end

      it 'only returns deployment_revision object_types as revision' do
        Models::Event.create(
          timestamp:   Time.now,
          user:        "user",
          action:      "create",
          object_type: "some-other-object-type",
          deployment:  "my-deployment",
        )

        expect(subject.revisions('my-deployment')).to eq([
          {
            deployment_name:"my-deployment",
            revision_number: 1,
            user: username,
            task: task,
            started_at: event.context['started_at'],
            completed_at: event.timestamp,
            error: nil,
          }
        ])
      end
    end

    describe '#revision' do
      let!(:event) {
        create_test_revision('my-deployment', manifest_text: 'test-key: test-value')
      }

      it 'returns a previously created revison' do
        expect(subject.revision('my-deployment', event.object_name)).to eq(
          {
            deployment_name:"my-deployment",
            revision_number: 1,
            user: username,
            task: task,
            started_at: event.context['started_at'],
            completed_at: event.timestamp,
            manifest_text: 'test-key: test-value',
            runtime_configs: [],
            stemcells: [],
            releases: [],
            error: nil,
          }
        )
      end
    end

    describe '#diff' do
      before do
        create_test_revision("deployment-A",
          manifest_text: {
            'releases' => [
              {'name' => 'A', 'version' => '2'},
              {'name' => 'B', 'version' => '1'}
            ]
          }.to_yaml,
          releases: ['A/1', 'A/2', 'B/1'])
        create_test_revision("deployment-A",
          manifest_text: {
            'releases' => [
              {'name' => 'A', 'version' => 'latest'},
              {'name' => 'B', 'version' => '2'}
            ]
          }.to_yaml,
          releases: ['A/1', 'A/2', 'A/3', 'B/2'])
      end

      it 'returns a diff between the manifests' do
        expect(subject.diff("deployment-A", 1, 2, should_redact: false)[:manifest]).to eq(
          [
            ["releases:", nil],
            ["- name: A", nil],
            ["  version: '2'", "removed"],
            ["  version: latest", "added"],
            ["- name: B", nil],
            ["  version: '1'", "removed"],
            ["  version: '2'", "added"]
          ]
        )
      end

      it 'returns releases added and removed, resolving "latest" to concrete version number' do
        expect(subject.diff("deployment-A", 1, 2, should_redact: false)[:releases]).to eq(
          {:added=>["A/3", "B/2"], :removed=>["A/2", "B/1"]}
        )
      end
    end
  end
end

def create_test_revision(deployment_name, manifest_text: 'key: value', releases: [])
  subject.create_revision(
    deployment_name: deployment_name,
    user: username,
    task: task,
    started_at: Time.now,
    manifest_text: manifest_text,
    cloud_config_id: nil,
    runtime_config_ids: [],
    releases: releases,
    stemcells: [],
  )
end

