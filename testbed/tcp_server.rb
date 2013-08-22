#!/usr/bin/env ruby
require 'socket'
s = TCPServer.new 4321
while true
  begin
    conn = s.accept
    eval File.read 'tcp.rb'
  rescue Exception => e
    STDERR.puts e
  end
end
