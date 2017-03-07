require "sinatra"
require 'json'
require 'haml'
require 'bunny'
require 'sinatra-websocket'


error do
  @e = request.env['sinatra_error']
  puts @e
  "500 server error".to_json
end
def list
  [{:sku => "test", :name => "A product", :price => 10, :available=>false},
  {:sku => "test2", :name => "Also a product",  :price => 10, :available=>true},
  {:sku => "test3", :name => "Another product",  :price => 10, :available=>true},
  {:sku => "test4", :name => "Some product",  :price => 10, :available=>true}]
end
def resource_url(item)
  request.base_url+"/products/"+item[:sku]
end
def details_url(item)
  request.base_url+"/products/"+item[:sku]+"/details/"
end
def want_json?
  puts request.accept.first
  request.accept.first.include? "json"
end
get '/products' do
  if want_json?
    list.map{|item|resource_url(item)}.to_json
  else
    haml :products
  end

end
lock=Mutex.new
$actions=[]
def add_action(uri_template)
  lock.synchronize do
    $actions.add uri_template
  end
end

get '/products/products-component' do
  available=  list.select {|product| product[:available]}
  uris=available.map{|item|resource_url(item)}
  haml :products_component, :locals => {:items =>uris}
end
get '/products/product-component' do
  haml :product_component,  :locals => {:actions =>$actions}
end
get '/products/product-details-component' do
  haml :product_detail_component
end
get '/products/:sku' do
  item=list.find{|item|item[:sku]==params['sku']}
  if(item.nil?)
    status 404
  elsif want_json?
    {:url => resource_url(item), :sku => item[:sku], :name => item[:name], :price => item[:price], :available=>item[:available],:details => details_url(item)}.to_json
  else
    haml :product, :locals => {:url =>resource_url(item)}
  end
end

#TODO This should be rabbit
post '/products/actions' do
  add_action params['url-template']
end

get '/products/:sku/details' do
  item=list.find{|item|item[:sku]==params['sku']}
  if(item.nil?)
    status 404
  elsif want_json?
    {:url => resource_url(item), :sku => item[:sku],:name => item[:name], :price => item[:price], :available=>item[:available]}.to_json
  else
    haml :details, :locals => {:item =>item}
  end
end
