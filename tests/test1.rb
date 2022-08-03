#!/usr/bin/ruby
require 'weel'
require 'riddl/client'
require 'json'

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
  sleep 3
END

client = Riddl::Client.new('http://localhost:9297')
status, res, headers = client.post [
  Riddl::Parameter::Complex.new('context','application/json',JSON::pretty_generate(ms)),
  Riddl::Parameter::Complex.new('code','text/plain',code),
  Riddl::Parameter::Complex.new('result',result_mimetype,result)
]

if status >= 200 && status < 300
  begin
    sleep 0.5
    s,r,h = client.resource(res[0].value).get
  end while s != 200
  pp JSON::parse(r[0].value.read)
else
  puts 'Not started'
end

