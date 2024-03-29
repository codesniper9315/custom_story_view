import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

class VideoLoader {
  String url;

  File? videoFile;

  Map<String, dynamic>? requestHeaders;

  LoadState state = LoadState.loading;
  VideoFormat format = VideoFormat.other;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    var a = Uri.parse(this.url);
    var ext = a.pathSegments.last;
    if (ext.endsWith('m3u8')) {
      this.format = VideoFormat.hls;
    } else {
      this.format = VideoFormat.other;
    }
    if (this.format == VideoFormat.hls) {
      this.state = LoadState.success;
      this.videoFile = null;
      onComplete();
      return;
    }
    if (this.videoFile != null) {
      this.state = LoadState.success;
      onComplete();
      return;
    }

    final fileStream = DefaultCacheManager().getFileStream(
      this.url,
      headers: this.requestHeaders as Map<String, String>?,
    );

    fileStream.listen((fileResponse) {
      if (fileResponse is FileInfo) {
        if (this.videoFile == null) {
          this.state = LoadState.success;
          this.videoFile = fileResponse.file;
          onComplete();
        }
      }
    });
  }
}

class StoryVideo extends StatefulWidget {
  final File? file;
  final StoryController? storyController;
  final VideoLoader? videoLoader;
  final String? thumbnail;
  final double width;
  final double height;

  StoryVideo(
    this.width,
    this.height, {
    this.storyController,
    this.videoLoader,
    this.file,
    this.thumbnail,
    Key? key,
  }) : super(key: key ?? UniqueKey());

  static StoryVideo local(
    File file,
    double width,
    double height, {
    StoryController? controller,
    Key? key,
  }) {
    return StoryVideo(
      width,
      height,
      file: file,
      storyController: controller,
      key: key,
    );
  }

  static StoryVideo url(
    String url,
    String thumbnail,
    double width,
    double height, {
    StoryController? controller,
    Map<String, dynamic>? requestHeaders,
    Key? key,
  }) {
    return StoryVideo(
      width,
      height,
      videoLoader: VideoLoader(url, requestHeaders: requestHeaders),
      thumbnail: thumbnail,
      storyController: controller,
      key: key,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void>? playerLoader;

  StreamSubscription? _streamSubscription;

  VideoPlayerController? playerController;

  @override
  void initState() {
    super.initState();

    widget.storyController!.pause();

    if (widget.videoLoader != null) {
      widget.videoLoader!.loadVideo(() {
        if (widget.videoLoader!.state == LoadState.success) {
          if (widget.videoLoader!.videoFile != null) {
            this.playerController =
                VideoPlayerController.file(widget.videoLoader!.videoFile!);
          } else {
            this.playerController = VideoPlayerController.network(
              widget.videoLoader!.url,
              formatHint: VideoFormat.hls,
            );
          }
          _initializeVideoPlayer();
        } else {
          setState(() {});
        }
      });
    } else if (widget.file != null) {
      this.playerController = VideoPlayerController.file(widget.file!);
      _initializeVideoPlayer();
    }
  }

  _initializeVideoPlayer() {
    playerController!.initialize().then((v) {
      setState(() {});
      widget.storyController!.play();
    });

    if (widget.storyController != null) {
      _streamSubscription =
          widget.storyController!.playbackNotifier.listen((playbackState) {
        if (playbackState == PlaybackState.pause) {
          playerController!.pause();
        } else {
          playerController!.play();
        }
      });
    }
  }

  Widget getContentView() {
    if (playerController != null && playerController!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: playerController!.value.aspectRatio,
          child: VideoPlayer(playerController!),
        ),
      );
    }

    if (widget.file != null || widget.thumbnail == null) return Container();

    return widget.videoLoader != null &&
            (widget.videoLoader!.format == VideoFormat.hls ||
                widget.videoLoader!.state == LoadState.loading)
        ? SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              children: [
                Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(widget.thumbnail!),
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
                // Center(
                //   child: Container(
                //     width: 70,
                //     height: 70,
                //     child: CircularProgressIndicator(
                //       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                //       strokeWidth: 3,
                //     ),
                //   ),
                // ),
              ],
            ),
          )
        : Center(
            child: Text(
              "Media failed to load.",
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: double.infinity,
      width: double.infinity,
      child: getContentView(),
    );
  }

  @override
  void dispose() {
    playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
