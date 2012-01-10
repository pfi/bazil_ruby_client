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

    # TODO: config
    # TODO: retrain
    # TODO: label APIs

    def train(label, data)
      data = %({"label": "#{label}", "data": #{data.to_json}})
      post('train', data, "Failed to post training data")
      true
    end

    def classify(data)
      data = %({"data": #{data.to_json}})
      res = JSON.parse(post('classify', data, "Failed to post data for classification"))
      return res['max_label'], res
    end

    private
    def post(path, data, error_message)
      res = @http_cli.post(gen_uri(path), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise error_message + ": application = #{@application.name}, model = #{@name}" unless res.code =~ /2[0-9][0-9]/ # TODO: enhance error information
      res.body
    end

    def gen_uri(path = nil)
      if path
        "/apps/#{@application.name}/models/#{@name}/#{path}"
      else
        "/apps/#{@application.name}/models/#{@name}"
      end
    end
  end # module Model
end # module Bazil
