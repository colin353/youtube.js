# ----------------------------------
# Config and setup
# ----------------------------------
# Config and setup parameters

socket_url = 'http://192.168.0.104:8081'
size = {x: 436, y: 356 }
playerID = 'ytplayer';
video_media = []
playing_video = null
socket = null

allLoaded = no

# ----------------------------------
# YouTube API connections
# ----------------------------------

# This function actually connects the
# existing SWF object to a video.
embedYoutube = ->
	swfobject.embedSWF("http://www.youtube.com/apiplayer?enablejsapi=1&playerapiid=ytplayer&version=3",
                       "ytplayer", size.x, size.y, "8", null, null, { allowScriptAccess: 'always'} , {id: playerID });

# When the document loads, load a video (blank)
$ ->
	embedYoutube()

# This function is called by the
# youtube flash object when it is
# ready to go.
onYouTubePlayerReady = ->
	document.player = $('#'+playerID).get(0)
	document.player.playVideo()
	document.connectToServer()
	

video_not_yet_started = ->
	switch document.player.getPlayerState()
		when 1,2,3,5
			return no
		else
			return yes

# ----------------------------------
# Sockets and connections
# ----------------------------------
# Here we connect to the socket 
# interface and relaying data, etc.

document.connectToServer = ->
	socket = io.connect socket_url

	socket.on 'play', (data) ->
		console.log "Play detected",data
		document.player.playVideo()

	socket.on 'pause', (data) ->
		console.log "Pause detected",data
		document.player.pauseVideo()

	socket.on 'upcoming', (videos) ->
		console.log 'Got a new video list.'
		if(videos.length > 0 && video_not_yet_started())
			document.player.loadVideoById(videos[0].video_code);

		video_media = []
		$('.media-list').html(' ');	

		for v in videos.slice(1) 
			video_media.push new MediaInterfaceElement(v)

		playing_video = videos[0]

		setTimeout(renderUpcomingIfAvailable,200)

document.play = ->
	socket.emit 'play', {}

document.pause = ->
	socket.emit 'pause', {}

document.update = ->
	socket.emit 'update', {}

document.skip  = (vid=0) ->
	if vid == 0
		vid = playing_video 
		document.player.loadVideoById(video_media[0].video.video_code)
	socket.emit 'skip', vid

renderUpcomingIfAvailable = ->
	all_loaded = yes
	for v in video_media
		if v.loaded == no
			all_loaded = no
			break
	
	$('.media-list').html(' ')

	if all_loaded
		for v in video_media
			v.insert()

		setTimeout(onAllReady(),300) if !allLoaded
	else 
		setTimeout(renderUpcomingIfAvailable,200)

# ----------------------------------
# MediaInterfaceElements
# ----------------------------------
# Here we make a model for the
# MediaInterfaceElements that we are 
# going to be using in the HTML.

class MediaInterfaceElement
	constructor: (video) ->
		@video = video
		me = @
		me.loaded = no
		$.get "https://gdata.youtube.com/feeds/api/videos/#{@video.video_code}?v=2&alt=json", (r) ->
			me.description = r.valueOf('media$group').entry.media$group.media$description.$t.substring(0,140)
			me.title = r.valueOf('media$group').entry.title.$t.substring(0,64)
			me.loaded = yes

	render: ->
		html = 	'<li class="media well"><a class="pull-left" href="#">'
		html += "<img class='media-object' style='width:100px' src='http://img.youtube.com/vi/#{@video.video_code}/hqdefault.jpg'></a>"
		html += "<div class='media-body'><h4 class='media-heading'>#{@title}</h4><div class='media'>"
		html += "#{@description}</div></div></li>"
		#console.log 'attempting to render: ', html
		html

	insert: ->
		$('.media-list').append @render()

class VolumeController
	constructor: ->
		@percent = 80
		@setVolume @percent

	setVolume: (percent) ->
		@percent = percent
		$('.volume-control').css('width', "#{@percent}%")
		document.player.setVolume(@percent)



# ----------------------------------
# Startup animations and other stuff
# ----------------------------------
# Here we get other visual and aesthetic
# javascript, for example, animations.

onAllReady = ->
	$('.bigblock').fadeOut('slow');
	document.volume = new VolumeController()

	allLoaded = yes