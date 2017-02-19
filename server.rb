require "sinatra"
require 'json'
require 'haml'

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
    available=  list.select {|product| product[:available]}
    uris=available.map{|item|resource_url(item)}
    haml :products, :locals => {:items =>uris}
  end

end
get '/products/component' do
  haml :product_component
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
