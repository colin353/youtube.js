# ----------------------------------
# Config and setup
# ----------------------------------
# Config and setup parameters

socket_url = 'http://192.168.0.104:8081'
video_media = []
playing_video = null
socket = null

allLoaded = no

# ----------------------------------
# Sockets and connections
# ----------------------------------
# Here we connect to the socket 
# interface and relaying data, etc.

document.connectToServer = ->
	socket = io.connect socket_url

	socket.on 'play', (data) ->
		console.log "Play detected",data
		isPlaying()

	socket.on 'pause', (data) ->
		console.log "Pause detected",data
		isNoLongerPlaying()

	socket.on 'volume', (vol) ->
		console.log "Volume change detected ",vol
		document.volume.setVolume(vol)


	socket.on 'upcoming', (videos) ->
		console.log 'Got a new video list.'

		playing_video = videos[0]

		if(videos.length > 0)
			newMainVideoLoaded(videos[0]);

		video_media = []
		$('.media-list').html(' ');	

		for v in videos.slice(1) 
			video_media.push new MediaInterfaceElement(v)

		setTimeout(renderUpcomingIfAvailable,200)

document.play = ->
	socket.emit 'play', {}

document.pause = ->
	socket.emit 'pause', {}

document.update = ->
	socket.emit 'update', {}

document.setVolume = (vol) ->
	socket.emit 'volume', vol

document.skip  =  ->
	vid = playing_video 
	socket.emit 'skip', vid

$ -> 
	document.connectToServer()

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

volumeDetector = (e) ->
	x_o = @offsetLeft - @scrollLeft
	y_o = @offsetTop  - @scrollTop

	x = e.pageX - x_o
	y = e.pageY - y_o

	document.setVolume(x / 3)

# ----------------------------------
# Startup animations and other stuff
# ----------------------------------
# Here we get other visual and aesthetic
# javascript, for example, animations.

newMainVideoLoaded = ->
	z = new MediaInterfaceElement(playing_video)

	z_checker = ->
		if z.loaded
			$('.nowplaying').html z.render()
		else 
			setTimeout z_checker,200

	setTimeout z_checker,200

isPlaying = ->
	$('.play-control').hide()
	$('.pause-control').show() 

isNoLongerPlaying = ->
	$('.play-control').show()
	$('.pause-control').hide()

onAllReady = ->
	$('.bigblock').fadeOut('slow');
	document.volume = new VolumeController()

	allLoaded = yes

	$('.volume-container').click volumeDetector
	$('.pause-control').click document.pause
	$('.skip-control').click document.skip
	$('.play-control').click document.play

document.addNewVideoViaModal = ->
	video_code = $('#ytvideomodal').val()
	$(".new-video-modal").modal("hide")
	socket.emit 'add', { video_code: video_code }