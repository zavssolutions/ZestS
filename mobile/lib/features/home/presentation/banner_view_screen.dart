import "dart:io";
import "dart:typed_data";

import "package:cached_network_image/cached_network_image.dart";
import "package:dio/dio.dart";
import "package:flutter/services.dart";
import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

class BannerViewArgs {
  const BannerViewArgs({
    required this.title,
    required this.image,
    required this.isAsset,
    this.deepLinkUrl,
    this.shareText,
    this.shareUrl,
  });

  final String title;
  final String image;
  final bool isAsset;
  final String? deepLinkUrl;
  final String? shareText;
  final String? shareUrl;
}

class BannerViewScreen extends StatelessWidget {
  const BannerViewScreen({required this.args, super.key});

  final BannerViewArgs args;

  Future<Uint8List> _loadImageBytes() async {
    if (args.isAsset) {
      final bytes = await rootBundle.load(args.image);
      return bytes.buffer.asUint8List();
    }
    final response = await Dio().get<List<int>>(
      args.image,
      options: Options(responseType: ResponseType.bytes, followRedirects: true),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  String _guessExtension() {
    final lower = args.image.toLowerCase();
    if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "jpg";
    if (lower.endsWith(".webp")) return "webp";
    return "png";
  }

  Future<void> _share(BuildContext context) async {
    try {
      final bytes = await _loadImageBytes();
      if (bytes.isEmpty) {
        throw Exception("Empty image");
      }

      final tmp = await getTemporaryDirectory();
      final ext = _guessExtension();
      final file = File("${tmp.path}${Platform.pathSeparator}zests_banner.$ext");
      await file.writeAsBytes(bytes, flush: true);

      final textParts = <String>[
        if ((args.shareText ?? "").trim().isNotEmpty) args.shareText!.trim(),
        if ((args.shareUrl ?? args.deepLinkUrl ?? "").trim().isNotEmpty)
          (args.shareUrl ?? args.deepLinkUrl!).trim(),
      ];
      final text = textParts.join("\n");

      await Share.shareXFiles(
        [XFile(file.path, mimeType: "image/$ext")],
        text: text.isEmpty ? null : text,
      );
    } catch (_) {
      final fallback = [
        if ((args.shareText ?? "").trim().isNotEmpty) args.shareText!.trim(),
        if ((args.shareUrl ?? args.deepLinkUrl ?? "").trim().isNotEmpty)
          (args.shareUrl ?? args.deepLinkUrl!).trim(),
      ].join("\n");

      if (fallback.trim().isNotEmpty) {
        await Share.share(fallback.trim());
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to share this banner right now.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(args.title),
        actions: [
          IconButton(
            tooltip: "Share",
            onPressed: () => _share(context),
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _share(context),
          child: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: args.isAsset
                  ? Image.asset(args.image, fit: BoxFit.contain)
                  : CachedNetworkImage(imageUrl: args.image, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

