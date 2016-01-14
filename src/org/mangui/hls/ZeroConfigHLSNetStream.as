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

    private var _zeroHLS:ZeroConfigHLS;

    private var _seekPosition:Number = NaN;

    public function ZeroConfigHLSNetStream() {
        super(createNetConnection(), (ZeroConfigHLS._netStream = this, _zeroHLS = new ZeroConfigHLS()), _zeroHLS._streamBuffer);
        _zeroHLS.addEventListener(HLSEvent.MANIFEST_LOADED, onManifestLoaded);
        _zeroHLS.addEventListener(HLSEvent.PLAYBACK_STATE, onPlaybackStateChange);
        _zeroHLS.addEventListener(HLSEvent.PLAYBACK_COMPLETE, onPlaybackComplete);
        _zeroHLS.addEventListener(HLSEvent.ERROR, onHlsError);
    }

    override public function play(...rest):void {
        var file:String = rest[0];
        _seekPosition = NaN;
        _zeroHLS.load(file);
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
        super.play(null, -1);
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
}
}

import org.mangui.hls.HLS;
import org.mangui.hls.ZeroConfigHLSNetStream;
import org.mangui.hls.stream.HLSNetStream;

class ZeroConfigHLS extends HLS {
    public static var _netStream:ZeroConfigHLSNetStream;

    public function ZeroConfigHLS() {
    }

    override protected function createNetStream():HLSNetStream {
        return _netStream;
    }
}
