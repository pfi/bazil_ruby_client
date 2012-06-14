require 'forwardable'

require 'rubygems'
require 'json'
require 'net/http'
require 'bazil/application'
require 'bazil/rest'
require 'bazil/error'

module Bazil
  class Client
    extend Forwardable

    def initialize(host, port)
      @http_cli = REST.new(host, port)
    end

    def_delegators :@http_cli, :read_timeout, :read_timeout=

    def status
      res = @http_cli.get(gen_uri('status'))
      raise_error("Failed to get status of the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def config
      res = @http_cli.get(gen_uri('config'))
      raise_error("Failed to get config of the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def update_config(conf)
      data = conf.to_json
      res = @http_cli.put(gen_uri('config'), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise_error("Failed to update config of the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def errors
      res = @http_cli.get(gen_uri('errors'))
      raise_error("Failed to get information of errors from the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def clear_errors
      res = @http_cli.delete(gen_uri('errors'))
      raise_error("Failed to clear error information of the server", res) unless res.code =~ /2[0-9][0-9]/
      true
    end

    def application_names
      res = @http_cli.get(gen_uri('apps'))
      # TODO: error check
      JSON.parse(res.body)['application_names']
    end

    def create_application(name, config = {})
      config['application_name'] = name
      data = config.to_json
      res, body = @http_cli.post(gen_uri('apps'), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise_error("Failed to create application: #{name}", res) unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      Application.new(self, name)
    end

    def delete_application(name)
      res, body = @http_cli.delete(gen_uri("apps/#{name}"))
      raise_error("Failed to delete application: #{name}", res) unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      true # TODO: return better information
    end

    def delete_all_applications
      res, body = @http_cli.delete("/#{api_version}")
      raise_error("Failed to delete applications: #{res.body}", res) unless res.code =~ /2[0-9][0-9]/
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

    def raise_error(message, res)
      raise APIError.new(message, res.code, JSON.parse(res.body))
    end
  end # class Client
end # module Bazil
