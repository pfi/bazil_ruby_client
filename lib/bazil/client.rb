require 'rubygems'
require 'json'
require 'net/http'
require 'bazil/application'

module Bazil
  class Client
    def initialize(host, port)
      @http_cli = Net::HTTP.new(host, port)
    end

    def status
      res = @http_cli.get(gen_uri('status'))
      raise "Failed to get status of the server" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def config
      res = @http_cli.get(gen_uri('config'))
      raise "Failed to get config of the server" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def errors
      res = @http_cli.get(gen_uri('errors'))
      raise "Failed to get information of errors from the server" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def clear_errors
      res = @http_cli.delete(gen_uri('errors'))
      raise "Failed to clear error information of the server" unless res.code =~ /2[0-9][0-9]/
      true
    end

    def application_names
      res = @http_cli.get(gen_uri('apps'))
      # TODO: error check
      JSON.parse(res.body)['application_names']
    end

    def create_application(name)
      data = %({"application_name": "#{name}"})
      res, body = @http_cli.post(gen_uri('apps'), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise "Failed to create application: #{name}" unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      Application.new(self, name)
    end

    def delete_application(name)
      res, body = @http_cli.delete(gen_uri("apps/#{name}"))
      raise "Failed to delete application: #{name}" unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      true # TODO: return better information
    end

    def delete_all_applications
      res, body = @http_cli.delete("/#{api_version}")
      raise "Failed to delete applications: #{res.body}" unless res.code =~ /2[0-9][0-9]/
      true
    end

    def application(name)
      Application.new(self, name)
    end

    def http_client
      @http_cli
    end

    # TODO: make this changable
    def api_version
      'v1'
    end

    private
    def gen_uri(path)
      "/#{api_version}/#{path}"
    end
  end # class Client
end # module Bazil
