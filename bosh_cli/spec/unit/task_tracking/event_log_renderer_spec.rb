require 'spec_helper'

describe Bosh::Cli::TaskTracking::EventLogRenderer do
  subject(:renderer) { described_class.new }

  it 'allows adding events' do
    renderer.add_event(make_event('Preparing', 'Binding release', 1, 9, 'started'))
    renderer.add_event(make_event('Preparing', 'Binding existing deployment', 2, 9, 'started'))
    renderer.events_count.should == 2
  end

  it 'silently ignores malformed events' do
    renderer.add_event(make_event(nil, 'Binding release', 1, 9, nil, []))
    renderer.add_event(make_event('Preparing', 'Binding existing deployment', 2, nil, nil))
    renderer.add_event(JSON.generate('a' => 'b'))
    renderer.events_count.should == 0
  end

  it 'sets current stage based on the most recent event ' +
     'but ignores events from non-current stages' do
    renderer.add_event(make_event('Preparing', 'Binding release', 1, 9))
    renderer.current_stage.should == 'Preparing'

    renderer.add_event(make_event('Preparing', 'Binding existing deployment', 2, 9))
    renderer.current_stage.should == 'Preparing'

    renderer.add_event(make_event('Updating resource pool', 'Deleting outdated VM', 1, 5))
    renderer.current_stage.should == 'Updating resource pool'
    renderer.events_count.should == 3

    renderer.add_event(make_event('Preparing', 'Some additional stuff', 3, 9))
    renderer.current_stage.should == 'Updating resource pool'
    renderer.events_count.should == 3

    renderer.add_event(make_event('Updating job router', 'Canary update', 1, 1))
    renderer.current_stage.should == 'Updating job router'
    renderer.events_count.should == 4
  end

  it 'can render event log with progress bar' do
    buf = StringIO.new
    Bosh::Cli::Config.output = buf

    renderer.add_event(make_event('Preparing', 'Binding release', 1, 9))

    lines = renderer.render.split("\n")

    lines.count.should == 3
    lines[1].should == 'Preparing'
    lines[2].should =~ /Binding release/
    lines[2].should =~ /\|\s+\| 0\/9/

    renderer.add_event(make_event('Preparing', 'Moving stuff', 2, 9))

    lines = renderer.render.split("\n")
    lines.count.should == 1
    lines[0].should =~ /Binding release/
    lines[0].should =~ /\|\s+\| 0\/9/

    renderer.add_event(make_event('Preparing', 'Moving stuff', 2, 9, 'finished'))

    lines = renderer.render.split("\n")
    lines.count.should == 2
    lines[0].should =~ /moving stuff/
    lines[1].should =~ /Binding release/
    lines[1].should =~ /\|o+\s+\| 1\/9/

    # throwing in out-of-order event
    renderer.add_event(make_event('Preparing', 'Binding release', 1, 9, 'finished'))

    (3..9).each do |i|
      renderer.add_event(make_event('Preparing', "event #{i}", i, 9))
      renderer.add_event(make_event('Preparing', "event #{i}", i, 9, 'finished'))
    end

    lines = renderer.render.split("\n")
    lines.count.should == 9
    lines[-1].should =~ /\|o+\| 9\/9/

    renderer.add_event(make_event('Updating', 'prepare update', 1, 2, 'started', ['stuff', 'thing']))

    lines = renderer.render.split("\n")
    lines.count.should == 4

    lines[0].should =~ /Done/
    lines[0].should =~ /9\/9/
    lines[1].should == ''
    lines[2].should == 'Updating %s' % ['stuff, thing'.make_green]
    lines[3].should =~ /0\/2/

    lines = renderer.finish(:done).split('\n')
    lines[0].should =~ /Done/
    lines[0].should =~ /2\/2/
  end

  it 'renders erorr state properly' do
    buf = StringIO.new
    Bosh::Cli::Config.output = buf

    renderer.add_event(make_event('Preparing', 'Binding release', 1, 9))
    renderer.add_event(make_event('Preparing', 'Moving stuff', 2, 9))
    renderer.add_event(make_event('Preparing', 'Moving stuff', 2, 9, 'finished'))
    renderer.add_event(make_event('Updating', 'prepare update', 1, 2, 'started', ['stuff', 'thing']))

    lines = renderer.finish(:error).split('\n')
    lines[-1].should =~ /Error/
    lines[-1].should =~ /0\/2/
  end

  it 'supports tracking individual tasks progress' do
    renderer.add_event(make_event('Preparing', 'Binding release', 1, 2, 'started', [], 0))
    renderer.add_event(make_event('Preparing', 'Binding release', 1, 2, 'in_progress', [], 25))

    lines = renderer.render.split("\n")
    lines[1].should =~ /Preparing/
    lines[2].should =~ /\|o+\s+\| 0\/2/
    lines[2].should =~ /Binding release/

    renderer.add_event(make_event('Preparing', 'Binding release', 1, 2, 'in_progress', [], 50))

    lines = renderer.render.split("\n")
    lines[0].should =~ /\|o+\s+\| 0\/2/
    lines[0].should =~ /Binding release/

    renderer.add_event(make_event('Preparing', 'Binding release', 1, 2, 'finished', []))

    lines = renderer.render.split("\n")
    lines[1].should_not =~ /Binding release/
    lines[1].should =~ /\|o+\s+\| 1\/2/
  end

  describe 'tracking stages with progress bar' do
    context 'when event state is started' do
      it 'updates total duration started at time' do
        expect {
          renderer.add_event(make_event('with-progress', 'task1', 0, 0, 'started', [], 0, nil, 101))
        }.to change { renderer.started_at }.to(Time.at(101))
      end
    end

    context 'when event state is finished' do
      before { renderer.add_event(make_event('with-progress', 'task1', 0, 0, 'started')) } # start!

      it 'updates total duration finished at time' do
        expect {
          renderer.add_event(make_event('with-progress', 'task1', 0, 0, 'finished', [], 0, nil, 101))
        }.to change { renderer.finished_at }.to(Time.at(101))
      end
    end
  end

  describe 'tracking stages without progress bar' do
    subject(:renderer) { described_class.new(stages_without_progress_bar: %w(fake-e1-stage fake-e2-stage fake-e3-stage)) }

    def self.it_prints_marker_for_state(event_state, ui_label)
      it "prints #{event_state} marker with stage name + tags and task name" do
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, event_state, []))
        renderer.render.should match /^\s+#{ui_label} fake-e1-stage: fake-e1-task$/

        renderer.add_event(make_event('fake-e2-stage', 'fake-e2-task', 0, 0, event_state, ['fake-e2-tag1']))
        renderer.render.should match /^\s+#{ui_label} fake-e2-stage fake-e2-tag1: fake-e2-task$/

        renderer.add_event(make_event('fake-e3-stage', 'fake-e3-task', 0, 0, event_state, ['fake-e3-tag1', 'fake-e3-tag2']))
        renderer.render.should match /^\s+#{ui_label} fake-e3-stage fake-e3-tag1, fake-e3-tag2: fake-e3-task$/
      end
    end

    it_prints_marker_for_state 'started',  'Started'
    it_prints_marker_for_state 'finished', 'Done'
    it_prints_marker_for_state 'failed',   'Failed'

    it 'does not print any information about progress' do
      renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'in_progress', []))
      renderer.render.should == ''
    end

    context 'when event state is started' do
      it 'updates total duration started at time' do
        expect {
          renderer.add_event(make_event('fake-e1-stage', 'task1', 0, 0, 'started', [], 0, nil, 101))
        }.to change { renderer.started_at }.to(Time.at(101))
      end
    end

    context 'when event state is finished' do
      it 'updates total duration finished at time' do
        expect {
          renderer.add_event(make_event('fake-e1-stage', 'task1', 0, 0, 'finished', [], 0, nil, 101))
        }.to change { renderer.finished_at }.to(Time.at(101))
      end
    end

    context 'when event state is failed' do
      [nil, {}].each do |incomplete_data|
        it "prints failed marker even when no event data is not available (#{incomplete_data.inspect})" do
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'failed', [], 0, incomplete_data))
          renderer.render.should match /^\s+Failed fake-e1-stage: fake-e1-task$/
        end
      end

      it 'prints failed information with included error description' do
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'failed', [], 0, {'error' => 'fake-error-description'}))
        renderer.render.should match /^\s+Failed fake-e1-stage: fake-e1-task: fake-error-description$/
      end
    end

    it 'ends previous stage (that was rendered with a progress bar) once new stage is started' do
      renderer.add_event(make_event('Preparing', 'Binding release', 1, 2))
      renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'started', []))

      # Add 2nd event to make sure that there is not spaces between start events
      renderer.add_event(make_event('fake-e2-stage', 'fake-e2-task', 0, 0, 'started', []))

      final_console_output(renderer.render).should == <<-OUTPUT

Preparing
Done                          2/2 00:00:00

  Started fake-e1-stage: fake-e1-task
  Started fake-e2-stage: fake-e2-task
      OUTPUT
    end

    it 'prints events right on the next line as they come in from the director' do
      renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'started', []))
      renderer.add_event(make_event('fake-e2-stage', 'fake-e2-task', 0, 0, 'started', []))
      renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'finished', []))
      renderer.render.should == <<-OUTPUT
  Started fake-e1-stage: fake-e1-task
  Started fake-e2-stage: fake-e2-task
     Done fake-e1-stage: fake-e1-task
      OUTPUT
    end
  end

  def make_event(stage, task, index, total, state = 'started', tags = [], progress = 0, data = nil, time = nil)
    event = {
      'time'  => time || Time.now.to_i,
      'stage' => stage,
      'task'  => task,
      'index' => index,
      'total' => total,
      'state' => state,
      'tags'  => tags,
      'progress' => progress,
    }

    event.merge!('data' => data) if data

    JSON.generate(event)
  end

  # Removes contents between \r to remove progress bars
  def final_console_output(str)
    str.gsub(/\r[^\n]+\r/, '')
  end
end
