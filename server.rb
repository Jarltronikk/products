require "sinatra"
require 'json'

error do
  @e = request.env['sinatra_error']
  puts @e
  "500 server error".to_json
end
def list
  [{:sku => "test", :price => 10, :available=>false},
  {:sku => "test", :price => 10, :available=>true}]
end

def list_as_json

end

get '/' do
  if not request.accept? 'text/html' and request.accept? 'application/json'
    list.to_json
  else
    list.select {|product| product[:available]}.to_json
  end

end
get '/:sku' do
end