package org.mangui.hls {
import flash.events.NetStatusEvent;
import flash.net.NetConnection;

import org.mangui.hls.constant.HLSPlayStates;
import org.mangui.hls.event.HLSEvent;
import org.mangui.hls.stream.HLSNetStream;

public class ZeroConfigHLSNetStream extends HLSNetStream {
    private static function createNetConnection():NetConnection {
        var connection : NetConnection = new NetConnection();
        connection.connect(null);
        return connection;
    }

    private static const MAX_PAUSE_DELAY:int = 20000;

    private var _zeroHLS:ZeroConfigHLS;

    private var _lastPlaylist:String;
    private var _manifestLoaded:Boolean;
    private var _pauseBeforeManifestLoaded:Boolean;
    private var _lastPauseTime:Number;

    private var _seekPosition:Number;

    public function ZeroConfigHLSNetStream() {
        super(createNetConnection(), (ZeroConfigHLS._netStream = this, _zeroHLS = new ZeroConfigHLS()), _zeroHLS._streamBuffer);
        _zeroHLS.addEventListener(HLSEvent.MANIFEST_LOADED, onManifestLoaded);
        _zeroHLS.addEventListener(HLSEvent.PLAYBACK_STATE, onPlaybackStateChange);
        _zeroHLS.addEventListener(HLSEvent.PLAYBACK_COMPLETE, onPlaybackComplete);
        _zeroHLS.addEventListener(HLSEvent.ERROR, onHlsError);
    }

    override public function play(...rest):void {
        if (rest[0] != _lastPlaylist || currentTimestamp - _lastPauseTime >= MAX_PAUSE_DELAY) {
            _lastPlaylist = rest[0];
            _zeroHLS.load(_lastPlaylist);
        } else if (_lastPlaylist) {
            super.resume();
        }
    }

    override public function pause():void {
        trace("HLS Pause. Playback state: " + playbackState);
        if (!_manifestLoaded) {
            _pauseBeforeManifestLoaded = true;
        }
        _lastPauseTime = currentTimestamp;
        super.pause();
    }

    override public function resume():void {
        if (_pauseBeforeManifestLoaded) {
            _pauseBeforeManifestLoaded = false;
            super.play(null, -1);
        } else {
            super.resume();
        }
    }

    override public function seek(position:Number):void {
        if (playbackState == HLSPlayStates.IDLE) {
            if (position > 0) {
                _seekPosition = position;
                return;
            }
        }

        super.seek(position);
    }

    override public function get time():Number {
        if (!isNaN(_seekPosition)) {
            return _seekPosition;
        }

        return _zeroHLS.position;
    }

    private function onPlaybackStateChange(event:HLSEvent):void {
        if (playbackState != HLSPlayStates.IDLE && !isNaN(_seekPosition)) {
            seek(_seekPosition);
            _seekPosition = NaN;
        }
    }

    private function onManifestLoaded(event:HLSEvent):void {
        _manifestLoaded = true;
        if (!_pauseBeforeManifestLoaded) {
            super.play(null, -1);
        }
    }

    private function onPlaybackComplete(event:HLSEvent):void {
        dispatchEvent(new NetStatusEvent(NetStatusEvent.NET_STATUS, false, false, {
            level: "status",
            code: "NetStream.Play.Stop"
        }));
    }

    private function onHlsError(event:HLSEvent):void {
        dispatchEvent(new NetStatusEvent(NetStatusEvent.NET_STATUS, false, false, {
            level: "status",
            code: "NetStream.Play.StreamNotFound",
            details: event.error.toString()
        }));
    }

    public function get hls():HLS {
        return _zeroHLS;
    }

    private function get currentTimestamp():Number {
        return (new Date()).valueOf();
    }
}
}

import org.mangui.hls.HLS;
import org.mangui.hls.ZeroConfigHLSNetStream;
import org.mangui.hls.model.Fragment;
import org.mangui.hls.model.Level;
import org.mangui.hls.stream.HLSNetStream;

class ZeroConfigHLS extends HLS {
    public static var _netStream:ZeroConfigHLSNetStream;

    public function ZeroConfigHLS() {
    }

    override protected function createNetStream():HLSNetStream {
        return _netStream;
    }

    public function get positionUtc():Number {
        if (!levels || !levels.length || !levels[currentLevel]) {
            return 0;
        }
        var level:Level = levels[currentLevel];
        var fragment:Fragment = level.fragments[0];

        if (!fragment || !fragment.program_date) {
            return 0;
        }

        return Math.floor((position * 1000  + fragment.program_date + fragment.start_time * 1000) / 1000);
    }
}
