require 'spec_helper'

describe 'ignore/unignore instance', type: :integration do
  with_reset_sandbox_before_each

  def safe_include(value, substring, defaults_to = false)
    if value.nil?
      defaults_to
    else
      value.include? substring
    end
  end

  it 'changes the ignore value of vms correctly' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    director.vms.each do |vm|
      expect(vm.ignore).to eq('false')
    end

    initial_vms = director.vms
    vm1 = initial_vms[0]
    vm2 = initial_vms[1]
    vm3 = initial_vms[2]

    bosh_runner.run("ignore instance #{vm1.job_name}/#{vm1.instance_uuid}")
    bosh_runner.run("ignore instance #{vm2.job_name}/#{vm2.instance_uuid}")
    expect(director.vm(vm1.job_name, vm1.instance_uuid).ignore).to eq('true')
    expect(director.vm(vm2.job_name, vm2.instance_uuid).ignore).to eq('true')
    expect(director.vm(vm3.job_name, vm3.instance_uuid).ignore).to eq('false')

    bosh_runner.run("unignore instance #{vm2.job_name}/#{vm2.instance_uuid}")
    expect(director.vm(vm1.job_name, vm1.instance_uuid).ignore).to eq('true')
    expect(director.vm(vm2.job_name, vm2.instance_uuid).ignore).to eq('false')
    expect(director.vm(vm3.job_name, vm3.instance_uuid).ignore).to eq('false')
  end

  context 'when there are ignored instances and a deploy happens' do

    context 'when the number of instance groups did not change between deployments' do
      it 'leaves ignored instances alone when instance group count is 1' do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest
        cloud_config = Bosh::Spec::Deployments.simple_cloud_config

        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar1', :instances => 1})
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar3', :instances => 1})

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        event_list_1 = director.raw_task_events('last')
        expect(event_list_1.select do |e|
          safe_include(e['stage'], 'Updating job') &&
          safe_include(e['state'], 'started')
        end.count).to eq(3)

        # ignore first VM
        initial_vms = director.vms
        foobar1_vm1 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}.first

        bosh_runner.run("ignore instance #{foobar1_vm1.job_name}/#{foobar1_vm1.instance_uuid}")

        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
            name: 'foobar1',
            templates: [
                {'name' => 'job_1_with_pre_start_script'},
                {'name' => 'job_2_with_pre_start_script'}
            ],
            instances: 1)
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar3', :instances => 1})

        deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        event_list_2 = director.raw_task_events('last')
        expect(
            event_list_2.none? do |e|
              safe_include(e['stage'], 'Updating job') &&
              safe_include(e['task'], foobar1_vm1.instance_uuid)
            end
        ).to eq(true)

        expect(
            event_list_2.select { |e|
              safe_include(e['stage'], 'Updating job') &&
              safe_include(e['state'], 'started') &&
              (
                safe_include(e['tags'], 'foobar1') ||
                safe_include(e['tags'], 'foobar2') ||
                safe_include(e['tags'], 'foobar3')
              )
            }.count
        ).to eq(0)
      end


      it 'leaves ignored instances alone when count of the instance groups is larger than 1' do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest
        cloud_config = Bosh::Spec::Deployments.simple_cloud_config

        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar1', :instances => 3})
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 3})

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        before_event_list = director.raw_task_events('last')
        expect(before_event_list.select { |e| e['stage'] == 'Updating job' && e['state'] == 'started' }.count).to eq(6)

        # ignore first VM
        initial_vms = director.vms
        vm1 = initial_vms[0]
        bosh_runner.run("ignore instance #{vm1.job_name}/#{vm1.instance_uuid}")

        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
            name: 'foobar1',
            templates: [
                {'name' => 'job_1_with_pre_start_script'},
                {'name' => 'job_2_with_pre_start_script'}
            ],
            instances: 3)
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 3})

        deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        after_event_list = director.raw_task_events('last')
        expect(
            after_event_list.none? do |e|
              (e['stage'] == 'Updating job') && (safe_include(e['task'], vm1.instance_uuid))
            end
        ).to eq(true)

        expect(
            after_event_list.select { |e|
              (e['stage'] == 'Updating job') && (e['state'] == 'started') && (safe_include(e['tags'], 'foobar1'))
            }.count
        ).to eq(2)
      end
    end

    context 'when the existing instances is less than the desired ones' do

      it 'should handle ignored instances' do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest
        cloud_config = Bosh::Spec::Deployments.simple_cloud_config

        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar1', :instances => 1})
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        event_list_1 = director.raw_task_events('last')
        expect(event_list_1.select { |e| e['stage'] == 'Updating job' && e['state'] == 'started' }.count).to eq(2)

        # ignore first VM
        initial_vms = director.vms
        foobar1_vm1 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}.first
        foobar2_vm1 = initial_vms.select{ |vm| vm.job_name == 'foobar2'}.first
        bosh_runner.run("ignore instance #{foobar1_vm1.job_name}/#{foobar1_vm1.instance_uuid}")

        # redelpoy with different foobar1 templates
        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
            name: 'foobar1',
            templates: [ {'name' => 'job_1_with_pre_start_script'} ],
            instances: 2)
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})

        deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        event_list_2 = director.raw_task_events('last')
        expect(
            event_list_2.none? do |e|
              (e['stage'] == 'Updating job') && (safe_include(e['task'], foobar1_vm1.instance_uuid))
            end
        ).to eq(true)

        expect(
            event_list_2.select { |e|
              (e['stage'] == 'Creating missing vms') && (e['state'] == 'started')
            }.count
        ).to eq(1)

        expect(
            event_list_2.select { |e|
              (e['stage'] == 'Updating job') && (e['state'] == 'started') && (safe_include(e['tags'], 'foobar1'))
            }.count
        ).to eq(1)

        # ======================================================
        # switch ignored instances

        bosh_runner.run("unignore instance #{foobar1_vm1.job_name}/#{foobar1_vm1.instance_uuid}")
        bosh_runner.run("ignore instance #{foobar2_vm1.job_name}/#{foobar2_vm1.instance_uuid}")

        # Redeploy with different numbers
        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
            name: 'foobar1',
            templates: [ {'name' => 'job_2_with_pre_start_script'} ],
            instances: 4)
        manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
            name: 'foobar2',
            templates: [ {'name' => 'job_1_with_pre_start_script'} ],
            instances: 3)

        deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        event_list_3 = director.raw_task_events('last')

        expect(
            event_list_3.select { |e|
              (e['stage'] == 'Creating missing vms') && (e['state'] == 'started') && (safe_include(e['task'], 'foobar1'))
            }.count
        ).to eq(2)

        expect(
            event_list_3.select { |e|
              (e['stage'] == 'Creating missing vms') && (e['state'] == 'started') && (safe_include(e['task'], 'foobar2'))
            }.count
        ).to eq(2)

        expect(
            event_list_3.select { |e|
              (e['stage'] == 'Updating job') && (e['state'] == 'started') && (safe_include(e['tags'], 'foobar1'))
            }.count
        ).to eq(4)

        expect(
            event_list_3.select { |e|
              (e['stage'] == 'Updating job') && (e['state'] == 'started') && (safe_include(e['tags'], 'foobar2'))
            }.count
        ).to eq(2)

        expect(
            event_list_3.select { |e|
              (e['stage'] == 'Updating job') &&
              (e['state'] == 'started') &&
              (safe_include(e['tags'], 'foobar1')) &&
              (safe_include(e['task'], foobar1_vm1.instance_uuid))
            }.count
        ).to eq(1)

        expect(
            event_list_3.none? do |e|
              (e['stage'] == 'Updating job') && (safe_include(e['task'], foobar2_vm1.instance_uuid))
            end
        ).to eq(true)

      end

    end

    context 'when the existing instances is larger than the desired ones' do

      context 'when the ignored instances is larger than the desired ones' do
        it "should fail to deploy" do
          manifest_hash = Bosh::Spec::Deployments.simple_manifest
          cloud_config = Bosh::Spec::Deployments.simple_cloud_config

          manifest_hash['jobs'].clear
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar1', :instances => 4})
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})

          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
          event_list_1 = director.raw_task_events('last')
          expect(event_list_1.select { |e| e['stage'] == 'Updating job' && e['state'] == 'started' }.count).to eq(5)

          # ignore first VM
          initial_vms = director.vms

          foobar1_vm1 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[0]
          foobar1_vm2 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[1]
          foobar1_vm3 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[2]

          bosh_runner.run("ignore instance #{foobar1_vm1.job_name}/#{foobar1_vm1.instance_uuid}")
          bosh_runner.run("ignore instance #{foobar1_vm2.job_name}/#{foobar1_vm2.instance_uuid}")
          bosh_runner.run("ignore instance #{foobar1_vm3.job_name}/#{foobar1_vm3.instance_uuid}")

          # redeploy with different foobar1 templates
          manifest_hash['jobs'].clear
          manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
              name: 'foobar1',
              templates: [ {'name' => 'job_1_with_pre_start_script'} ],
              instances: 2
          )
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})

          output, exit_code = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)

          expect(exit_code).to_not eq(0)
          expect(output).to include("Error 190020: Instance Group 'foobar1' has 3 ignored instances.You requested to have 2 instances of that instance group. Deleting ignored instances is not allowed.")
        end
      end

      context 'when the ignored instances is equal to desired ones' do
        it 'deletes all non-ignored vms and leaves the ignored alone without updating them' do
          manifest_hash = Bosh::Spec::Deployments.simple_manifest
          cloud_config = Bosh::Spec::Deployments.simple_cloud_config

          manifest_hash['jobs'].clear
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar1', :instances => 4})
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})

          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
          event_list_1 = director.raw_task_events('last')
          expect(event_list_1.select { |e| e['stage'] == 'Updating job' && e['state'] == 'started' }.count).to eq(5)

          initial_vms = director.vms

          foobar1_vm1 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[0]
          foobar1_vm2 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[1]
          foobar1_vm3 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[2]
          foobar1_vm4 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[3]

          bosh_runner.run("ignore instance #{foobar1_vm1.job_name}/#{foobar1_vm1.instance_uuid}")
          bosh_runner.run("ignore instance #{foobar1_vm2.job_name}/#{foobar1_vm2.instance_uuid}")

          # ===================================================
          # redeploy with different foobar1 templates
          manifest_hash['jobs'].clear
          manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
              name: 'foobar1',
              templates: [ {'name' => 'job_1_with_pre_start_script'} ],
              instances: 2
          )
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})

          output = deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
          expect(output).to include("Started deleting unneeded instances foobar1 > foobar1/2 (#{foobar1_vm3.instance_uuid}). Done")
          expect(output).to include("Started deleting unneeded instances foobar1 > foobar1/3 (#{foobar1_vm4.instance_uuid}). Done")

          event_list_2 = director.raw_task_events('last')
          expect(event_list_2.none? {|e| (e['stage'] == 'Updating job')}).to eq(true)
          expect(event_list_2.none? {|e| (e['stage'] == 'Creating missing vms')}).to eq(true)

          expect(
              event_list_2.select { |e|
                (e['stage'] == 'Deleting unneeded instances') && (e['state'] == 'started')
              }.count
          ).to eq(2)

          expect(director.vm(foobar1_vm1.job_name, foobar1_vm1.instance_uuid).ignore).to eq('true')
          expect(director.vm(foobar1_vm1.job_name, foobar1_vm1.instance_uuid).last_known_state).to eq('running')
          expect(director.vm(foobar1_vm2.job_name, foobar1_vm2.instance_uuid).ignore).to eq('true')
          expect(director.vm(foobar1_vm2.job_name, foobar1_vm2.instance_uuid).last_known_state).to eq('running')
        end
      end

      context 'when the ignored instances is less than the desired ones' do

        it 'should keep the ignored instances untouched and adjust the number of remaining functional instances' do
          manifest_hash = Bosh::Spec::Deployments.simple_manifest
          cloud_config = Bosh::Spec::Deployments.simple_cloud_config

          manifest_hash['jobs'].clear
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar1', :instances => 5})
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})

          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
          event_list_1 = director.raw_task_events('last')
          expect(event_list_1.select { |e| e['stage'] == 'Updating job' && e['state'] == 'started' }.count).to eq(6)

          initial_vms = director.vms
          foobar1_vm1 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[0]
          foobar1_vm2 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[1]

          bosh_runner.run("ignore instance #{foobar1_vm1.job_name}/#{foobar1_vm1.instance_uuid}")
          bosh_runner.run("ignore instance #{foobar1_vm2.job_name}/#{foobar1_vm2.instance_uuid}")

          # ===================================================
          # redeploy with different foobar1 templates
          manifest_hash['jobs'].clear
          manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
              name: 'foobar1',
              templates: [ {'name' => 'job_1_with_pre_start_script'} ],
              instances: 3
          )
          manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})

          deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

          event_list_2 = director.raw_task_events('last')

          expect(
              event_list_2.select { |e|
                (e['stage'] == 'Deleting unneeded instances') &&
                (e['state'] == 'started') &&
                (safe_include(e['tags'], 'foobar1'))
              }.count
          ).to eq(2)

          expect(
              event_list_2.select { |e|
                (e['stage'] == 'Deleting unneeded instances') &&
                    (e['state'] == 'started')
              }.count
          ).to eq(2)

          expect(
              event_list_2.select { |e|
                (e['stage'] == 'Updating job') &&
                (e['state'] == 'started') &&
                (safe_include(e['tags'], 'foobar1'))
              }.count
          ).to eq(1)

          expect(
              event_list_2.select { |e|
                (e['stage'] == 'Updating job') &&
                (e['state'] == 'started')
              }.count
          ).to eq(1)

          expect(
              event_list_2.none? do |e|
                (safe_include(e['task'], foobar1_vm1.instance_uuid)) ||
                (safe_include(e['task'], foobar1_vm2.instance_uuid))
              end
          ).to eq(true)

          modified_vms = director.vms

          expect(modified_vms.count).to eq(4)

          expect(modified_vms.select{ |vm| vm.ignore == 'true' }.count).to eq(2)
          expect(modified_vms.select{ |vm| vm.ignore == 'true' && vm.job_name == 'foobar1' }.count).to eq(2)
          expect(modified_vms.select{ |vm| vm.job_name == 'foobar1' }.count).to eq(3)
          expect(modified_vms.select{ |vm| vm.job_name == 'foobar2' }.count).to eq(1)
          expect(modified_vms.select{ |vm| vm.instance_uuid == foobar1_vm1.instance_uuid }.count).to eq(1)
          expect(modified_vms.select{ |vm| vm.instance_uuid == foobar1_vm2.instance_uuid }.count).to eq(1)
        end
      end
    end

    context 'when --recreate flag is passed' do
      it 'should recreate needed vms but leave the ignored ones alone' do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest
        cloud_config = Bosh::Spec::Deployments.simple_cloud_config

        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar1', :instances => 3})
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 3})

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        # ignore first VM
        initial_vms = director.vms
        foobar1_vm1 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[0]
        foobar1_vm2 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[1]
        foobar1_vm3 = initial_vms.select{ |vm| vm.job_name == 'foobar1'}[2]

        foobar2_vm1 = initial_vms.select{ |vm| vm.job_name == 'foobar2'}[0]
        foobar2_vm2 = initial_vms.select{ |vm| vm.job_name == 'foobar2'}[1]
        foobar2_vm3 = initial_vms.select{ |vm| vm.job_name == 'foobar2'}[2]

        bosh_runner.run("ignore instance #{foobar1_vm1.job_name}/#{foobar1_vm1.instance_uuid}")

        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.job_with_many_templates(
            name: 'foobar1',
            templates: [
                {'name' => 'job_1_with_pre_start_script'},
                {'name' => 'job_2_with_pre_start_script'}
            ],
            instances: 3)
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 3})

        deploy_simple_manifest(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, recreate: true)

        after_event_list = director.raw_task_events('last')

        modified_vms = director.vms

        expect(
            after_event_list.none? do |e|
              (e['stage'] == 'Updating job') && (safe_include(e['task'], foobar1_vm1.instance_uuid))
            end
        ).to eq(true)

        expect(
            after_event_list.select { |e|
              (e['stage'] == 'Updating job') && (e['state'] == 'started') && (safe_include(e['tags'], 'foobar1'))
            }.count
        ).to eq(2)

        expect(
            modified_vms.none? do |vm|
              vm.agent_id == foobar1_vm2.agent_id ||
              vm.agent_id == foobar1_vm3.agent_id ||
              vm.agent_id == foobar2_vm1.agent_id ||
              vm.agent_id == foobar2_vm2.agent_id ||
              vm.agent_id == foobar2_vm3.agent_id
            end
        ).to eq(true)

        expect(
            modified_vms.select { |vm|
              vm.agent_id == foobar1_vm1.agent_id
            }.count
        ).to eq(1)
      end
    end
  end

  context 'when starting/stoping/restarting/recreating instances' do

    context 'when not specifying an instance group name' do
      it 'should change the state of all instances except the ignored ones' do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest
        cloud_config = Bosh::Spec::Deployments.simple_cloud_config

        manifest_hash['jobs'].clear
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar1', :instances => 3})
        manifest_hash['jobs'] << Bosh::Spec::Deployments.simple_job({:name => 'foobar2', :instances => 1})

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

        vms_first_state = director.vms
        ignored_vm = vms_first_state[0]
        foobar1_vm_2 = vms_first_state[1]
        foobar1_vm_3 = vms_first_state[2]
        foobar2_vm_1 = vms_first_state[3]

        bosh_runner.run("ignore instance #{ignored_vm.job_name}/#{ignored_vm.instance_uuid}")

        # ===========================================
        # TODO: make sure no jobs are started when all are already started
        start_output = bosh_runner.run("start")
        expect(start_output).to include('Warning: You have ignored instances. No changes will be reflected on them.')
        expect(start_output).to_not include('Started updating job foobar1 > foobar1/0')

        # ===========================================
        stop_output = bosh_runner.run("stop")
        expect(stop_output).to include('Warning: You have ignored instances. No changes will be reflected on them.')
        expect(stop_output).to_not include('Started updating job foobar1 > foobar1/0')
        expect(stop_output).to include('Started updating job foobar1 > foobar1/1')
        expect(stop_output).to include('Started updating job foobar1 > foobar1/2')
        expect(stop_output).to include('Started updating job foobar2 > foobar2/0')

        vms_after_stop = director.vms
        expect(vms_after_stop[0].last_known_state).to eq('running')
        expect(vms_after_stop[1].last_known_state).to eq('stopped')
        expect(vms_after_stop[2].last_known_state).to eq('stopped')
        expect(vms_after_stop[3].last_known_state).to eq('stopped')


        # ===========================================
        restart_output = bosh_runner.run("restart")
        expect(restart_output).to include('Warning: You have ignored instances. No changes will be reflected on them.')
        expect(restart_output).to_not include('Started updating job foobar1 > foobar1/0')
        expect(restart_output).to include('Started updating job foobar1 > foobar1/1')
        expect(restart_output).to include('Started updating job foobar1 > foobar1/2')
        expect(restart_output).to include('Started updating job foobar2 > foobar2/0')

        vms_after_restart = director.vms
        expect(vms_after_restart[0].last_known_state).to eq('running')
        expect(vms_after_restart[1].last_known_state).to eq('running')
        expect(vms_after_restart[2].last_known_state).to eq('running')
        expect(vms_after_restart[3].last_known_state).to eq('running')


        # ===========================================
        recreate_output = bosh_runner.run("recreate")
        expect(recreate_output).to include('Warning: You have ignored instances. No changes will be reflected on them.')
        expect(recreate_output).to_not include('Started updating job foobar1 > foobar1/0')
        expect(recreate_output).to include('Started updating job foobar1 > foobar1/1')
        expect(recreate_output).to include('Started updating job foobar1 > foobar1/2')
        expect(recreate_output).to include('Started updating job foobar2 > foobar2/0')

        vms_after_recreate = director.vms
        expect(vms_after_recreate[0].last_known_state).to eq('running')
        expect(vms_after_recreate[1].last_known_state).to eq('running')
        expect(vms_after_recreate[2].last_known_state).to eq('running')
        expect(vms_after_recreate[3].last_known_state).to eq('running')

        expect(vms_after_recreate[0].agent_id).to eq(ignored_vm.agent_id)
        expect(vms_after_recreate[1].agent_id).to_not eq(foobar1_vm_2.agent_id)
        expect(vms_after_recreate[2].agent_id).to_not eq(foobar1_vm_3.agent_id)
        expect(vms_after_recreate[3].agent_id).to_not eq(foobar2_vm_1.agent_id)

        # ========================================================================================
        # Targeting and instance group
        # ========================================================================================

        stop_output = bosh_runner.run("stop foobar1")
        expect(stop_output).to include('Warning: You have ignored instances. No changes will be reflected on them.')
        expect(stop_output).to_not include('Started updating job foobar1 > foobar1/0')
        expect(stop_output).to include('Started updating job foobar1 > foobar1/1')
        expect(stop_output).to include('Started updating job foobar1 > foobar1/2')
        expect(stop_output).to_not include('Started updating job foobar2 > foobar2/0')

        vms_after_stop = director.vms
        expect(vms_after_stop[0].last_known_state).to eq('running')
        expect(vms_after_stop[1].last_known_state).to eq('stopped')
        expect(vms_after_stop[2].last_known_state).to eq('stopped')
        expect(vms_after_stop[3].last_known_state).to eq('running')

        # ===========================================
        start_output = bosh_runner.run("start foobar1")
        expect(start_output).to include('Warning: You have ignored instances. No changes will be reflected on them.')
        expect(start_output).to_not include('Started updating job foobar1 > foobar1/0')
        expect(start_output).to include('Started updating job foobar1 > foobar1/1')
        expect(start_output).to include('Started updating job foobar1 > foobar1/2')
        expect(start_output).to_not include('Started updating job foobar2 > foobar2/0')

        vms_after_start = director.vms
        expect(vms_after_start[0].last_known_state).to eq('running')
        expect(vms_after_start[1].last_known_state).to eq('running')
        expect(vms_after_start[2].last_known_state).to eq('running')
        expect(vms_after_start[3].last_known_state).to eq('running')

        # ===========================================
        restart_output = bosh_runner.run("restart foobar1")
        expect(restart_output).to include('Warning: You have ignored instances. No changes will be reflected on them.')
        expect(restart_output).to_not include('Started updating job foobar1 > foobar1/0')
        expect(restart_output).to include('Started updating job foobar1 > foobar1/1')
        expect(restart_output).to include('Started updating job foobar1 > foobar1/2')
        expect(restart_output).to_not include('Started updating job foobar2 > foobar2/0')

        vms_after_restart = director.vms
        foobar1_vm_2 = vms_after_restart[1]
        foobar1_vm_3 = vms_after_restart[2]
        foobar2_vm_1 = vms_after_restart[3]

        expect(vms_after_restart[0].last_known_state).to eq('running')
        expect(vms_after_restart[1].last_known_state).to eq('running')
        expect(vms_after_restart[2].last_known_state).to eq('running')
        expect(vms_after_restart[3].last_known_state).to eq('running')

        # ===========================================
        recreate_output = bosh_runner.run("recreate foobar1")
        expect(recreate_output).to include('Warning: You have ignored instances. No changes will be reflected on them.')
        expect(recreate_output).to_not include('Started updating job foobar1 > foobar1/0')
        expect(recreate_output).to include('Started updating job foobar1 > foobar1/1')
        expect(recreate_output).to include('Started updating job foobar1 > foobar1/2')
        expect(recreate_output).to_not include('Started updating job foobar2 > foobar2/0')

        vms_after_recreate = director.vms
        expect(vms_after_recreate[0].last_known_state).to eq('running')
        expect(vms_after_recreate[1].last_known_state).to eq('running')
        expect(vms_after_recreate[2].last_known_state).to eq('running')
        expect(vms_after_recreate[3].last_known_state).to eq('running')

        expect(vms_after_recreate[0].agent_id).to eq(ignored_vm.agent_id)
        expect(vms_after_recreate[1].agent_id).to_not eq(foobar1_vm_2.agent_id)
        expect(vms_after_recreate[2].agent_id).to_not eq(foobar1_vm_3.agent_id)
        expect(vms_after_recreate[3].agent_id).to eq(foobar2_vm_1.agent_id)

        # ========================================================================================
        # Targeting a specific ignored instance
        # ========================================================================================
        stop_output, stop_exit_code = bosh_runner.run("stop #{ignored_vm.job_name} #{ignored_vm.instance_uuid}", failure_expected: true, return_exit_code: true)
        expect(stop_output).to include("Error 140021: You are trying to change the state of the ignored instance 'foobar1/#{ignored_vm.instance_uuid}'. This operation is not allowed. You need to unignore it first.")
        expect(stop_exit_code).to_not eq(0)

        start_output, start_exit_code = bosh_runner.run("start #{ignored_vm.job_name} #{ignored_vm.instance_uuid}", failure_expected: true, return_exit_code: true)
        expect(start_output).to include("Error 140021: You are trying to change the state of the ignored instance 'foobar1/#{ignored_vm.instance_uuid}'. This operation is not allowed. You need to unignore it first.")
        expect(start_exit_code).to_not eq(0)

        restart_output, restart_exit_code = bosh_runner.run("restart #{ignored_vm.job_name} #{ignored_vm.instance_uuid}", failure_expected: true, return_exit_code: true)
        expect(restart_output).to include("Error 140021: You are trying to change the state of the ignored instance 'foobar1/#{ignored_vm.instance_uuid}'. This operation is not allowed. You need to unignore it first.")
        expect(restart_exit_code).to_not eq(0)

        recreate_output, recreate_exit_code = bosh_runner.run("recreate #{ignored_vm.job_name} #{ignored_vm.instance_uuid}", failure_expected: true, return_exit_code: true)
        expect(recreate_output).to include("Error 140021: You are trying to change the state of the ignored instance 'foobar1/#{ignored_vm.instance_uuid}'. This operation is not allowed. You need to unignore it first.")
        expect(recreate_exit_code).to_not eq(0)

      end
    end
  end
end
