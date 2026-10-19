import 'package:flutter/foundation.dart';

/// Bus de errores de reproducción en stream para mostrar feedback en la UI.
///
/// El handler de audio reporta aquí los fallos (stream no obtenido, fallo de
/// recuperación, etc.) y la app muestra un SnackBar. Sin esto, los errores
/// quedaban solo en `debugPrint` y el usuario veía silencio total.
class StreamErrorBus {
  static final ValueNotifier<String?> ultimoError = ValueNotifier<String?>(null);

  /// Reporta un error. Fuerza re-emisión incluso si el mensaje es idéntico al
  /// anterior (primero se limpia y luego se asigna).
  static void report(String message) {
    ultimoError.value = null;
    ultimoError.value = message;
  }

  static void clear() => ultimoError.value = null;
}
