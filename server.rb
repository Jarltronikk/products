require "sinatra"
require 'json'
require 'haml'
require 'bunny'

$lock=Mutex.new
$actions={}
def add_action(key, priority, uri_template)
  $lock.synchronize do
    if($actions.has_key? key)
      if $actions[key][:priority]<priority
        $actions[key]={:priority=> priority, :uri_template=>uri_template}
      end
    else
      $actions[key]={:priority=> priority, :uri_template=>uri_template}
    end
  end
end
puts ENV["RABBITMQ"]
rabbitConn = Bunny.new(ENV["RABBITMQ"])
rabbitConn.start
channel=rabbitConn.create_channel
registryExchange=channel.topic("registry")

queue = channel.queue("", :exclusive => true, :durable=>false)
queue.bind(registryExchange, :routing_key=>"action.product.registration")

puts "Listening for action.product.registration"
queue.subscribe(:manual_ack => true, :block => false) do |delivery_info, properties, body|
  begin
    puts body
    message=JSON.parse body
    add_action message["key"], message["priority"], message["uri-template"]
  rescue Exception => e
    puts e
  end
  channel.ack(delivery_info.delivery_tag)
end

registryExchange.publish("what here?", :routing_key => "action.product.registration.request")
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
get '/products/products-component' do
  available=  list.select {|product| product[:available]}
  uris=available.map{|item|resource_url(item)}
  haml :products_component, :locals => {:items =>uris}
end
get '/products/product-component' do
  haml :product_component,  :locals => {:actions =>$actions.values.map{|action| action[:uri_template]}}
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
