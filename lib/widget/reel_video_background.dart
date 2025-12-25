import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelVideoBackground extends StatefulWidget {
  const ReelVideoBackground({
    super.key,
    required this.videoFileName,
    this.onControllerCreated,
  });

  final String videoFileName;
  final ValueChanged<VideoPlayerController?>? onControllerCreated;

  @override
  State<ReelVideoBackground> createState() => _ReelVideoBackgroundState();
}

class _ReelVideoBackgroundState extends State<ReelVideoBackground>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(ReelVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoFileName != widget.videoFileName) {
      _controller?.dispose();
      _controller = null;
      _loading = true;
      _error = null;
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    if (widget.videoFileName.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('chalets_videos/${widget.videoFileName}');
      final url = await ref.getDownloadURL();

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));

      await controller.initialize();

      controller
        ..setLooping(true)
        ..setVolume(1.0)
        ..play();

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
      });

      widget.onControllerCreated?.call(controller);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_loading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      // Show placeholder when video is missing or failed to load
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: _error == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.videocam_off,
                    color: Colors.white38,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا يوجد فيديو',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white54,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'فشل تحميل الفيديو',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}