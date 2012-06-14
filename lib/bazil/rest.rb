require 'forwardable'

require 'rubygems'
require 'json'
require 'net/http'

module Bazil
  class REST
    extend Forwardable

    def initialize(host, port, opt = {})
      @http = Net::HTTP.new(host, port)
      read_timeout = opt[:read_timeout] if opt.has_key?(:read_timeout)
    end

    def_delegators :@http, :read_timeout, :read_timeout=

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
      raise ConnectionError.new(method, @http.address, @http.port)
    end
  end # class Rest
end # module Bazil
