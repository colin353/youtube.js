# ----------------------------------
# Config + Require
# ----------------------------------
# The list of settings required to run
# this application, and included libs.

http 	= require 'http'
fs 		= require 'fs'
io		= require 'socket.io'
mysql	= require('mysql')

# Setup database connection

db = mysql.createConnection {
	host: 		'localhost',
	user: 		'root',
	password: 	'bitnami',
	database:	'video'
}

db.connect (err) ->
	throw err if err

# Setup socket connection

io = io.listen(8081)

# ----------------------------------
# Migration testing
# ----------------------------------
# This component tests if migration is
# necessary (checking for the existance
# of tables, etc.) and if so runs it.

db.query "CREATE TABLE IF NOT EXISTS `videos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `video_code` varchar(64) NOT NULL,
  `last_played` timestamp NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"

# ----------------------------------
# HTTP Server
# ----------------------------------
# This component actually serves assets
# and html content to the browser.

viewmap	= {
	index:	'views/client.html',
	client: 'views/client.html',
	server: 'views/server.html'
}

HTTPServer = http.createServer (req, res) ->
	res.writeHead 200, {'Content-type': 'text/html'};
	url = req.url.slice 1
	url = 'index' if url == ''

	if viewmap.hasOwnProperty url 
		res.end fs.readFileSync viewmap[url]
	else if url.split('/')[0] == 'assets' 
		try
			content = fs.readFileSync url
			res.end content
		catch e
			res.end fs.readFileSync 'views/404.html' 
	else
		res.end fs.readFileSync 'views/404.html' 

HTTPServer.listen(8080);

# ----------------------------------
# Database models
# ----------------------------------
# These models actually do the heavy
# lifting of interacting with the 
# database.

class Video 
	# Static methods:

	@get: (callback) ->
		retval = [];

		db.query "select * from videos order by last_played = '0000-00-00 00:00:00' desc, last_played asc limit 4", (err, result) ->
			throw err if err
			for row in result
				retval.push new Video(row.id)

			f = ->
				loaded = yes
				for v in retval
					if v.loaded == no
						loaded = no
						break

				if loaded
					callback(retval)
				else
					setTimeout(f,200)

			setTimeout(f,200)

	# Object-bound methods

	constructor: (id = 0, callback) ->
		if id != 0
			# Then the user must have provided an ID to load from
			@id = id
			@loaded = false
			me = @
			db.query "select * from videos where id = #{@id}", (err, result) ->
				throw err if err
				me.last_played 	= result[0].last_played
				me.video_code	= result[0].video_code
				me.loaded 		= yes
				callback() if callback?
			@saved = yes
		else
			# Then the user must want to make a new one.
			@id = 0
			@saved = no

	save: (callback) ->
		if @saved
			me = @
			db.query "update videos set video_code = '#{@video_code}' where id = #{@id}", (err, result) ->
				throw err if err
				me.id = result.insertId
				callback() if callback?
		else
			db.query "insert into videos (video_code) value ('#{@video_code}')"
			@saved = yes
			callback() if callback?

	updatePlayedTime: ->
		db.query "update videos set last_played = NOW() where id = #{@id}"

# ----------------------------------
# Socket IO
# ----------------------------------
# Here we do the socket IO interface
# for the clients. We distribute video
# codes, do updates, broadcast messages
# etc.

sockets = []

io.sockets.on 'connection', (socket) ->
	socket.connected = no

	sockets.push socket

	Video.get (v) ->
		socket.emit 'upcoming', v

	socket.on 'end', ->
		# When a socket is terminated, remove
		# from the listening array.
		console.log 'The connection is closed'
		i = sockets.indexOf socket
		sockets.splice i,1

	socket.on 'play', (message) ->
		# When somebody says play video
		console.log "Somebody says: play"

		for s in sockets
			s.emit 'play', '0'

	socket.on 'pause', ->
		# When somebody says pause video
		console.log "Somebody says: pause"

		for s in sockets
			s.emit 'pause', '0'

	socket.on 'skip', (video) ->
		# When somebody wants to skip the video
		# for one or another reason

		v = new Video video.id, ->
			v.updatePlayedTime()
			setTimeout(massUpdate,500)

		for s in sockets
			s.emit 'skipped', video.video_code

	socket.on 'volume', (volume) ->
		# When somebody says pause video
		console.log "Somebody changed volume to:"
		console.log volume

		for s in sockets
			s.emit 'volume', volume

	socket.on 'add', (video) ->
		# When somebody says pause video
		console.log "Somebody added new video ", video.video_code

		v = new Video()
		v.video_code = video.video_code
		v.save ->
			for s in sockets
				s.emit 'added', v

		# Push a mass-update in half a second.
		setTimeout(massUpdate,500)

	socket.on 'update', ->
		console.log "Recieved request for playlist update"
		Video.get (v) ->
			socket.emit 'upcoming', v

massUpdate = ->
	Video.get (v) ->
		for s in sockets
			s.emit 'upcoming', v