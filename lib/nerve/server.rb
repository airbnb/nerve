require 'eventmachine'

module Nerve
  class Server < EM::Connection
    include Logging
    @@connected_clients = Array.new
    def initialize(nerve)
      @nerve = nerve
      @services = Set.new
      log.info "TCP client connected"
    end
    def post_init
      @@connected_clients.push self
    end
    def unbind
      @@connected_clients.delete self
      log.info "TCP client disconnected"
      @services.each do |key|
        @nerve.remove_watcher key
      end
    end
    def receive_data(data)
      # Attempt to parse as JSON
      begin
        data.each_line do |line|
          line.chomp!
          begin
            json = JSON.parse(line)
            op = json['op']
            case op
            when 'service'
              @services.merge(@nerve.add_services(json['definition'], true))
            when 'status'
              send_data JSON.generate(@nerve.log_status)
            else
              # NOTE: This exists for backward (legacy) compatibility.  It
              # should be removed before we merge into master.
              @services.merge(@nerve.add_services(json, true))
            end
          rescue JSON::ParserError => e
            # nope!
            log.warn "received malformed data"
            log.debug "Got: '#{line.to_s}'"
            close_connection
          end
        end
      rescue => e
        log.warn "error on input:"
        log.warn $!.inspect
        log.warn $@
        log.warn "closing socket"
        close_connection
      end
    end
  end
end
