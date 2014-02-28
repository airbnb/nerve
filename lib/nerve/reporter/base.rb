
class Nerve::Reporter
  class Base
    include Nerve::Utils
    include Nerve::Logging

    def initialize(opts)
    end

    def start
    end

    def report_up
    end

    def report_down
    end

    def update_data(new_data='')
    end

    def ping?
    end
  end
end

