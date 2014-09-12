#!/usr/bin/env ruby -I ../lib -I lib
# coding: utf-8
require 'sinatra'
set :server, 'thin'
enable :sessions
set :bind, '0.0.0.0'

Notification_connections = []

connections = {}
Users = []
Notifications = Hash.new(0)
History = {}
# def get_key_between user1, user2
#   return (user1 > user2) ? [user1, user2] : [user2, user1]
# end

get '/' do
  unless params[:user]
    erb :login 
  else
    user = params[:user].gsub(/\W/, '')
    Users << params[:user] unless Users.include? user
    session[:user] = user
    erb :choose
  end
end

post '/chat' do 
  session[:receiver] = params[:receiver]
  Notifications[[session[:user],session[:receiver]]] = 0
  erb :chat, :locals => { :user => session[:user], :receiver => params[:receiver]}
end

get '/notif', :provides => 'text/event-stream' do
  stream :keep_open do |out|
    # puts out.inspect
    puts "open notif connection"
    Notification_connections << out
    out.callback { Notification_connections.delete(out); }
  end
end

get '/stream', :provides => 'text/event-stream' do
  # receiver = params[:receiver]
  # key = get_key_between(session[:user], session[:receiver])
  key = [session[:user], session[:receiver]]

  if connections[key] and !connections[key].closed?
    puts "user: %s, receiver: %s, found previous connection" % [session[:user], session[:receiver].to_s]
  else
    puts "user: %s, receiver: %s, create new connection" % [session[:user], session[:receiver].to_s]
    stream :keep_open do |out|
      connections[key] = out
      out.callback { connections.delete(key); }
    end
  end

  return connections[key]
end

get '/test' do
  Notification_connections.each do |out|
    # puts out.inspect
    out << "data: #{params[:data]}\n\n"
  end
  "updated"
end

post '/' do
  receiver = session[:receiver]
  user     = session[:user]
  # LOVE IS A TWO-WAY STREET
  [[user, receiver], [receiver, user]].each do |key|
    if connections[key] != nil and !connections[key].closed? #online
      connections[key] << "data: #{params[:msg]}\n\n" 
      History[key] = Array.new if History[key] == nil
      History[key] << "#{params[:msg]}"
    else # offline
      puts "Can't find key: " + key.inspect
      History[key] = Array.new if History[key] == nil
      History[key] << "#{params[:msg]}"
      Notifications[key] += 1
      puts "going to send notif "
      Notification_connections.each do |out|
        puts "data: #{key[0]},#{key[1]},#{Notifications[key]}"
        
        out << "data: #{key[0]},#{key[1]},#{Notifications[key]}\n\n"
      end
    end

    
  end

  204 # response without entity body
end

__END__