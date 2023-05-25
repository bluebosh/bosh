require 'db_migrator'
require 'delayed_job'

module Bosh
  module Director
    class Worker
      def initialize(config, index = 0)
        @config = config
        @index = index
      end

      def prep
        Delayed::Worker.logger = @config.worker_logger

        ensure_migrations
        Bosh::Director::App.new(@config)

        Delayed::Worker.backend = :sequel
        Delayed::Worker.destroy_failed_jobs = true
        Delayed::Worker.sleep_delay = ENV['INTERVAL'] || 1
        Delayed::Worker.max_attempts = 0
        Delayed::Worker.max_run_time = 31_536_000

        @delayed_job_worker = nil
        queues = (ENV['QUEUES'] || ENV['QUEUE']).to_s.split(',')
        queues << @config.director_pool unless @config.director_pool.nil? || (queues - ['urgent']).empty?

        @delayed_job_worker = Delayed::Worker.new(queues: queues)

        # stop accepting new jobs when USR1 is sent
        trap('USR1') do
          Delayed::Worker.queues = ['non_existent_queue']
          @delayed_job_worker.logger.info('No longer accepting new jobs (received signal USR1)')
        end
      end

      def start
        @delayed_job_worker.name = "worker_#{@index}"
        @delayed_job_worker.logger.info("Starting worker #{@delayed_job_worker.name}.")
        Bosh::Director::Config.log_director_start_event('worker', @delayed_job_worker.name, {})

        begin
          @delayed_job_worker_retries ||= 0
          @delayed_job_worker.start
        rescue StandardError => e
          @delayed_job_worker.logger.error(
            "Something goes wrong during worker start. Attempt #{@delayed_job_worker_retries}. Error: #{e.inspect}",
          )
          while @delayed_job_worker_retries < 10
            @delayed_job_worker_retries += 1
            sleep @retry_interval
            retry
          end
          @delayed_job_worker.logger.error("Max retries reached. Error: #{e.inspect}")
          raise e
        end
      end

      def ensure_migrations
        if defined?(Bosh::Director::Models)
          raise 'Bosh::Director::Models were loaded before ensuring migrations are current. Cowardly refusing to start worker.'
        end
        migrator = DBMigrator.new(@config.db, :director)
        unless migrator.finished?
          @config.worker_logger.error(
            "Migrations not current during worker start after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} attempts.",
          )
          raise "Migrations not current after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} retries"
        end
        require 'bosh/director'
      end

      def queues
        @delayed_job_worker.queues
      end
    end
  end
end
