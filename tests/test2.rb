#!/usr/bin/ruby
require 'weel'
require 'riddl/client'
require 'json'
require 'ld-eventsource'

de = { 'a' => 1}
ep = { 'b' => 1}
stat = WEEL::Status.new(0,"undefined")
add = { 'attributes' => { 'c' => 7 }, 'cpee' => {'uuid' => 3} }

ms = WEEL::ManipulateStructure.new(de,ep,stat,add)

result_mimetype = 'text/plain'
result = '__________'
code = <<-END
  data.a = 42
  data.d = cpee.uuid
  sleep 5
END

puts JSON::pretty_generate(ms)

client = Riddl::Client.new('http://localhost:9297')
status, res, headers = client.post [
  Riddl::Parameter::Complex.new('context','application/json',JSON::pretty_generate(ms)),
  Riddl::Parameter::Complex.new('code','text/plain',code),
  Riddl::Parameter::Complex.new('result',result_mimetype,result)
]

if status >= 200 && status < 300
  uuid = res[0].value
  wait = Queue.new
  sse_client = SSE::Client.new("http://localhost:9297/" + uuid + '/sse') do |client|
    client.on_event do |event|
      client.close
      wait.push 'ready'
    end
  end
  wait.deq
  s,r,h = client.resource(uuid).get
  pp JSON::parse(r[0].value.read)
else
  puts 'Not started'
end

