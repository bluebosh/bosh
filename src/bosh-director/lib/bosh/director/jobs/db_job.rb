module Bosh::Director
  module Jobs
    class DBJob
      attr_reader :job_class, :task_id

      def initialize(job_class, task_id, args)
        unless job_class.kind_of?(Class) &&
          job_class <= Jobs::BaseJob
          raise DirectorError, "Invalid director job class `#{job_class}'"
        end
        raise DirectorError, "Invalid director job class `#{job_class}'. It should have `perform' method." unless job_class.instance_methods(false).include?(:perform)
        @job_class = job_class
        @task_id = task_id
        @args = args
        raise DirectorError, "Invalid director job class `#{job_class}'. It should specify queue value." unless queue_name
      end

      def before(job)
        @worker_name = job.locked_by
      end

      def perform
        update_task_state

        process_status = ForkedProcess.run do
          perform_args = []

          unless @args.nil?
            perform_args = decode(encode(@args))
          end

          @job_class.perform(@task_id, @worker_name, *perform_args)
        end

        if process_status.signaled?
          Config.logger.debug("Task #{@task_id} was terminated, marking as failed")
          fail_task
        end
      end

      def queue_name
        if (@job_class.instance_variable_get(:@local_fs) ||
          (@job_class.respond_to?(:local_fs) && @job_class.local_fs)) && !Config.director_pool.nil?
          Config.director_pool
        else
          @job_class.instance_variable_get(:@queue) ||
            (@job_class.respond_to?(:queue) && @job_class.queue)
        end
      end

      private

      def update_task_state
        Config.db.transaction(retry_on: [Sequel::DatabaseConnectionError]) do
          task = Models::Task.where(id: @task_id).first
          raise DirectorError, "Task #{@task_id} not found in queue" unless task

          task.checkpoint_time = Time.now
          if task.state == 'cancelling'
            task.state = 'cancelled'
            Config.logger.debug("Task #{@task_id} cancelled")
          elsif task.state == 'queued'
            task.state = 'processing'
          else
            task.save
            raise DirectorError, "Cannot perform job for task #{@task_id} (not in 'queued' state)"
          end
          task.save
        end
      end

      def fail_task
        Models::Task.first(id: @task_id).update(state: 'error')
      end

      def encode(object)
        JSON.generate object
      end

      # Given a string, returns a Ruby object.
      def decode(object)
        return unless object

        begin
          JSON.parse object
        rescue JSON::ParserError => e
          raise DecodeException, e.message, e.backtrace
        end
      end
    end
  end

  class ForkedProcess
    def self.run
      pid = Process.fork do
        begin
          EM.run do
            operation = proc { yield }
            operation_complete_callback = proc { EM.stop }
            EM.defer( operation, operation_complete_callback )
          end
        rescue Exception => e
          Config.logger.error("Fatal error from event machine: #{e}\n#{e.backtrace.join("\n")}")
          raise e
        end
      end
      Process.waitpid(pid)

      $?
    end
  end
end
