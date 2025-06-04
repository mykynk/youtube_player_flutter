// Copyright 2020 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../enums/player_state.dart';
import '../utils/youtube_meta_data.dart';
import '../utils/youtube_player_controller.dart';

/// A raw youtube player widget which interacts with the underlying webview inorder to play YouTube videos.
///
/// Use [YoutubePlayer] instead.
class RawYoutubePlayer extends StatefulWidget {
  /// Creates a [RawYoutubePlayer] widget.
  const RawYoutubePlayer({
    super.key,
    this.onEnded,
  });

  /// {@macro youtube_player_flutter.onEnded}
  final void Function(YoutubeMetaData metaData)? onEnded;

  @override
  State<RawYoutubePlayer> createState() => _RawYoutubePlayerState();
}

class _RawYoutubePlayerState extends State<RawYoutubePlayer>
    with WidgetsBindingObserver {
  YoutubePlayerController? controller;
  PlayerState? _cachedPlayerState;
  bool _isPlayerReady = false;
  bool _onLoadStopCalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_cachedPlayerState != null &&
            _cachedPlayerState == PlayerState.playing) {
          controller?.play();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        _cachedPlayerState = controller!.value.playerState;
        controller?.pause();
        break;
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    controller = YoutubePlayerController.of(context);
    return IgnorePointer(
      ignoring: true,
      child: InAppWebView(
        key: widget.key,
        initialData: InAppWebViewInitialData(
          data: player,
          baseUrl: WebUri.uri(Uri.https('www.youtube.com')),
          encoding: 'utf-8',
          mimeType: 'text/html',
        ),
        initialSettings: InAppWebViewSettings(
          userAgent: userAgent,
          mediaPlaybackRequiresUserGesture: false,
          transparentBackground: true,
          disableContextMenu: true,
          supportZoom: false,
          disableHorizontalScroll: false,
          disableVerticalScroll: false,
          allowsInlineMediaPlayback: true,
          allowsAirPlayForMediaPlayback: true,
          allowsPictureInPictureMediaPlayback: true,
          useWideViewPort: false,
          useHybridComposition: controller!.flags.useHybridComposition,
        ),
        onWebViewCreated: (webController) {
          controller!.updateValue(
            controller!.value.copyWith(webViewController: webController),
          );
          webController
            ..addJavaScriptHandler(
              handlerName: 'Ready',
              callback: (_) {
                _isPlayerReady = true;
                if (_onLoadStopCalled) {
                  controller!.updateValue(
                    controller!.value.copyWith(isReady: true),
                  );
                }
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'StateChange',
              callback: (args) {
                switch (args.first as int) {
                  case -1:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.unStarted,
                        isLoaded: true,
                      ),
                    );
                    break;
                  case 0:
                    widget.onEnded?.call(controller!.metadata);
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.ended,
                      ),
                    );
                    break;
                  case 1:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.playing,
                        isPlaying: true,
                        hasPlayed: true,
                        errorCode: 0,
                      ),
                    );
                    break;
                  case 2:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.paused,
                        isPlaying: false,
                      ),
                    );
                    break;
                  case 3:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.buffering,
                      ),
                    );
                    break;
                  case 5:
                    controller!.updateValue(
                      controller!.value.copyWith(
                        playerState: PlayerState.cued,
                      ),
                    );
                    break;
                  default:
                    throw Exception("Invalid player state obtained.");
                }
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'PlaybackQualityChange',
              callback: (args) {
                controller!.updateValue(
                  controller!.value
                      .copyWith(playbackQuality: args.first as String),
                );
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'PlaybackRateChange',
              callback: (args) {
                final num rate = args.first;
                controller!.updateValue(
                  controller!.value.copyWith(playbackRate: rate.toDouble()),
                );
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'Errors',
              callback: (args) {
                controller!.updateValue(
                  controller!.value.copyWith(errorCode: int.parse(args.first)),
                );
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'VideoData',
              callback: (args) {
                controller!.updateValue(
                  controller!.value.copyWith(
                      metaData: YoutubeMetaData.fromRawData(args.first)),
                );
              },
            )
            ..addJavaScriptHandler(
              handlerName: 'VideoTime',
              callback: (args) {
                final position = args.first * 1000;
                final num buffered = args.last;
                controller!.updateValue(
                  controller!.value.copyWith(
                    position: Duration(milliseconds: position.floor()),
                    buffered: buffered.toDouble(),
                  ),
                );
              },
            );
        },
        onLoadStop: (_, __) {
          _onLoadStopCalled = true;
          if (_isPlayerReady) {
            controller!.updateValue(
              controller!.value.copyWith(isReady: true),
            );
          }
        },
      ),
    );
  }

  String get player => '''
    <!DOCTYPE html>
<html lang="en">
  <head>
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
    />
    <style>
      html {
        width: 100%;
        height: 100%;
        background-color: black;
        pointer-events: <<pointerEvents>>;
      }

      body {
        margin: 0;
        width: 100%;
        height: 100%;
        background-color: black;
        pointer-events: inherit;
      }

      .embed-container iframe,
      .embed-container object,
      .embed-container embed {
        position: absolute;
        top: 0;
        left: 0;
        width: 100% !important;
        height: 100% !important;
        pointer-events: inherit;
      }
    </style>
    <title>Youtube Player</title>
  </head>
    <body>
        <div class="embed-container">
          <div id="player"></div>
        </div>
        <script>
            var tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            var firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
            var player;
            var timerId;
            function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                    height: '100%',
                    width: '100%',
                    host: 'https://www.youtube.com',
                    videoId: '${controller!.initialVideoId}',
                    playerVars: {
                        'controls': 0,
                        'playsinline': 1,
                        'enablejsapi': 1,
                        'fs': 0,
                        'rel': 0,
                        'showinfo': 0,
                        'iv_load_policy': 3,
                        'modestbranding': 1,
                        'cc_load_policy': ${boolean(value: controller!.flags.enableCaption)},
                        'cc_lang_pref': '${controller!.flags.captionLanguage}',
                        'autoplay': ${boolean(value: controller!.flags.autoPlay)},
                        'start': ${controller!.flags.startAt},
                        'end': ${controller!.flags.endAt},
                        'hl': '${controller!.flags.interfaceLanguage}'
                    },
                  events: {
                    onReady: function (event) {
                      handleFullScreenForMobilePlatform();
                      sendMessage('Ready', event);
                    },
                    onStateChange: function (event) {
                      clearTimeout(timerId);
                      sendMessage('StateChange', event.data);
                      if (event.data == 1) {
                        timerId = setInterval(function () {
                          var state = {
                            'currentTime': player.getCurrentTime(),
                            'loadedFraction': player.getVideoLoadedFraction()
                          };

                          sendMessage('VideoState', JSON.stringify(state));
                        }, 100);
                      }
                    },
                    onPlaybackQualityChange: function (event) {
                      sendMessage('PlaybackQualityChange', event.data);
                    },
                    onPlaybackRateChange: function (event) {
                      sendMessage('PlaybackRateChange', event.data);
                    },
                    onApiChange: function (event) {
                      sendMessage('ApiChange', event.data);
                    },
                    onError: function (event) {
                      sendMessage('PlayerError', event.data);
                    },
                    onAutoplayBlocked: function (event) {
                      sendMessage('AutoplayBlocked', event.data);
                    },
                  },
                });
            }
  window.addEventListener('message', (event) => {
        try {
          var data = JSON.parse(event.data);

          if(data.function){
            var rawFunction = data.function.replaceAll('<<quote>>', '"');
            var result = eval(rawFunction);

            if(data.key) {
              var message = {}
              message[data.key] = result
              var messageString = JSON.stringify(message);

              event.source.postMessage(messageString , '*');
            }
          }
        } catch (e) { }
      }, false);

      window.onresize = function () {
        player.setSize(window.innerWidth, window.innerHeight);
      };

      function sendPlatformMessage(message) {
        switch(platform) {
           case 'android':
             <<playerId>>.postMessage(message);
             break;
           case 'ios':
             <<playerId>>.postMessage(message, '*');
             break;
           case 'web':
             window.parent.postMessage(message, '*');
             break;
         }
      }

      function sendMessage(key, data) {
         var message = {};
         message[key] = data;
         message['playerId'] = '<<playerId>>';
         var messageString = JSON.stringify(message);

         sendPlatformMessage(messageString);
      }

      function getVideoData() {
        return prepareDataForPlatform(player.getVideoData());
      }

      function getPlaylist() {
        return prepareDataForPlatform(player.getPlaylist());
      }

      function getAvailablePlaybackRates(){
        return prepareDataForPlatform(player.getAvailablePlaybackRates());
      }

      function prepareDataForPlatform(data) {
        if(platform == 'android') return data;

        return JSON.stringify(data);
      }

      function handleFullScreenForMobilePlatform() {
        if(platform != 'web') {
          var ytFrame = document.getElementsByTagName('iframe')[0].contentWindow.document;
          var fsButton = ytFrame.getElementsByClassName('ytp-fullscreen-button ytp-button')[0];

          if(fsButton != null) {
            var fsButtonCopy = fsButton.cloneNode(true);
            fsButton.replaceWith(fsButtonCopy);
            fsButtonCopy.onclick = function() {
              sendMessage('FullscreenButtonPressed', '');
            };
          }
        }
      }
    </script>
  </body>
</html>

  ''';

  String boolean({required bool value}) => value == true ? "'1'" : "'0'";

  String get userAgent => controller!.flags.forceHD
      ? 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36'
      : '';
}
