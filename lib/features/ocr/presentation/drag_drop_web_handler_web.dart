// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

typedef WebDropFileCallback = void Function(
    Uint8List bytes, String fileName, String mimeType);

html.EventListener? _dragOverListener;
html.EventListener? _dropListener;
html.EventListener? _dragEnterListener;
html.EventListener? _dragLeaveListener;
WebDropFileCallback? _onFileDrop;
void Function()? _onEnterCallback;
void Function()? _onLeaveCallback;

void registerWebDropHandler(
  WebDropFileCallback onFileDrop, {
  void Function()? onEnter,
  void Function()? onLeave,
}) {
  unregisterWebDropHandler();

  _onFileDrop = onFileDrop;
  _onEnterCallback = onEnter;
  _onLeaveCallback = onLeave;

  _dragOverListener = (html.Event event) {
    event.preventDefault();
    event.stopPropagation();
    final dataTransfer = (event as dynamic).dataTransfer;
    if (dataTransfer != null) {
      dataTransfer.dropEffect = 'copy';
    }
  };

  _dropListener = (html.Event event) {
    event.preventDefault();
    event.stopPropagation();
    _onLeaveCallback?.call();

    final files = (event as dynamic).dataTransfer?.files;
    if (files != null && files.isNotEmpty) {
      _handleFile(files.first);
    }
  };

  _dragEnterListener = (html.Event event) {
    event.preventDefault();
    event.stopPropagation();
    _onEnterCallback?.call();
  };

  _dragLeaveListener = (html.Event event) {
    event.preventDefault();
    event.stopPropagation();
    _onLeaveCallback?.call();
  };

  final target = html.document.body;
  if (target != null) {
    target.addEventListener('dragover', _dragOverListener!);
    target.addEventListener('drop', _dropListener!);
    target.addEventListener('dragenter', _dragEnterListener!);
    target.addEventListener('dragleave', _dragLeaveListener!);
  }
}

Future<void> _handleFile(html.File file) async {
  final bytes = await _readFileBytes(file);
  final mimeType = file.type.isNotEmpty ? file.type : _guessMimeType(file.name);
  _onFileDrop?.call(bytes, file.name, mimeType);
}

Future<Uint8List> _readFileBytes(html.File file) {
  final reader = html.FileReader();
  final completer = Completer<Uint8List>();

  reader.onLoad.listen((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
    } else if (result is Uint8List) {
      completer.complete(result);
    } else if (result is List<int>) {
      completer.complete(Uint8List.fromList(result));
    } else {
      completer.completeError('No se pudo leer el archivo');
    }
  });

  reader.onError.listen((event) {
    completer.completeError(event);
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}

String _guessMimeType(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return 'application/octet-stream';
  }
}

void unregisterWebDropHandler() {
  final target = html.document.body;
  if (target != null) {
    if (_dragOverListener != null) {
      target.removeEventListener('dragover', _dragOverListener!);
    }
    if (_dropListener != null) {
      target.removeEventListener('drop', _dropListener!);
    }
    if (_dragEnterListener != null) {
      target.removeEventListener('dragenter', _dragEnterListener!);
    }
    if (_dragLeaveListener != null) {
      target.removeEventListener('dragleave', _dragLeaveListener!);
    }
  }
  _dragOverListener = null;
  _dropListener = null;
  _dragEnterListener = null;
  _dragLeaveListener = null;
  _onFileDrop = null;
  _onEnterCallback = null;
  _onLeaveCallback = null;
}
