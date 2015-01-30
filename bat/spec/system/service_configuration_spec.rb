require 'system/spec_helper'

def instance_reboot(ip)
  # turn off vm resurrection
  bosh('vm resurrection off')

  # shutdown instance
  expect(ssh(ip, 'vcap', "echo 'c1oudc0w' | sudo -p '' -S reboot && echo 'SUCCESS'", ssh_options)).to eq("SUCCESS\n")

  # wait for it to come back up (max 2 minutes)
  start = Time.now.to_i
  result = ''
  loop do
    sleep 10
    begin
      result = ssh(ip, 'vcap', "echo 'UP'", ssh_options)
    rescue Exception => e
      @logger.info("Failed to run ssh command. Retrying. Message: #{e.message}")
    end
    break unless (Time.now.to_i - start) < 120 && result != "UP\n"
  end

  expect(result).to eq("UP\n")

  # turn on vm resurrection
  bosh('vm resurrection on')
end

def process_running_on_instance(ip, process_name)
  # make sure process is up and running
  tries = 0
  pid = ''
  loop do
    sleep 1
    pid = ssh(ip, 'vcap', "pgrep #{process_name}", ssh_options)
    break unless (tries += 1) < 30 && (pid =~ /^\d+\n$/).nil?
  end
  expect(pid =~ /^\d+\n$/).to eq(0), "Expected process '#{process_name}' to be running after 30 seconds, but it was not"
end

def runit_running_on_instance(ip)
  process_running_on_instance(ip, "runsvdir")
end

def agent_running_on_instance(ip)
  process_running_on_instance(ip, "bosh-agent")
end

def monit_running_on_instance(ip)
  process_running_on_instance(ip, "monit")
end

def batlight_running_on_instance(ip)
  process_running_on_instance(ip, "batlight")
end

