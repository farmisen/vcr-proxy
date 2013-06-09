require "rubygems" 
require "goliath" 
require "em-http" 
require "em-synchrony/em-http" 
require "pp"
require "vcr"
require "debugger"

# see https://groups.google.com/group/phillyrb/tree/browse_frm/month/2012-02/8e621fa1ca1453fc?rnum=131&_done=%2Fgroup%2Fphillyrb%2Fbrowse_frm%2Fmonth%2F2012-02%3F

# start with `ruby proxy.rb -sv`

VCR.configure do |c|
  c.cassette_library_dir = "cassettes"
  c.default_cassette_options = {
    match_requests_on: [:method, :uri, :body],
    decode_compressed_response: true,
    :record => :once,
    serialize_with: :syck
  }
  c.hook_into :webmock
end

class VCRProxy < Goliath::API
  use Goliath::Rack::Params 

  def response(env)
    @current_cassette ||= "api"

    request_path = env[Goliath::Request::REQUEST_PATH]

    if request_path.match /^\/__vcr__\/insert\//
      @current_cassette = request_path.split("/").last
      VCR.insert_cassette(@current_cassette)
      env.logger.info "Inserted cassette: #{@current_cassette}"

      [200, {}, nil]
    elsif request_path.match /^\/__vcr__\/eject/
      VCR.eject_cassette
      env.logger.info "Ejected cassette: #{@current_cassette}"

      [200, {}, nil]
    elsif request_path.match /^\/api\//
      env.logger.info "Proxying new request: #{request_path}"

      params = { :head => env["client-headers"], :query => env.params }
      request = EM::HttpRequest.new("http://localhost:3000#{request_path}")

      request_method = env[Goliath::Request::REQUEST_METHOD]
      response = case request_method
        when "GET"  then request.get(params)
        when "POST" then request.post(params.merge(:body => env[Goliath::Request::RACK_INPUT].read))
        when "HEAD" then request.head(params)
        else p "UNKNOWN METHOD #{request_method}"
      end

      response.response_header["X-Goliath"] = "Proxy"
      [response.response_header.status, response.response_header, response.response]
    end
  end

  def to_http_header(k) 
    k.downcase.split("_").collect { |e| e.capitalize }.join("-") 
  end 

end
