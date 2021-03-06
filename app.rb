require 'sinatra'
require 'sinatra/json'
require 'bundler'
require 'youtube-dl.rb'
require 'pp'
require 'sinatra/activerecord'
require './config/environments'
require 'sinatra/cross_origin'
require 'securerandom'


load 'lib/services/download_service.rb'
load 'lib/services/splitter_service.rb'
load 'lib/track.rb'
load 'lib/user.rb'
load 'lib/playlist_track.rb'

use Rack::Logger

helpers do
    def logger
        request.logger
    end
end

configure do
    enable :cross_origin
end

before do
    response.headers['Access-Control-Allow-Origin'] = '*'
end

downloader = DownloadService.new
splitter = SplitterService.new



#track = Track.create(name: title, artist: artist, duration: duration_in_seconds, filepath: path+"/"+track['title']+".m4a")
#user = User.create(username: "hey", password: "datstick")

post '/real/download_tape' do
    content_type :json

    url = params[:url].to_s

    raw_video_info = `youtube-dl --skip-download -j #{url}`
    json_video_info = JSON.parse(raw_video_info)
end

post '/test/download' do
    content_type :json

    puts params[:url]

    puts 'Ripping...'
    metadata = downloader.rip_metadata(params[:url])

    # First we make sure that we haven't already downloaded this one
    if Playlist.where(name: metadata['fulltitle'])[0]
        puts 'Tape already downloaded'
        status 200
        json "This tape has already been downloaded!"
        return
    end

    # Make sure that we have enough metadata information to split the track
    if metadata['chapters'].nil?
        puts 'No chapters information - cannot continue'
        status 420
        json "There is not enough metadata to split this tape. Sorry!"
        return
    end

    puts 'Downloading...'
    filename = downloader.download_tape(params[:url])
    puts 'Splitting..'
    splitter.split_tape(filename, metadata)
    puts 'Complete'
end

post '/test/create_user' do

    unless params[:username].nil? || params[:password].nil?

        user = User.new
        user.username = params[:username]
        user.password = params[:password]
        user.token = SecureRandom.uuid

        if user.save
            response = {:token => user.token.to_s}
            json response
            status 200
        else
            status 201
        end
        
    end
end

post '/test/login' do
    unless params[:username].nil? || params[:password].nil?

        user = User.find_by(username: params[:username]);

        if user.try(:authenticate, params[:password])
            status 201
            token = SecureRandom.uuid

            user.update(token: token.to_s)

            response = {:token => token.to_s}
            json response
            #json 'Success'
        else
            status 201
            json 'Failure'
        end
    end

end

get '/test/test' do

    pp PlaylistTrack.where(playlist_id: 1)
    pp Track.where(id:279)
end

get '/test/playlist_tracks/:id' do

    tracks = PlaylistTrack.where(playlist_id: params[:id])

    tracks_data = []

    tracks.each do |track|
        detailed_track = Track.where(id: track.track_id)[0]
        tracks_data.push detailed_track
    end

    status 200
    json tracks_data
end

get '/test/playlists/:id' do

    playlist = Playlist.where(playlist_id: params[:id])[0]

    status 200
    json playlist

end



get '/test/playlists' do

    playlists = Playlist.all

    status 200
    json playlists
end

options "*" do
    response.headers["Allow"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
    response.headers["Access-Control-Allow-Origin"] = "*"
    200
end

