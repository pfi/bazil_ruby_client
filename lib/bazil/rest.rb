require 'rubygems'
require 'json'
require 'net/http'

module Bazil
  class REST
    def initialize(host, port)
      @http = Net::HTTP.new(host, port)
    end

    def get(uri)
      @http.get(uri)
    rescue Errno::ECONNREFUSED => e
      raise_error('GET')
    end

    def put(uri, data, header = {})
      @http.put(uri, data, header)
    rescue Errno::ECONNREFUSED => e
      raise_error('PUT')
    end

    def post(uri, data, header = {})
      @http.post(uri, data, header)
    rescue Errno::ECONNREFUSED => e
      raise_error('POST')
    end

    def delete(uri)
      @http.delete(uri)
    rescue Errno::ECONNREFUSED => e
      raise_error('DELETE')
    end

    private

    def raise_error(method)
      raise "Failed to connect to the server at #{method} method: server = #{@http.address}:#{@http.port}"
    end
  end # class Rest
end # module Bazil
