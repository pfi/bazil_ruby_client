require 'rubygems'
require 'json'
require 'net/http'
require 'bazil/application'

module Bazil
  class Client
    def initialize(host, port)
      @http_cli = Net::HTTP.new(host, port)
    end

    def application_names
      res = @http_cli.get('/apps')
      # TODO: error check
      JSON.parse(res.body)['application_names']
    end

    def create_application(name)
      data = %({"application_name": "#{name}"})
      res, body = @http_cli.post('/apps', data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise "Failed to create application: #{name}" unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      Application.new(@http_cli, name)
    end

    def delete_application(name)
      res, body = @http_cli.delete("/apps/#{name}")
      raise "Failed to delete application: #{name}" unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      true
    end

    def application(name)
      Application.new(@http_cli, name)
    end
  end # class Client
end # module Bazil
