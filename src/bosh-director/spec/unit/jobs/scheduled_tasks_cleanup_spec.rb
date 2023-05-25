require 'spec_helper'

module Bosh::Director
  describe Jobs::ScheduledTasksCleanup do
    subject { described_class.new({}) }

    let(:task_remover) { double(Bosh::Director::Api::TaskRemover) }

    before do
      allow(Config).to receive(:max_tasks).and_return(2)
      allow(Bosh::Director::Api::TaskRemover).to receive(:new).and_return(task_remover)
    end

    describe '#initialize' do
      it 'has default values for the arguments' do
        expect { described_class.new }.to_not raise_error
      end
    end

    context 'there are task counts beyond max_tasks' do
      let!(:tasks) do
        Models::Task.make(type: 'vms', state: 'done')
        Models::Task.make(type: 'vms', state: 'done')
        Models::Task.make(type: 'vms', state: 'done')
        Models::Task.make(type: 'vms', state: 'processing')
        Models::Task.make(type: 'deployment', state: 'done')
        Models::Task.make(type: 'deployment', state: 'done')
        Models::Task.make(type: 'deployment', state: 'done')
        Models::Task.make(type: 'deployment', state: 'processing')
        Models::Task.make(type: 'deployment', state: 'queued')
        Models::Task.make(type: 'deployment', state: 'queued')
        Models::Task.make(type: 'snapshot_deployment', state: 'done')
        Models::Task.make(type: 'update_stemcell', state: 'done')
      end

      describe '.schedule_message' do
        it 'outputs a message' do
          expect(described_class.schedule_message).to eq('clean up tasks')
        end
      end

      describe '.job_type' do
        it 'returns the job type' do
          expect(described_class.job_type).to eq(:scheduled_task_cleanup)
        end
      end

      describe '#perform' do
        it 'should delete completed tasks with task remover' do
          expect(task_remover).to receive(:remove).with('deployment').and_return(1)
          expect(task_remover).to receive(:remove).with('snapshot_deployment').and_return(2)
          expect(task_remover).to receive(:remove).with('update_stemcell').and_return(3)
          expect(task_remover).to receive(:remove).with('vms').and_return(4)
          expect(subject.perform).to eq(
            "Deleted tasks and logs for\n" \
            "1 task(s) of type 'deployment'\n" \
            "2 task(s) of type 'snapshot_deployment'\n" \
            "3 task(s) of type 'update_stemcell'\n" \
            "4 task(s) of type 'vms'\n",
          )
        end
      end
    end
  end
end
