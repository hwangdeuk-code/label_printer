part of 'painter_page.dart';

void handlePanStartCreate(_PainterPageState state, DragStartDetails details) {
  if (state._isPainterGestureTool ||
      state.currentTool == tool.Tool.text ||
      state.currentTool == tool.Tool.image) {
    return;
  }
  state._dragSnapAngle = null;
  state._isCreatingLineLike =
      (state.currentTool == tool.Tool.line || state.currentTool == tool.Tool.arrow);
  state._firstAngleLockPending = state._isCreatingLineLike;

  state._pressSnapTimer?.cancel();
  if (state._isCreatingLineLike) {
    state._pressSnapTimer = Timer(const Duration(milliseconds: 250), () {
      if (state._isCreatingLineLike && state._firstAngleLockPending) {
        state._dragSnapAngle = (state._lastRawAngle / state._snapStep).roundToDouble() * state._snapStep;
        state._firstAngleLockPending = false;
      }
    });
  }

  state.dragStart = state._sceneFromGlobal(details.globalPosition);
  state.previewShape = state._makeShape(state.dragStart!, state.dragStart!);
  if (state.previewShape != null) {
    state.controller.addDrawables([state.previewShape!]);
  }
}

void handlePanUpdateCreate(_PainterPageState state, DragUpdateDetails details) {
  if (state._isPainterGestureTool ||
      state.currentTool == tool.Tool.text ||
      state.currentTool == tool.Tool.image) {
    return;
  }
  if (state.dragStart == null || state.previewShape == null) return;
  final current = state._sceneFromGlobal(details.globalPosition);

  if (state._isCreatingLineLike) {
    final delta = current - state.dragStart!;
    if (delta.distance > 0) {
      state._lastRawAngle = math.atan2(delta.dy, delta.dx);
    }
  }

  final updated = state._makeShape(state.dragStart!, current, previewOf: state.previewShape);
  if (updated != null) {
    state.controller.replaceDrawable(state.previewShape!, updated);
    state.previewShape = updated;
  }
}

void handlePanEndCreate(_PainterPageState state) {
  if (state._isPainterGestureTool ||
      state.currentTool == tool.Tool.text ||
      state.currentTool == tool.Tool.image) {
    return;
  }
  state._pressSnapTimer?.cancel();
  state._dragSnapAngle = null;
  state._isCreatingLineLike = false;
  state._firstAngleLockPending = false;
  final createdDrawable = state.previewShape;
  state.dragStart = null;
  state.previewShape = null;

  final shouldSwitchToSelect = state.currentTool == tool.Tool.rect ||
      state.currentTool == tool.Tool.oval ||
      state.currentTool == tool.Tool.line ||
      state.currentTool == tool.Tool.arrow ||
      state.currentTool == tool.Tool.barcode;

  if (shouldSwitchToSelect && createdDrawable != null) {
    state.setState(() => state.selectedDrawable = createdDrawable);
  }
  if (shouldSwitchToSelect) {
    state._setTool(tool.Tool.select);
  }
}
