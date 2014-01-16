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

  it 'renders error state properly' do
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
    subject(:renderer) do
      described_class.new(stages_without_progress_bar: %w(fake-e1-stage fake-e2-stage fake-e3-stage fake-e4-stage))
    end

    context 'stages' do
      it 'outputs the stage name and duration when the stage is started' do
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 1, 1, 'started', [], 0, nil, 100))
        expect(renderer.render).to include('Started fake-e1-stage')
      end

      it 'outputs the stage name and duration when the stage is finished' do
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 1, 2, 'started', [], 0, nil, 100))
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 1, 2, 'finished', [], 0, nil, 1000))
        renderer.add_event(make_event('fake-e1-stage', 'fake-e2-task', 2, 2, 'started', [], 0, nil, 100))
        renderer.add_event(make_event('fake-e1-stage', 'fake-e2-task', 2, 2, 'finished', [], 0, nil, 1400))

        expect(renderer.render).to include('Done fake-e1-stage (00:21:40)')
      end

      it 'outputs the stage name and duration when the stage is failed' do
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 1, 2, 'started', [], 0, nil, 100))
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 1, 2, 'finished', [], 0, nil, 1000))
        renderer.add_event(make_event('fake-e1-stage', 'fake-e2-task', 2, 2, 'started', [], 0, nil, 100))
        renderer.add_event(make_event('fake-e1-stage', 'fake-e2-task', 2, 2, 'failed', [], 0, { 'error' => 'fake-error-description' }, 1000))

        expect(renderer.render).to include('Failed fake-e1-stage (00:15:00)')
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
    end

    context 'tasks' do

      it 'prints started marker with stage name + tags and task name when the task is started' do
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'started', []))
        expect(renderer.render).to match /^\s+Started fake-e1-stage: fake-e1-task$/

        renderer.add_event(make_event('fake-e2-stage', 'fake-e2-task', 0, 0, 'started', ['fake-e2-tag1']))
        expect(renderer.render).to match /^\s+Started fake-e2-stage fake-e2-tag1: fake-e2-task$/

        renderer.add_event(make_event('fake-e3-stage', 'fake-e3-task', 0, 0, 'started', ['fake-e3-tag1', 'fake-e3-tag2']))
        expect(renderer.render).to match /^\s+Started fake-e3-stage fake-e3-tag1, fake-e3-tag2: fake-e3-task$/
      end

      context 'task failed marker' do
        it 'prints failed marker with stage name task name' do
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'started', [], 0, nil, 100))
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'failed', [], 0, nil, 1000))
          expect(renderer.render).to match /^\s+Failed fake-e1-stage: fake-e1-task \(00:15:00\)$/
        end

        it 'prints failed marker with stage name,tag and task name' do
          renderer.add_event(make_event('fake-e2-stage', 'fake-e2-task', 0, 0, 'started', ['fake-e2-tag1'], 0, nil, 100))
          renderer.add_event(make_event('fake-e2-stage', 'fake-e2-task', 0, 0, 'failed', ['fake-e2-tag1'], 0, nil, 1000))
          expect(renderer.render).to match /^\s+Failed fake-e2-stage fake-e2-tag1: fake-e2-task \(00:15:00\)$/
        end

        it 'prints failed marker with stage name,tags and task name' do
          renderer.add_event(make_event('fake-e3-stage', 'fake-e3-task', 0, 0, 'started', ['fake-e3-tag1', 'fake-e3-tag2'], 0, nil, 100))
          renderer.add_event(make_event('fake-e3-stage', 'fake-e3-task', 0, 0, 'failed', ['fake-e3-tag1', 'fake-e3-tag2'], 0, nil, 1000))
          expect(renderer.render).to match /^\s+Failed fake-e3-stage fake-e3-tag1, fake-e3-tag2: fake-e3-task \(00:15:00\)$/
        end

        it 'prints failed information with included error description' do
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'started', [], 0, nil, 100))
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'failed', [], 0, { 'error' => 'fake-error-description' }, 1000))
          expect(renderer.render).to match /^\s+Failed fake-e1-stage: fake-e1-task \(00:15:00\): fake-error-description$/
        end

        it 'prints failed marker even when the event data is an empty hash' do
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'failed', [], 0, {}))
          renderer.render.should match /^\s+Failed fake-e1-stage: fake-e1-task$/
        end

        it 'prints failed marker even when the event data is nil' do
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'failed', [], 0, nil))
          renderer.render.should match /^\s+Failed fake-e1-stage: fake-e1-task$/
        end
      end

      context 'task finished marker' do
        it 'prints stage name and task name' do
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'started', [], 0, nil, 100))
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'finished', [], 0, nil, 3823))
          expect(renderer.render).to match /^\s+Done fake-e1-stage: fake-e1-task \(01:02:03\)$/
        end

        it 'print stage name, task name and tag' do
          renderer.add_event(make_event('fake-e2-stage', 'fake-e2-task', 0, 0, 'started', ['fake-e2-tag1'], 0, nil, 100))
          renderer.add_event(make_event('fake-e2-stage', 'fake-e2-task', 0, 0, 'finished', ['fake-e2-tag1'], 0, nil, 3823))
          expect(renderer.render).to match /^\s+Done fake-e2-stage fake-e2-tag1: fake-e2-task \(01:02:03\)$/
        end

        it 'print stage name, task name and tags' do
          renderer.add_event(make_event('fake-e3-stage', 'fake-e3-task', 0, 0, 'started', %W(fake-e3-tag1 fake-e3-tag2), 0, nil, 100))
          renderer.add_event(make_event('fake-e3-stage', 'fake-e3-task', 0, 0, 'finished', %W(fake-e3-tag1 fake-e3-tag2), 0, nil, 3823))
          expect(renderer.render).to match /^\s+Done fake-e3-stage fake-e3-tag1, fake-e3-tag2: fake-e3-task \(01:02:03\)$/
        end

        it 'print stage name, task name and no duration when finished time is invalid' do
          renderer.add_event(make_event('fake-e4-stage', 'fake-e4-task', 0, 0, 'started', [], 0, nil, 100))
          renderer.add_event(make_event('fake-e4-stage', 'fake-e4-task', 0, 0, 'finished', [], 0, nil, 'invalid'))
          expect(renderer.render).to match /^\s+Done fake-e4-stage: fake-e4-task$/
        end

        it 'does not print any information about progress' do
          renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'in_progress', []))
          expect(renderer.render).to eq('')
        end
      end

      it 'prints events in the correct order as they come in from the director' do
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'started', [], 0, nil, 100))
        renderer.add_event(make_event('fake-e2-stage', 'fake-e2-task', 0, 0, 'started', []))
        renderer.add_event(make_event('fake-e1-stage', 'fake-e1-task', 0, 0, 'finished', [], 0, nil, 1000))
        renderer.render.should == <<-OUTPUT
  Started fake-e1-stage: fake-e1-task
  Started fake-e2-stage: fake-e2-task
     Done fake-e1-stage: fake-e1-task (00:15:00)
     Done fake-e1-stage (00:15:00)
        OUTPUT
      end
    end
  end

  describe '#started_at' do
    context 'when event state is started' do
      it 'updates total duration started at time' do
        expect {
          renderer.add_event(make_event('fake-e1-stage', 'task1', 0, 0, 'started', [], 0, nil, 101))
        }.to change { renderer.started_at }.to(Time.at(101))
      end
    end
  end

  describe '#finished_at' do
    context 'when event state is finished' do
      it 'updates total duration finished at time' do
        expect {
          renderer.add_event(make_event('fake-e1-stage', 'task1', 0, 0, 'started', [], 0, nil, 0))
          renderer.add_event(make_event('fake-e1-stage', 'task1', 0, 0, 'finished', [], 0, nil, 101))
        }.to change { renderer.finished_at }.to(Time.at(101))
      end
    end
  end

  def make_event(stage, task, index, total, state = 'started', tags = [], progress = 0, data = nil, time = nil)
    event = {
      'time' => time || Time.now.to_i,
      'stage' => stage,
      'task' => task,
      'index' => index,
      'total' => total,
      'state' => state,
      'tags' => tags,
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
