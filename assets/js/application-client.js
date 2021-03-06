// Generated by CoffeeScript 1.6.2
var MediaInterfaceElement, VolumeController, allLoaded, isNoLongerPlaying, isPlaying, newMainVideoLoaded, onAllReady, playing_video, renderUpcomingIfAvailable, socket, socket_url, video_media, volumeDetector;

socket_url = 'http://192.168.0.104:8081';

video_media = [];

playing_video = null;

socket = null;

allLoaded = false;

document.connectToServer = function() {
  socket = io.connect(socket_url);
  socket.on('play', function(data) {
    console.log("Play detected", data);
    return isPlaying();
  });
  socket.on('pause', function(data) {
    console.log("Pause detected", data);
    return isNoLongerPlaying();
  });
  socket.on('volume', function(vol) {
    console.log("Volume change detected ", vol);
    return document.volume.setVolume(vol);
  });
  return socket.on('upcoming', function(videos) {
    var v, _i, _len, _ref;

    console.log('Got a new video list.');
    playing_video = videos[0];
    if (videos.length > 0) {
      newMainVideoLoaded(videos[0]);
    }
    video_media = [];
    $('.media-list').html(' ');
    _ref = videos.slice(1);
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      v = _ref[_i];
      video_media.push(new MediaInterfaceElement(v));
    }
    return setTimeout(renderUpcomingIfAvailable, 200);
  });
};

document.play = function() {
  return socket.emit('play', {});
};

document.pause = function() {
  return socket.emit('pause', {});
};

document.update = function() {
  return socket.emit('update', {});
};

document.setVolume = function(vol) {
  return socket.emit('volume', vol);
};

document.skip = function() {
  var vid;

  vid = playing_video;
  return socket.emit('skip', vid);
};

$(function() {
  return document.connectToServer();
});

renderUpcomingIfAvailable = function() {
  var all_loaded, v, _i, _j, _len, _len1;

  all_loaded = true;
  for (_i = 0, _len = video_media.length; _i < _len; _i++) {
    v = video_media[_i];
    if (v.loaded === false) {
      all_loaded = false;
      break;
    }
  }
  $('.media-list').html(' ');
  if (all_loaded) {
    for (_j = 0, _len1 = video_media.length; _j < _len1; _j++) {
      v = video_media[_j];
      v.insert();
    }
    if (!allLoaded) {
      return setTimeout(onAllReady(), 300);
    }
  } else {
    return setTimeout(renderUpcomingIfAvailable, 200);
  }
};

MediaInterfaceElement = (function() {
  function MediaInterfaceElement(video) {
    var me;

    this.video = video;
    me = this;
    me.loaded = false;
    $.get("https://gdata.youtube.com/feeds/api/videos/" + this.video.video_code + "?v=2&alt=json", function(r) {
      me.description = r.valueOf('media$group').entry.media$group.media$description.$t.substring(0, 140);
      me.title = r.valueOf('media$group').entry.title.$t.substring(0, 64);
      return me.loaded = true;
    });
  }

  MediaInterfaceElement.prototype.render = function() {
    var html;

    html = '<li class="media well"><a class="pull-left" href="#">';
    html += "<img class='media-object' style='width:100px' src='http://img.youtube.com/vi/" + this.video.video_code + "/hqdefault.jpg'></a>";
    html += "<div class='media-body'><h4 class='media-heading'>" + this.title + "</h4><div class='media'>";
    html += "" + this.description + "</div></div></li>";
    return html;
  };

  MediaInterfaceElement.prototype.insert = function() {
    return $('.media-list').append(this.render());
  };

  return MediaInterfaceElement;

})();

VolumeController = (function() {
  function VolumeController() {
    this.percent = 80;
    this.setVolume(this.percent);
  }

  VolumeController.prototype.setVolume = function(percent) {
    this.percent = percent;
    return $('.volume-control').css('width', "" + this.percent + "%");
  };

  return VolumeController;

})();

volumeDetector = function(e) {
  var x, x_o, y, y_o;

  x_o = this.offsetLeft - this.scrollLeft;
  y_o = this.offsetTop - this.scrollTop;
  x = e.pageX - x_o;
  y = e.pageY - y_o;
  return document.setVolume(x / 3);
};

newMainVideoLoaded = function() {
  var z, z_checker;

  z = new MediaInterfaceElement(playing_video);
  z_checker = function() {
    if (z.loaded) {
      return $('.nowplaying').html(z.render());
    } else {
      return setTimeout(z_checker, 200);
    }
  };
  return setTimeout(z_checker, 200);
};

isPlaying = function() {
  $('.play-control').hide();
  return $('.pause-control').show();
};

isNoLongerPlaying = function() {
  $('.play-control').show();
  return $('.pause-control').hide();
};

onAllReady = function() {
  $('.bigblock').fadeOut('slow');
  document.volume = new VolumeController();
  allLoaded = true;
  $('.volume-container').click(volumeDetector);
  $('.pause-control').click(document.pause);
  $('.skip-control').click(document.skip);
  return $('.play-control').click(document.play);
};

document.addNewVideoViaModal = function() {
  var video_code;

  video_code = $('#ytvideomodal').val();
  $(".new-video-modal").modal("hide");
  return socket.emit('add', {
    video_code: video_code
  });
};
