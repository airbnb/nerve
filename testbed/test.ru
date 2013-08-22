require 'sinatra'

get '/' do
  'hello'
  eval File.read 'http.rb'
end

run Sinatra::Application
