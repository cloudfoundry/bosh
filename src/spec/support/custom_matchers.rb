require 'rspec'
require 'common/deep_copy'

RSpec::Matchers.define :be_create_swap_deleted do |old_vm|
  match do |new_vm|
    new_vm['active'] == 'true' &&
      new_vm['az'] == old_vm['az'] &&
      new_vm['vm_type'] == old_vm['vm_type'] &&
      new_vm['instance'] == old_vm['instance'] &&
      new_vm['process_state'] == 'running' &&
      new_vm['vm_cid'] != old_vm['vm_cid'] &&
      new_vm['ips'] != old_vm['ips']
  end
end

RSpec::Matchers.define :be_sequence_of_calls do |calls:, reference: {}|
  next_actual_call = {}
  next_expected_call = {}
  index = 0
  actual_index = 0
  did_fail_match = false
  sequence_length = calls.length
  original_expected_calls = Bosh::Common::DeepCopy.copy(calls)

  def highlight_call(calls, index)
    calls.map.with_index do |call, i|
      i == index ? '=> ' + call : call
    end
  end

  def prettify_expected_call(expected_call, reference)
    {
      target: expected_call[:target],
      method: expected_call[:method],
      agent_id: reference.fetch(expected_call[:agent_id], expected_call[:agent_id]),
      disk_id: reference.fetch(expected_call[:disk_id], expected_call[:disk_id]),
      vm_cid: reference.fetch(expected_call[:vm_cid], expected_call[:vm_cid]),
      argument_matcher: expected_call[:argument_matcher],
      response_matcher: expected_call[:response_matcher],
      can_repeat: expected_call[:can_repeat],
    }.inspect
  end

  match do |original_actual|
    actual = original_actual.dup
    matches = true

    until calls.empty?
      if actual.empty?
        matches = false
        break
      end
      next_actual_call = actual.shift
      next_expected_call = calls.shift
      matches &&= next_actual_call.target == next_expected_call[:target]
      matches &&= next_actual_call.method == next_expected_call[:method]

      if next_expected_call.key? :argument_matcher
        matches &&= next_expected_call[:argument_matcher].matches?(next_actual_call.arguments)
      end

      if next_expected_call.key? :response_matcher
        matches &&= next_expected_call[:response_matcher].matches?(next_actual_call.response)
      end

      if next_expected_call.key? :agent_id
        matches &&= next_actual_call.agent_id == next_expected_call[:agent_id]
      end

      if next_expected_call.key? :vm_cid
        matches &&= next_actual_call.vm_cid == next_expected_call[:vm_cid]
      end

      unless matches
        did_fail_match = true
        break
      end

      if next_expected_call[:can_repeat]
        actual = actual.drop_while do |i|
          i.to_hash == next_actual_call.to_hash && actual_index += 1
        end
      end

      actual_index += 1
      index += 1
    end
    matches && actual.empty?
  end

  failure_message do |actual|
    if did_fail_match
      "expected at index #{index} call did not match:\n" \
        "  expected:\n    #{prettify_expected_call(next_expected_call, reference)}\n" \
        "  actual:\n    #{next_actual_call.to_hash(true, reference).inspect}\n\n"  \
        "  actual calls:\n" \
        "    #{highlight_call(actual.map { |i| i.to_hash(false, reference).inspect }, actual_index).join("\n    ")}\n\n" \
        "  expected calls:\n" \
        "    #{highlight_call(original_expected_calls.map { |e| prettify_expected_call(e, reference) }, index).join("\n    ")}"
    else
      "expected a sequence of length #{sequence_length}#{calls.any? { |i| i[:can_repeat] } ? '+' : ''} " \
        "but got a differing sequence of length #{actual.length}: \n" \
        "#{actual.map { |i| i.to_hash(false, reference).inspect }.join("\n")}"
    end
  end
end
