require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

# TODO: Merge training_data API
TestCase 'Bazil-server label' do
  include_context 'bazil_case_utils'
  beforeCase { setup_environment }
  before { create_default_application }
  before do
    set :model_name, 'random'
    set :model_config, {
      'converter_config' => JSON.parse(File.read(CONFIG_PATH)),
      'classifier_config' => {
        'method' => 'nherd',
        'regularization_weight' => 0.2
      }
    }

    # Remove previous training data
    Mongo::Connection.new(*MONGODB_SERVERS.split(':')).db("bazil_#{app_name}").drop_collection(model_name)
    app.create_model(model_name, model_config)
    set :model, app.model(model_name)
  end

  after do
    app.delete_model(model_name)
  end
  after { delete_default_application }
  afterCase { cleanup_environment }

  test 'empty_labels' do
    result = model.labels
    assert_equal([], result)
  end
end
