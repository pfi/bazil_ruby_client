require 'forwardable'

require 'rubygems'
require 'json'
require 'time'
require 'net/http'
require 'digest/md5'

module Bazil
  class REST
    extend Forwardable

    def initialize(http)
      @http = http
    end

    def_delegators :@http, :read_timeout, :read_timeout=

    def set_api_keys(key, secret)
      @api_key = key
      @secret_key = secret
      true
    end

    def get(uri)
      uri, header = add_api_signature(uri, nil)
      @http.get(uri, header)
    rescue Errno::ECONNREFUSED => e
      raise_error('GET')
    end

    def put(uri, data, header = {})
      uri, header = add_api_signature(uri, data, header)
      @http.put(uri, data, header)
    rescue Errno::ECONNREFUSED => e
      raise_error('PUT')
    end

    def post(uri, data, header = {})
      uri, header = add_api_signature(uri, data, header)
      @http.post(uri, data, header)
    rescue Errno::ECONNREFUSED => e
      raise_error('POST')
    end

    def delete(uri)
      uri, header = add_api_signature(uri, nil)
      @http.delete(uri, header)
    rescue Errno::ECONNREFUSED => e
      raise_error('DELETE')
    end

    private
    def add_api_signature(uri, data, header = {})
      return uri, header unless @api_key and @secret_key

      uri = uri.split('?')
      base = uri[0]
      current_time = Time.now.httpdate

      signature = ''
      signature = data.gsub(/\s/, '') if data
      parameters = []
      parameters = uri[1..-1] if uri.size > 1
      parameters << "api_key=#{@api_key}"
      signature << parameters.sort.join()
      signature << current_time
      signature << @secret_key
      parameters << "api_signature=#{Digest::MD5.hexdigest(signature)}"
      base << '?'
      base << parameters.join('&')

      return base, header.merge({'Date' => current_time})
    end

    def raise_error(method)
      raise ConnectionError.new(method, @http.address, @http.port)
    end
  end # class Rest
end # module Bazil
