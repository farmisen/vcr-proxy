require "rubygems" 
require "goliath" 
require "em-http" 
require "em-synchrony/em-http" 
require "pp" 
require "debugger"

# see https://groups.google.com/group/phillyrb/tree/browse_frm/month/2012-02/8e621fa1ca1453fc?rnum=131&_done=%2Fgroup%2Fphillyrb%2Fbrowse_frm%2Fmonth%2F2012-02%3F

# start with `ruby proxy.rb -sv`

class HttpLog < Goliath::API 
  use Goliath::Rack::Params 

  def on_headers(env, headers) 
    env.logger.info "Proxying new request: #{headers.inspect}"
    env["client-headers"] = headers
  end

  def on_body(env, data)
    env.logger.info "Received data: #{data}"
  end

  def response(env) 
    params = {:head => env["client-headers"], :query => env.params}

    request_path = env[Goliath::Request::REQUEST_PATH]
    request = EM::HttpRequest.new("http://localhost:3000/#{request_path}")

    request_method = env[Goliath::Request::REQUEST_METHOD]
    response = case request_method
      when "GET"  then request.get(params)
      when "POST" then request.post(params.merge(:body =>
env[Goliath::Request::RACK_INPUT].read)) 
      when "HEAD" then request.head(params)
      else p "UNKNOWN METHOD #{request_method}"
    end

    response_headers = {}
    response.response_header.each_pair do |k, v|
      response_headers[to_http_header(k)] = v
    end

    [response.response_header.status, response_headers, response.response]
  end 

  def to_http_header(k) 
    k.downcase.split("_").collect { |e| e.capitalize }.join("-") 
  end 

end
