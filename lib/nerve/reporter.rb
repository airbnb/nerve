require 'nerve/utils'
require 'nerve/log'
require 'nerve/reporter/base'

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
      reporter.new(service)
    end
  end
end
