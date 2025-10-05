part of 'painter_page.dart';

void clearAll(_PainterPageState state) {
  state.controller.clearDrawables();
  state.selectedDrawable = null;
  state.dragAction = DragAction.none;

  state.dragStart = null;
  state.previewShape = null;

  state.dragStartBounds = null;
  state.dragStartPointer = null;
  state.dragFixedCorner = null;
  state.startAngle = null;

  state._pressSnapTimer?.cancel();
  state._dragSnapAngle = null;
  state._isCreatingLineLike = false;
  state._firstAngleLockPending = false;

  state._laFixedEnd = null;
  state._laAngle = null;
  state._laDir = null;

  state._pressOnSelection = false;
  state._movedSinceDown = false;
  state._downScene = null;
  state._downHitDrawable = null;

  if (state.mounted) {
    state.setState(() {});
  }
}

Future<void> saveAsPng(_PainterPageState state, BuildContext context) async {
  final ui.Image image = await state.controller.renderImage(const Size(1200, 1200));
  final bytes = await image.pngBytes;
  if (bytes == null) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Exported PNG Preview'),
      content: Image.memory(bytes),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> pickImageAndAdd(_PainterPageState state) async {
  const typeGroup = XTypeGroup(
    label: 'images',
    extensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
  );
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null) return;

  final data = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(data));
  final frame = await codec.getNextFrame();
  final image = frame.image;

  const double maxSide = 320;
  double width = image.width.toDouble();
  double height = image.height.toDouble();
  final scale = (width > height) ? (maxSide / width) : (maxSide / height);
  if (scale < 1.0) {
    width *= scale;
    height *= scale;
  }

  final drawable = ImageBoxDrawable(
    position: const Offset(320, 320),
    image: image,
    size: Size(width, height),
    rotationAngle: 0,
    strokeWidth: 0,
  );

  state.controller.addDrawables([drawable]);
  state.setState(() {
    state.selectedDrawable = drawable;
    state.currentTool = tool.Tool.select;
    state.controller.freeStyleMode = FreeStyleMode.none;
    state.controller.scalingEnabled = true;
  });
}