describe 'service configuration', :type => 'os'  do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:all) do
    load_deployment_spec
    use_static_ip
    use_vip
    @requirements.requirement(deployment, @spec) # 2.5 min on local vsphere
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  let(:sudo) { "echo 'c1oudc0w' | sudo -S -p '' -s" }

  let(:bash_functions) do
    <<-EOF
      waitForProcess() {
        local proc_name="${1}"
        local old_pid="${2}"

        for i in `seq 1 30`; do
          new_pid="$(pgrep ^${proc_name}$)"
          if [ -n "${new_pid}" ] && [ "x${old_pid}" != "x${new_pid}" ]; then break; fi
          sleep 1
        done

        if [ -z "${new_pid}" ] || [ "x${old_pid}" = "x${new_pid}" ]; then
          if [ -z "${new_pid}" ]; then
            echo "FAILURE: never found ${proc_name} running"
          else
            echo "FAILURE: ${proc_name} is still running with the prior pid (${old_pid})"
          fi

          exit 1
        fi

        echo $new_pid
      }

      killAndAwaitProcess() {
        local proc_name="${1}"

        local pid="$(waitForProcess ${proc_name})"
        echo 'c1oudc0w' | sudo -p '' -S kill -9 ${pid}
        waitForProcess ${proc_name} ${pid}
      }

      waitForSymlink() {
        local name="${1}"
        for i in `seq 1 30`; do
          if [ -h "${name}" ]; then break; fi
          sleep 1
        done

        if [ ! -h "${name}" ]; then
          echo "FAILURE: ${name} missing or not a symlink"
          exit 1
        fi

        readlink ${1}
      }
    EOF
  end

  describe 'runit' do
    before(:each) do
      runit_running_on_instance(public_ip)
    end

    after(:each) do
      instance_reboot(public_ip)
    end

    context 'when initially started after instance boot (before agent has been started)' do
      it 'deletes /etc/service/monit' do
        # expect /etc/service/monit to be younger that the system's uptime
        cmd = <<-EOF
          #{bash_functions}
          _=$(waitForSymlink /etc/service/monit)
          now="$(date +"%s")"
          mod_time="$(stat --printf="%Y" /etc/service/monit)"
          up_time="$(cut -f1 -d. /proc/uptime)"
          diff=$((${up_time}-${now}+${mod_time}))
          if [ $diff -ge 0 ]; then
            echo "SUCCESS"
          else
            echo "FAILURE: expected /etc/service/monit to be younger than uptime, got a difference of ${diff} seconds"
          fi
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
      end

      context 'when monit dies' do
        it 'restarts it' do
          # compare monit pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            old_pid="$(waitForProcess monit '')"
            echo 'c1oudc0w' | sudo -p '' -S kill ${old_pid}
            new_pid="$(waitForProcess monit $old_pid)"
            if [[ "${new_pid}" = "${old_pid}" || -z "${new_pid}" ]]; then echo 'FAILURE'; fi
            echo "SUCCESS"
          EOF
          expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
        end
      end

      context 'when the agent dies' do
        it 'restarts it' do
          # compare agent pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            old_pid="$(waitForProcess bosh-agent '')"
            echo 'c1oudc0w' | sudo -p '' -S kill ${old_pid}
            new_pid="$(waitForProcess bosh-agent $old_pid)"
            if [[ "${new_pid}" = "${old_pid}" || -z "${new_pid}" ]]; then echo 'FAILURE'; fi
            echo "SUCCESS"
          EOF
          expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
        end
      end
    end

    context 'when restarted after agent has been started' do
      it 'does not delete /etc/service/monit' do
        # wait for agent and monit to come up
        agent_running_on_instance(public_ip)
        monit_running_on_instance(public_ip)

        # compare pids pre- and post runsvdir kill
        # make sure runsvdir does not delete /etc/service/monit
        cmd = <<-EOF
          #{bash_functions}
          agent_pid="$(waitForProcess bosh-agent)"
          monit_pid="$(waitForProcess monit)"

          _=$(waitForSymlink /etc/service/monit)
          link_time="$(stat --printf="%Y" /etc/service/monit)"

          _=$(killAndAwaitProcess runsvdir)
          new_agent_pid="$(pgrep ^bosh-agent$)"
          new_monit_pid="$(pgrep ^monit$)"
          if [ "${new_agent_pid}" != "${agent_pid}" ] || [ -z "${new_agent_pid}" ]; then
            echo "FAILURE: Agent pid changed from ${agent_pid} to ${new_agent_pid}"
          fi
          if [ "${new_monit_pid}" != "${monit_pid}" ] || [ -z "${new_monit_pid}" ]; then
            echo "FAILURE: Monit pid changed from ${monit_pid} to ${new_monit_pid}"
          fi
          if [ "$(stat --printf="%Y" /etc/service/monit)" != "${link_time}" ] || [ -z "${link_time}" ]; then
            echo 'FAILURE: /etc/service/monit symlink changed'
          fi
          echo "SUCCESS"
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
      end

      context 'when monit dies' do
        it 'restarts it' do
          # wait for monit to come up
          monit_running_on_instance(public_ip)

          # compare monit pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            _=$(killAndAwaitProcess runsvdir)
            _=$(killAndAwaitProcess monit)
            echo "SUCCESS"
          EOF
          expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
        end
      end

      context 'when the agent dies' do
        it 'restarts it' do
          # wait for agent to come up
          agent_running_on_instance(public_ip)

          # compare agent pids pre- and post kill
          cmd = <<-EOF
            #{bash_functions}
            _=$(killAndAwaitProcess runsvdir)
            _=$(killAndAwaitProcess bosh-agent)
            echo "SUCCESS"
          EOF
          expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
        end
      end
    end
  end

  describe 'agent' do
    before(:each) do
      agent_running_on_instance(public_ip)
    end

    context 'when initially started after instance boot' do
      it 'starts monit' do
        # make sure monit is up and running
        monit_running_on_instance(public_ip)
      end

      it 'mounts tmpfs to /var/vcap/data/sys/run' do
        # verify mount point for sys/run
        cmd = "if [ x`mount | grep -c /var/vcap/data/sys/run` = x1 ] ; then echo 'SUCCESS' ; fi"
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
      end

      it 'creates a symlink from /etc/sv/monit to /etc/service/monit' do
        # shutdown agent and remove /etc/service/monit
        # make sure agent recreates /etc/service/monit upon restart
        cmd = <<-EOF
          #{bash_functions}
          #{sudo} PATH=$PATH:/sbin sv down agent
          echo 'c1oudc0w' | sudo -p '' -S rm -rf /etc/service/monit
          if [ -f /etc/service/monit ]; then echo 'FAILURE'; fi
          #{sudo} PATH=$PATH:/sbin sv up agent
          link_target=$(waitForSymlink /etc/service/monit)
          if [ "${link_target}" != "/etc/sv/monit" ]; then
            echo "FAILURE: wrong symlink for /etc/service/monit: expected /etc/sv/monit, got ${link_target}"
          fi
          echo 'SUCCESS'
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
      end

      it 'does not keep pre-existing pid files in sys/run after instance reboot' do
        # wait until monit comes up
        monit_running_on_instance(public_ip)

        # wait for batlight
        batlight_running_on_instance(public_ip)

        # compare pidfile with actual pid and the pid that monit uses; create dummy file in sys/run
        cmd = <<-EOF
          pgrep=$(pgrep ^batlight$)
          pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          if [ "${pid}" != "${pgrep}" ]; then
            echo "FAILURE: actual batlight pid (${pgrep}) different from pid in batlight.pid (${pid})"
          fi
          for i in `seq 1 30`; do
            monit=$(#{sudo} PATH=$PATH:/var/vcap/bosh/bin monit status | grep '^\s*pid' | awk '{ print \$2 }')
            if [ -n "${monit}" ] && [ "x${monit}" != "x0" ]; then break; fi
            sleep 1
          done
          if [ "${monit}" != "${pgrep}" ]; then
            echo "FAILURE: actual batlight pid (${pgrep}) different from pid monitored by monit (${monit})"
          fi
          touch /var/vcap/data/sys/run/foo.pid
          echo 'SUCCESS'
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")

        # reboot instance
        instance_reboot(public_ip)

        # wait for monit
        monit_running_on_instance(public_ip)

        # wait for batlight
        batlight_running_on_instance(public_ip)

        # compare pidfile with actual pid and the pid that monit uses; make sure dummy file in sys/run is gone
        cmd = <<-EOF
          pgrep=$(pgrep ^batlight$)
          pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          if [ "${pid}" != "${pgrep}" ]; then
            echo "FAILURE: actual batlight pid (${pgrep}) different from pid in batlight.pid (${pid})"
          fi
          for i in `seq 1 30`; do
            monit=$(#{sudo} PATH=$PATH:/var/vcap/bosh/bin monit status | grep '^\s*pid' | awk '{ print \$2 }')
            if [ -n "${monit}" ] && [ "x${monit}" != "x0" ]; then break; fi
            sleep 1
          done
          if [ "${monit}" != "${pgrep}" ]; then
            echo "FAILURE: actual batlight pid (${pgrep}) different from pid monitored by monit (${monit})"
          fi
          if [ -f /var/vcap/data/sys/run/foo.pid ]; then
            echo "FAILURE: foo.pid still existing"
          fi
          echo 'SUCCESS'
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
      end
    end

    context 'when restarted by runit' do
      it 'does not remount /var/vcap/data/sys/run' do
        # put file into /var/vcap/data/sys/run
        # restart agent
        # make sure file still exists
        cmd = <<-EOF
          touch /var/vcap/data/sys/run/foo
          #{sudo} PATH=$PATH:/sbin sv down agent
          #{sudo} PATH=$PATH:/sbin sv up agent
          if [ -f /var/vcap/data/sys/run/foo ]; then
            echo 'SUCCESS';
          else
            echo "FAILURE: foo not existing anymore"
          fi
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
      end

      it 'does not remove existing pid files' do
        # wait for batlight
        batlight_running_on_instance(public_ip)

        # compare pids pre and post agent restart
        cmd = <<-EOF
          old_pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          #{sudo} PATH=$PATH:/sbin sv down agent
          #{sudo} PATH=$PATH:/sbin sv up agent
          new_pid=$(cat /var/vcap/data/sys/run/batlight/batlight.pid)
          if [ "${old_pid}" = "${new_pid}" ]; then
            echo 'SUCCESS'
          else
            echo 'FAILURE: batlight.pid changed'
          fi
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
      end

      it 'does not recreates a symlink from /etc/sv/monit to /etc/service/monit' do
        # compare modification times for /etc/service/monit pre and post agent restart
        cmd = <<-EOF
          old_time=$(stat  --print '%Y' /etc/service/monit)
          #{sudo} PATH=$PATH:/sbin sv down agent
          #{sudo} PATH=$PATH:/sbin sv up agent
          new_time=$(stat  --print '%Y' /etc/service/monit)
          if [ "${old_time}" = "${new_time}" ]; then
            echo 'SUCCESS'
          else
            echo 'FAILURE: /etc/service/monit modified'
          fi
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
      end

      it 'does not restart monit' do
        # wait for monit
        monit_running_on_instance(public_ip)

        # compare monit pid and process time pre and post agent restart
        cmd = <<-EOF
          old_pid=$(pgrep ^monit$)
          #{sudo} PATH=$PATH:/sbin sv down agent
          #{sudo} PATH=$PATH:/sbin sv up agent
          new_pid=$(pgrep ^monit$)
          if [ "${old_pid}" = "${new_pid}" ]; then
            echo 'SUCCESS'
          else
            echo 'FAILURE: monit restarted'
          fi
        EOF
        expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")
      end
    end
  end

  describe 'monit' do
    before(:each) do
      # wait for monit to come up
      monit_running_on_instance(public_ip)
    end

    context 'when initially started by agent' do
      context 'when a monitored process dies' do
        it 'restarts it' do
          # wait for batlight
          batlight_running_on_instance(public_ip)

          # kill batlight
          cmd = "#{sudo} pkill batlight && echo 'SUCCESS'"
          expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")

          # wait for batlight to come up again
          batlight_running_on_instance(public_ip)
        end
      end
    end

    context 'when restarted by runit' do
      context 'when a monitored process dies' do
        it 'restarts it' do
          # kill monit
          cmd = "#{sudo} pkill monit && echo 'SUCCESS'"
          expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")

          # wait for monit to come up again
          monit_running_on_instance(public_ip)

          # kill batlight
          cmd = "#{sudo} pkill batlight && echo 'SUCCESS'"
          expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to eq("SUCCESS\n")

          # wait for batlight to come up again
          batlight_running_on_instance(public_ip)
        end
      end
    end
  end
end
