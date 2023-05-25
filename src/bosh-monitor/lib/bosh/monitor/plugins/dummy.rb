module Bosh::Monitor
  module Plugins
    class Dummy < Base
      def run
        logger.info('Dummy delivery agent is running...')
      end

      def process(event)
        logger.info('Processing event!')
        logger.info(event)
        @events ||= []
        @events << event
      end

      attr_reader :events
    end
  end
end
