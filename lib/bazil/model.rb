require 'rubygems'
require 'json'

module Bazil
  class Model
    attr_reader :application, :name

    def initialize(http_cli, app, name)
      @http_cli = http_cli
      @application = app
      @name = name

      status
    end

    def status
      res = @http_cli.get(gen_uri('status'))
      raise "Failed to get status of the model: application = #{@application.name}, model = #{@name}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    private
    def gen_uri(path = nil)
      if path
        "/apps/#{@application.name}/models/#{@name}/#{path}"
      else
        "/apps/#{@application.name}/models/#{@name}"
      end
    end
  end # module Model
end # module Bazil
