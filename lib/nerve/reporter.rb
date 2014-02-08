require 'zk'

module Nerve
  class Reporter
    def self.new_from_service(service)
      type = service['reporter_type'] || 'zookeeper'
      reporter = begin
        require "nerve/reporter/#{type.downcase}"
        self.const_get(type.downcase.capitalize)
      rescue Exception => e
        raise ArgumentError, "specified a reporter_type of #{type}, which could not be found: #{e}"
      end
      reporter.new_from_service service
    end
  end
end

class Nerve::Reporter
  class Base
    include Nerve::Utils
    include Nerve::Logging
    def initialize(opts)
    end

    def start()
    end

    def report_up()
    end

    def report_down
    end

    def update_data(new_data='')
    end

    def ping?
    end
  end
end

