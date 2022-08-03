# This file is part of CPEE-SCRIPT-RUBY.
#
# CPEE-SCRIPT-RUBY is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# CPEE-SCRIPT-RUBY is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# CPEE-SCRIPT-RUBY (file LICENSE in the main directory).  If not, see
# <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'weel'
require 'xml/smart'
require 'riddl/server'
require 'json'

def simplify_result(result)
  if result.length == 1
    if result[0].is_a? Riddl::Parameter::Simple
      result = result[0].value
    elsif result[0].is_a? Riddl::Parameter::Complex
      if result[0].mimetype == 'application/json'
        result = JSON::parse(result[0].value.read) rescue nil
      elsif result[0].mimetype == 'text/yaml'
        result = YAML::load(result[0].value.read) rescue nil
      elsif result[0].mimetype == 'application/xml' || result[0].mimetype == 'text/xml'
        result = XML::Smart::string(result[0].value.read) rescue nil
      elsif result[0].mimetype == 'text/plain'
        result = result[0].value.read
        if result.start_with?("<?xml version=")
          result = XML::Smart::string(result)
        else
          result = result.to_f if result == result.to_f.to_s
          result = result.to_i if result == result.to_i.to_s
        end
      elsif result[0].mimetype == 'text/html'
        result = result[0].value.read
        result = result.to_f if result == result.to_f.to_s
        result = result.to_i if result == result.to_i.to_s
      else
        result = result[0]
      end
    end
  end
  result
end

module CPEE
  module Script

    SERVER = File.expand_path(File.join(__dir__,'implementation.xml'))

    class Store < Riddl::Implementation #{{{
      def response
        uuid =  SecureRandom.uuid
        __context = JSON::parse(@p.shift.value.read)
        @a[0][uuid] = [
          false,
          WEEL::ManipulateStructure.new(
            __context['data'].transform_keys{|k| k.to_sym },
            __context['endpoints'].transform_keys{|k| k.to_sym },
            WEEL::Status.new(__context['status']['id'],__context['message']),
            __context['additional'].transform_keys{|k| k.to_sym }
          )
        ]
        EM.defer do
          code = @p.shift.value.read
          result = simplify_result(@p)
          @a[0][uuid][1].instance_eval(code)
          @a[0][uuid][0] = true
          if @a[1][uuid]
            @a[1][uuid].send('ready')
            @a[1].delete(uuid)
          end
        end
        Riddl::Parameter::Simple.new('id',uuid)
      end
    end #}}}

    class Get < Riddl::Implementation #{{{
      def response
        uuid = @r[-1]
        if @a[0][uuid] && @a[0][uuid][0]
          ret = @a[0][uuid][1]
          @a[0].delete(uuid)
          Riddl::Parameter::Complex.new('context','application/json',JSON::generate(ret))
        else
          @status = 304
          nil
        end
      end
    end #}}}

    class Nots < Riddl::SSEImplementation #{{{
      def onopen
        @ssec = @a[0]
        @key = @r[-2]
        if @ssec[@key]
          @ssec[@key].close
          @ssec.delete(@key)
        end

        @ssec[@key] = self
      end

      def onclose
        @ssec.delete(@key)
      end
    end #}}}


    def self::implementation(opts)
      opts[:sse_connections] ||= {}
      opts[:exec] ||= {}

      Proc.new do
        on resource do
          run Store, opts[:exec], opts[:sse_connections] if post 'script'
          on resource do
            run Get, opts[:exec] if get
            on resource 'sse' do
              begin
              run Nots, opts[:sse_connections] if sse
              rescue => e
                p e
              end
            end
          end
        end
      end
    end

  end
end
