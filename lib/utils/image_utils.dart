extension ImageResizeExtension on String {
  String resize({int? width, int? height}) {
    if (width == null && height == null) return this;
    final targetSize = width ?? height ?? 500;

    if (contains('i.ytimg.com')) {
      final targetQuality = (targetSize >= 1000)
          ? 'maxresdefault.jpg'
          : (targetSize <= 120)
              ? 'mqdefault.jpg'
              : 'hqdefault.jpg';
      return replaceAll(
        RegExp(r'(default|mqdefault|hqdefault|sddefault|maxresdefault)\.jpg'),
        targetQuality,
      );
    }

    if (contains('googleusercontent.com') && contains('=w')) {
      final baseUrl = split('=w')[0];
      final size = (targetSize >= 1000)
          ? 1080
          : (targetSize <= 240)
              ? targetSize
              : 500;
      return '$baseUrl=w$size-h$size-l90-rj';
    }

    if (contains('yt3.ggpht.com')) {
      final baseUrl = split('=')[0].split('-s')[0];
      final size = (targetSize >= 1000) ? 1080 : targetSize;
      return '$baseUrl=s$size';
    }

    return this;
  }
}

class ImageUtils {
  static String? highRes(String? url, {int size = 1080}) {
    if (url == null || url.isEmpty) return url;
    return url.resize(width: size, height: size);
  }
}
