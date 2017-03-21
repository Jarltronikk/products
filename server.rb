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

registryExchange.publish("what here?", :routing_key => "product.registration")
error do
  @e = request.env['sinatra_error']
  puts @e
  "500 server error".to_json
end
def allproducts
  [
      {:sku => "ta-qwerty-no", :name => "Tastatur A",:description=>"Et fint tastatur. Norsk qwerty er det vanlige norske tastaturoppsettet", :price => 10, :available=>true, :variations=>[:layout], :layout=>"Norsk qwerty"},
      {:sku => "ta-qwerty-smi", :variant_of=>"ta-qwerty-no", :name => "Tastatur A",:description=>"Et fint tastatur. Samisk qwerty er det vanlige tastaturoppsett tilpasset for samisk.", :price => 10, :available=>true, :layout=>"Samisk qwerty"},
      {:sku => "ta-dvorak-no", :variant_of=>"ta-qwerty-no", :name => "Tastatur A",:description=>"Et fint tastatur. Norsk dvorak er oppsett for de litt mer spesielt interesserte..", :price => 10, :available=>true, :layout=>"Norsk dvorak"}
  ]
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
    allproducts.map{|item|resource_url(item)}.to_json
  else
    haml :products
  end

end
get '/products/products-component' do
  available=  allproducts.select {|product| product[:available]}
  uris=available.select{|product|not product.has_key?(:variant_of)}.map{|item|resource_url(item)}
  haml :products_component, :locals => {:items =>uris}
end
get '/products/product-component' do
  haml :product_component,  :locals => {:actions =>$actions.values.map{|action| action[:uri_template]}}
end
get '/products/product-details-component' do
  haml :product_detail_component
end
def map(item)#TODO make it nice yes?
  hash={:url => resource_url(item), :sku => item[:sku], :name => item[:name], :description=>item[:description],:price => item[:price], :available=>item[:available],:details => details_url(item) }
  item[:variations].each do |variation|
    hash[variation]=item[variation]
  end if item.has_key? :variations
  list=[hash]
  allproducts.select {|product| (product.has_key? :variant_of)&&product[:variant_of]==item[:sku]}.each do|product|
    hash={:url => resource_url(product), :sku => product[:sku], :name => product[:name],:description=>product[:description], :price => product[:price], :available=>product[:available]}
    item[:variations].each do |variation|
      hash[variation]=product[variation]
    end
    list<<hash
  end
  {:url => resource_url(item), :sku => item[:sku], :name => item[:name], :description=>item[:description],:price => item[:price], :available=>item[:available],:details => details_url(item),:variations=>item[:variations], :variants=>list}
end
get '/products/:sku' do
  item=allproducts.find{|item|item[:sku]==params['sku']}
  if(item.nil?)
    status 404
  elsif want_json?
    map(item).to_json
  else
    haml :product, :locals => {:url =>resource_url(item)}
  end
end


get '/products/:sku/details' do
  item=allproducts.find{|item|item[:sku]==params['sku']}
  if(item.nil?)
    status 404
  elsif want_json?
    {:url => resource_url(item), :sku => item[:sku],:name => item[:name], :price => item[:price], :available=>item[:available]}.to_json
  else
    haml :details, :locals => {:item =>item}
  end
end
