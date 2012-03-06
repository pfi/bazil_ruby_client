require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

# TODO: Merge training_data API
TestCase 'Bazil-server label' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'

  beforeCase { setup_environment }
  before { create_default_application }
  before { create_random_model }

  after { delete_random_model }
  after { delete_default_application }
  afterCase { cleanup_environment }

  test 'empty_labels' do
    result = model.labels
    assert_equal([], result)
  end
end
