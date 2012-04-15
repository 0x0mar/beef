require 'test/unit'
require 'rest_client'
require 'json'
require '../common/test_constants'
require '../common/beef_test'

class TC_DebugModules < Test::Unit::TestCase

  @@token = nil
  @@hb_session = nil

  @@mod_debug_long_string = nil
  @@mod_debug_ascii_chars = nil
  @@mod_debug_test_network = nil

  # Test RESTful API authentication with default credentials, returns the API token to be used later.
  def test_restful_auth
    response = RestClient.post "#{RESTAPI_ADMIN}/login",
                               { 'username' => "#{BEEF_USER}",
                                 'password' => "#{BEEF_PASSWD}"}.to_json,
                               :content_type => :json,
                               :accept => :json
    assert_equal 200, response.code
    assert_not_nil response.body
    result = JSON.parse(response.body)
    success = result['success']
    @@token = result['token']
    assert(success)
  end

  # Test RESTful API hooks handler hooking a victim browser, and then retrieving his BeEF session
  def test_restful_hooks
    BeefTest.new_victim
    sleep 2.0
    response = RestClient.get "#{RESTAPI_HOOKS}", {:params => {:token => @@token}}
    assert_equal 200, response.code
    assert_not_nil response.body
    result = JSON.parse(response.body)
    @@hb_session = result["hooked-browsers"]["online"]["0"]["session"]
    assert_not_nil @@hb_session
  end

  # Test RESTful API modules handler, retrieving the IDs of the 3 debug modules currently in the framework
  def test_restful_modules
    response = RestClient.get "#{RESTAPI_MODULES}", {:params => {:token => @@token}}
    assert_equal 200, response.code
    assert_not_nil response.body
    result = JSON.parse(response.body)
    result.each do |mod|
     case mod[1]["class"]
       when "Test_return_long_string"
         @@mod_debug_long_string = mod[1]["id"]
       when "Test_return_ascii_chars"
         @@mod_debug_ascii_chars = mod[1]["id"]
       when "Test_network_request"
         @@mod_debug_test_network = mod[1]["id"]
     end
    end
    assert_not_nil @@mod_debug_long_string
    assert_not_nil @@mod_debug_ascii_chars
    assert_not_nil @@mod_debug_test_network
  end

  # Test debug module "Test_return_long_string" using the RESTful API
  def test_return_long_string
    repeat_string = "BeEF"
    repeat_count = 20

    BeefTest.new_victim
    sleep 2.0
    response = RestClient.post "#{RESTAPI_MODULES}/#{@@hb_session}/#{@@mod_debug_long_string}?token=#{@@token}",
                               { 'repeat_string' => repeat_string,
                                 'repeat'        => repeat_count}.to_json,
                               :content_type => :json,
                               :accept => :json
    assert_equal 200, response.code
    assert_not_nil response.body
    result = JSON.parse(response.body)
    success = result['success']
    assert success

    cmd_id = result['command_id']
    sleep 3.0
    response = RestClient.get "#{RESTAPI_MODULES}/#{@@hb_session}/#{@@mod_debug_long_string}/#{cmd_id}", {:params => {:token => @@token}}
    assert_equal 200, response.code
    assert_not_nil response.body
    result = JSON.parse(response.body)
    data = JSON.parse(result["data"])
    assert_not_nil data
    assert data["data"] == (repeat_string * repeat_count)
  end

end