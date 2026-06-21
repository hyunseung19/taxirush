import 'package:audioplayers/audioplayers.dart';

/// App-wide singleton controlling the looping background music track.
class BgmPlayer {
  BgmPlayer._();
  static final BgmPlayer instance = BgmPlayer._();

  final AudioPlayer _player = AudioPlayer();
  bool _prepared = false;
  bool _playing = false;

  Future<void> play() async {
    if (!_prepared) {
      _prepared = true;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.45);
      await _player.play(AssetSource('audio/bgm.wav'));
      _playing = true;
      return;
    }
    if (_playing) return;
    _playing = true;
    await _player.resume();
  }

  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    await _player.pause();
  }

  Future<void> stop() async {
    _prepared = false;
    _playing = false;
    await _player.stop();
  }
}
