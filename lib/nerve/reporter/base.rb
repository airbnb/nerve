
class Nerve::Reporter
  class Base
    include Nerve::Utils
    include Nerve::Logging

    def initialize(opts)
    end

    def start
    end

    def stop
    end

    def report_up
    end

    def report_down
    end

    def update_data(new_data='')
    end

    def ping?
    end

    protected
    def parse_data(data)
      return data if data.class == String
      return data.to_json
    end
  end
end

