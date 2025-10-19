part of 'painter_page.dart';

/// 라벨 영역(-1px 인셋) 안에 머물도록 이동 델타를 클램프한다.
Offset _clampMoveDeltaToLabel(
  _PainterPageState state,
  Rect startRect,
  Offset desiredDelta, {
  double inset = 1.0,
}) {
  final Size label = state.labelPixelSize;
  final Rect allowed = Rect.fromLTWH(
    inset,
    inset,
    (label.width - inset * 2).clamp(0.0, double.infinity),
    (label.height - inset * 2).clamp(0.0, double.infinity),
  );

  final Rect newRect = startRect.shift(desiredDelta);
  double dx = desiredDelta.dx;
  double dy = desiredDelta.dy;

  // 좌/우 경계 보정
  if (newRect.left < allowed.left) {
    dx += allowed.left - newRect.left;
  }
  if (newRect.right > allowed.right) {
    dx += allowed.right - newRect.right;
  }

  // 상/하 경계 보정
  if (newRect.top < allowed.top) {
    dy += allowed.top - newRect.top;
  }
  if (newRect.bottom > allowed.bottom) {
    dy += allowed.bottom - newRect.bottom;
  }

  return Offset(dx, dy);
}

/// 회전된 객체의 이동 델타를, 시작 시점의 크기(startRect.size)와 각도(angle)를 기준으로
/// 회전 AABB가 라벨(-inset) 내부에 유지되도록 중심을 클램프하여 반환한다.
Offset _clampMoveDeltaToLabelRotated(
  _PainterPageState state,
  Rect startRect,
  double angle,
  Offset desiredDelta, {
  double inset = 1.0,
}) {
  final Size label = state.labelPixelSize;
  final Rect allowed = Rect.fromLTWH(
    inset,
    inset,
    (label.width - inset * 2).clamp(0.0, double.infinity),
    (label.height - inset * 2).clamp(0.0, double.infinity),
  );

  // 시작 시점 콘텐츠 크기와 각도로 회전 AABB 반폭 계산
  final Size s = startRect.size;
  final double cosA = math.cos(angle).abs();
  final double sinA = math.sin(angle).abs();
  final double rotW = s.width * cosA + s.height * sinA;
  final double rotH = s.width * sinA + s.height * cosA;
  final double halfW = rotW / 2.0;
  final double halfH = rotH / 2.0;

  final Offset desiredCenter = startRect.center + desiredDelta;
  final double minX = allowed.left + halfW;
  final double maxX = allowed.right - halfW;
  final double minY = allowed.top + halfH;
  final double maxY = allowed.bottom - halfH;

  final double clampedX = desiredCenter.dx.clamp(minX, maxX);
  final double clampedY = desiredCenter.dy.clamp(minY, maxY);
  return Offset(clampedX - startRect.center.dx, clampedY - startRect.center.dy);
}

/// 현재 라벨 픽셀 크기를 기준으로 허용 사각형을 돌려준다. (-1px 인셋 기본)
Rect _allowedLabelRect(_PainterPageState state, {double inset = 1.0}) {
  final Size label = state.labelPixelSize;
  return Rect.fromLTWH(
    inset,
    inset,
    (label.width - inset * 2).clamp(0.0, double.infinity),
    (label.height - inset * 2).clamp(0.0, double.infinity),
  );
}

/// r 이 allowed 내부에 완전히 포함되는지 검사한다.
bool _isRectInside(Rect r, Rect allowed) {
  return r.left >= allowed.left &&
      r.top >= allowed.top &&
      r.right <= allowed.right &&
      r.bottom <= allowed.bottom;
}

/// 점 p 를 사각형 r 안으로 클램프한다.
Offset _clampPointToRect(Offset p, Rect r) {
  return Offset(p.dx.clamp(r.left, r.right), p.dy.clamp(r.top, r.bottom));
}

/// 코너 리사이즈 시, 시작 경계(startRect)와 고정 코너(worldFixed), 원하는 이동점(worldDesired)을 바탕으로
/// 결과 도형의 bounds(AABB)가 허용 사각형(라벨 - inset) 안에만 있도록 vMoveLocal(이동 코너의 로컬 좌표)를 이분 탐색으로 제한한다.
/// buildCandidate는 주어진 vMoveLocal로 Drawable 후보를 생성하는 클로저여야 한다.
Drawable _clampCornerResizeByBisection({
  required _PainterPageState state,
  required Rect startRect,
  required double angle,
  required Offset worldFixed,
  required Offset worldDesired,
  required DragAction action,
  double inset = 1.0,
  required Drawable Function(Offset vMoveLocal) buildCandidate,
  required Drawable Function(Offset vMoveLocal) buildStartCandidate,
}) {
  final allowed = _allowedLabelRect(state, inset: inset);
  final center0 = startRect.center;
  // 로컬 좌표들 계산
  // 시작 시점의 이동 코너(= 드래그 중 움직이는 코너)의 월드 좌표 추정 -> 로컬 변환
  Offset _movingCornerForAction(Rect r, DragAction a) {
    switch (a) {
      case DragAction.resizeNW:
        return r.topLeft;
      case DragAction.resizeNE:
        return r.topRight;
      case DragAction.resizeSW:
        return r.bottomLeft;
      case DragAction.resizeSE:
        return r.bottomRight;
      default:
        return r.center;
    }
  }

  final startMovingCornerWorld = state._rotPoint(
    _movingCornerForAction(startRect, action),
    center0,
    angle,
  );
  final vMove0 = state._toLocalVec(startMovingCornerWorld, center0, angle);
  final vDesired = state._toLocalVec(worldDesired, center0, angle);

  // 빠른 경로: 원하는 위치가 이미 허용 영역 안인 경우 바로 반환
  final desiredCandidate = buildCandidate(vDesired);
  final desiredBounds = state._boundsOf(desiredCandidate);
  if (_isRectInside(desiredBounds, allowed)) {
    return desiredCandidate;
  }

  // 시작 후보(항상 inside 여야 함)
  final startCandidate = buildStartCandidate(vMove0);
  final startBounds = state._boundsOf(startCandidate);
  if (!_isRectInside(startBounds, allowed)) {
    // 안전장치: 만약 시작 상태가 내부가 아니면 시작 상태로 되돌린다.
    return startCandidate;
  }

  // [0,1] 구간에서 이분 탐색으로 허용되는 최대 t 를 찾는다.
  double tLow = 0.0;
  double tHigh = 1.0;
  Drawable best = startCandidate;

  for (int i = 0; i < 18; i++) {
    final tMid = (tLow + tHigh) / 2.0;
    final vMid = Offset(
      vMove0.dx + (vDesired.dx - vMove0.dx) * tMid,
      vMove0.dy + (vDesired.dy - vMove0.dy) * tMid,
    );
    final cand = buildCandidate(vMid);
    final b = state._boundsOf(cand);
    if (_isRectInside(b, allowed)) {
      best = cand;
      tLow = tMid;
    } else {
      tHigh = tMid;
    }
  }

  return best;
}

void handlePointerDownSelect(
  _PainterPageState state,
  PointerDownEvent event,
) async {
  if (state.currentTool == tool.Tool.text) {
    final scenePoint = state.clampToLabel(
      state._sceneFromGlobal(event.position),
    );
    await state._createTextAt(scenePoint);
    return;
  }
  if (state.currentTool != tool.Tool.select) return;

  state._keyboardFocus.requestFocus();
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  final bool shiftNow =
      pressed.contains(LogicalKeyboardKey.shiftLeft) ||
      pressed.contains(LogicalKeyboardKey.shiftRight);
  if (state._isShiftPressed != shiftNow) {
    state.safeSetState(() {
      state._isShiftPressed = shiftNow;
    });
  }

  final scenePoint = state.clampToLabel(state._sceneFromGlobal(event.position));
  state._downScene = scenePoint;
  state._movedSinceDown = false;
  state._pressOnSelection = state._hitSelectionChromeScene(scenePoint);

  final hit = state._pickTopAt(scenePoint);
  state._downHitDrawable = hit;

  final isMultiSelectingTable = state._isShiftPressed && hit is TableDrawable;
  if (hit != null && hit != state.selectedDrawable && !isMultiSelectingTable) {
    state.safeSetState(() => state.selectedDrawable = hit);
  }
  if (hit is! TableDrawable && !isMultiSelectingTable) {
    state._clearCellSelection();
  }
}

Drawable? pickTopAt(_PainterPageState state, Offset scenePoint) {
  final list = state.controller.drawables.reversed.toList();
  for (final drawable in list) {
    if (state._hitTest(drawable, scenePoint)) return drawable;
  }
  return null;
}

void handleOverlayPanStart(_PainterPageState state, DragStartDetails details) {
  if (state.currentTool != tool.Tool.select) return;

  state._movedSinceDown = true;
  state._pressSnapTimer?.cancel();
  state._dragSnapAngle = null;
  state._isCreatingLineLike = false;
  state._firstAngleLockPending = false;

  final localScene = state.clampToLabel(
    state._sceneFromGlobal(details.globalPosition),
  );
  final current = state.selectedDrawable;

  void clearLineResize() {
    state._laFixedEnd = null;
    state._laAngle = null;
    state._laDir = null;
  }

  void prepareLineResize(Drawable drawable, DragAction action) {
    if (action != DragAction.resizeStart && action != DragAction.resizeEnd) {
      clearLineResize();
      return;
    }
    if (drawable is LineDrawable || drawable is ArrowDrawable) {
      final start = state._lineStart(drawable);
      final end = state._lineEnd(drawable);
      state._laFixedEnd = action == DragAction.resizeStart ? end : start;
      final rotation = (drawable as ObjectDrawable).rotationAngle;
      state._laAngle = rotation;
      state._laDir = Offset(math.cos(rotation), math.sin(rotation));
      return;
    }
    clearLineResize();
  }

  clearLineResize();

  void prime(ObjectDrawable obj, Rect rect, DragAction action) {
    state.dragAction = action;
    state.dragStartBounds = rect;
    state.dragStartPointer = localScene;

    if (action == DragAction.rotate) {
      state.startAngle = obj.rotationAngle;
      final center = obj.position;
      state._startPointerAngle = math.atan2(
        (localScene - center).dy,
        (localScene - center).dx,
      );
    } else {
      state.startAngle = null;
      state._startPointerAngle = null;
    }

    if (obj is BarcodeDrawable ||
        obj is ConstrainedTextDrawable ||
        obj is TextDrawable ||
        obj is ImageBoxDrawable ||
        obj is TableDrawable) {
      if (action == DragAction.resizeNW ||
          action == DragAction.resizeNE ||
          action == DragAction.resizeSW ||
          action == DragAction.resizeSE) {
        final angle = obj.rotationAngle;
        final opp = _fixedCornerForAction(rect, action);
        state.dragFixedCorner = state._rotPoint(opp, rect.center, angle);
      } else {
        state.dragFixedCorner = null;
      }
    } else {
      state.dragFixedCorner = null;
    }
  }

  if (current is ObjectDrawable) {
    final rect = state._boundsOf(current);
    final action = state._hitHandle(rect, localScene);
    prime(current, rect, action);
    prepareLineResize(current, action);

    if (action == DragAction.none && !rect.inflate(4).contains(localScene)) {
      final hit = state._pickTopAt(localScene);
      if (hit is ObjectDrawable && hit != current) {
        state.safeSetState(() => state.selectedDrawable = hit);
        final r2 = state._boundsOf(hit);
        final a2 = state._hitHandle(r2, localScene);
        prime(hit, r2, a2);
        prepareLineResize(hit, a2);
      }
    }
  } else {
    final hit = state._pickTopAt(localScene);
    if (hit is ObjectDrawable) {
      state.safeSetState(() => state.selectedDrawable = hit);
      final r2 = state._boundsOf(hit);
      final a2 = state._hitHandle(r2, localScene);
      prime(hit, r2, a2);
      prepareLineResize(hit, a2);
    } else {
      state.dragAction = DragAction.none;
      state.dragStartBounds = null;
      state.dragStartPointer = null;
      state.startAngle = null;
      state._startPointerAngle = null;
      state.dragFixedCorner = null;
    }
  }

  state.safeSetState(() {});
}

void handleOverlayPanUpdate(
  _PainterPageState state,
  DragUpdateDetails details,
) {
  if (state.selectedDrawable == null || state.dragAction == DragAction.none)
    return;
  state._movedSinceDown = true;

  final scenePtWorld = state._sceneFromGlobal(details.globalPosition);

  final original = state.selectedDrawable!;
  final startRect = state.dragStartBounds!;
  final startPtWorld = state.dragStartPointer!;
  Drawable? replaced;

  final isCornerResize =
      state.dragAction == DragAction.resizeNW ||
      state.dragAction == DragAction.resizeNE ||
      state.dragAction == DragAction.resizeSW ||
      state.dragAction == DragAction.resizeSE;

  if (state.dragAction == DragAction.move) {
    final desired = scenePtWorld - startPtWorld;
    Offset delta;
    if (original is LineDrawable || original is ArrowDrawable) {
      // 선/화살표는 startRect가 이미 AABB이며, 기존 방식으로 충분
      delta = _clampMoveDeltaToLabel(state, startRect, desired, inset: 1.0);
    } else if (original is ObjectDrawable) {
      final angle = original.rotationAngle;
      delta = _clampMoveDeltaToLabelRotated(
        state,
        startRect,
        angle,
        desired,
        inset: 1.0,
      );
    } else {
      delta = _clampMoveDeltaToLabel(state, startRect, desired, inset: 1.0);
    }
    if (original is ObjectDrawable) {
      replaced = (original as dynamic).copyWith(
        position: startRect.center + delta,
      );
    } else if (original is LineDrawable) {
      replaced = original.copyWith(position: startRect.center + delta);
    } else if (original is ConstrainedTextDrawable) {
      replaced = original.copyWith(position: startRect.center + delta);
    } else if (original is TextDrawable) {
      replaced = original.copyWith(position: startRect.center + delta);
    } else if (original is ImageBoxDrawable) {
      replaced = original.copyWithExt(position: startRect.center + delta);
    } else if (original is TableDrawable) {
      replaced = original.copyWith(position: startRect.center + delta);
    }
  } else if (state.dragAction == DragAction.rotate) {
    if (original is ObjectDrawable) {
      final center = original.position;

      final curPointerAngle = math.atan2(
        (scenePtWorld - center).dy,
        (scenePtWorld - center).dx,
      );
      final baseObjAngle = state.startAngle ?? original.rotationAngle;
      final basePointerAngle = state._startPointerAngle ?? curPointerAngle;

      var newAngle = baseObjAngle + (curPointerAngle - basePointerAngle);
      newAngle = state._snapAngle(newAngle);

      if (original is LineDrawable) {
        replaced = original.copyWith(rotation: newAngle);
      } else if (original is ArrowDrawable) {
        replaced = original.copyWith(rotation: newAngle);
      } else if (original is ConstrainedTextDrawable) {
        replaced = original.copyWith(rotation: newAngle);
      } else if (original is TextDrawable) {
        replaced = original.copyWith(rotation: newAngle);
      } else if (original is BarcodeDrawable) {
        replaced = original.copyWith(rotation: newAngle);
      } else if (original is ImageBoxDrawable) {
        replaced = original.copyWithExt(rotation: newAngle);
      }

      if (replaced != null) {
        replaced = adjustInsideAllowed(state, replaced, inset: 1.0);
      }
    }
  } else {
    if (original is RectangleDrawable || original is OvalDrawable) {
      final fixed =
          state.dragFixedCorner ??
          _fixedCornerForAction(startRect, state.dragAction);
      // 경계(-1px) 내로 이동 코너를 먼저 클램프한다 (축회전 없음)
      final allowed = _allowedLabelRect(state, inset: 1.0);
      final clampedMove = _clampPointToRect(scenePtWorld, allowed);
      Rect newRect = Rect.fromPoints(fixed, clampedMove);

      if (state.lockRatio) {
        final size = newRect.size;
        final m = math.max(size.width.abs(), size.height.abs());
        final dir = (clampedMove - fixed);
        final ddx = dir.dx.isNegative ? -m : m;
        final ddy = dir.dy.isNegative ? -m : m;
        newRect = Rect.fromPoints(fixed, fixed + Offset(ddx, ddy));
      }

      if (original is RectangleDrawable) {
        replaced = RectangleDrawable(
          position: newRect.center,
          size: newRect.size,
          paint: original.paint,
          borderRadius: original.borderRadius,
        );
      } else if (original is OvalDrawable) {
        replaced = OvalDrawable(
          position: newRect.center,
          size: newRect.size,
          paint: original.paint,
        );
      }
    } else if (original is BarcodeDrawable) {
      if (isCornerResize) {
        final angle = original.rotationAngle;
        final center0 = startRect.center;

        final worldFixed = state.dragFixedCorner!;
        final worldMove = scenePtWorld;

        Drawable buildWith(Offset vMoveLocal) {
          // vFixed 는 build 범위 밖에서 캡처
          final vFixed = state._toLocalVec(worldFixed, center0, angle);
          Offset vCenter = (vFixed + vMoveLocal) / 2;
          Size newSize = Size(
            (vMoveLocal.dx - vFixed.dx).abs(),
            (vMoveLocal.dy - vFixed.dy).abs(),
          );
          if (state.lockRatio) {
            final size = math.max(newSize.width, newSize.height);
            final signX = (vMoveLocal.dx - vFixed.dx) >= 0 ? 1.0 : -1.0;
            final signY = (vMoveLocal.dy - vFixed.dy) >= 0 ? 1.0 : -1.0;
            final vMoveLocked = Offset(
              vFixed.dx + signX * size,
              vFixed.dy + signY * size,
            );
            vCenter = (vFixed + vMoveLocked) / 2;
            newSize = Size(size, size);
          }
          final newCenterWorld = state._fromLocalVec(vCenter, center0, angle);
          return original.copyWith(
            position: newCenterWorld,
            size: newSize,
            rotation: angle,
          );
        }

        Drawable buildStart(Offset vMove0) => buildWith(vMove0);

        replaced = _clampCornerResizeByBisection(
          state: state,
          startRect: startRect,
          angle: angle,
          worldFixed: worldFixed,
          worldDesired: worldMove,
          action: state.dragAction,
          inset: 1.0,
          buildCandidate: buildWith,
          buildStartCandidate: buildStart,
        );
      }
    } else if (original is ConstrainedTextDrawable) {
      if (isCornerResize) {
        final angle = original.rotationAngle;
        final center0 = startRect.center;

        final worldFixed = state.dragFixedCorner!;
        final worldMove = scenePtWorld;

        Drawable buildWith(Offset vMoveLocal) {
          final vFixed = state._toLocalVec(worldFixed, center0, angle);
          final newWidth = (vMoveLocal.dx - vFixed.dx).abs().clamp(
            40.0,
            2000.0,
          );
          final signX = (vMoveLocal.dx - vFixed.dx) >= 0 ? 1.0 : -1.0;
          final vMoveAdjusted = Offset(
            vFixed.dx + signX * newWidth,
            vMoveLocal.dy,
          );
          final vCenter = (vFixed + vMoveAdjusted) / 2;
          final newCenterWorld = state._fromLocalVec(vCenter, center0, angle);
          return original.copyWith(
            position: newCenterWorld,
            maxWidth: newWidth,
            rotation: angle,
          );
        }

        Drawable buildStart(Offset vMove0) => buildWith(vMove0);

        replaced = _clampCornerResizeByBisection(
          state: state,
          startRect: startRect,
          angle: angle,
          worldFixed: worldFixed,
          worldDesired: worldMove,
          action: state.dragAction,
          inset: 1.0,
          buildCandidate: buildWith,
          buildStartCandidate: buildStart,
        );
      }
    } else if (original is TextDrawable) {
      if (isCornerResize) {
        final angle = original.rotationAngle;
        final center0 = startRect.center;

        final worldFixed = state.dragFixedCorner!;
        final worldMove = scenePtWorld;

        Drawable buildWith(Offset vMoveLocal) {
          final vFixed = state._toLocalVec(worldFixed, center0, angle);
          final vCenter = (vFixed + vMoveLocal) / 2;
          final newCenterWorld = state._fromLocalVec(vCenter, center0, angle);
          return original.copyWith(position: newCenterWorld, rotation: angle);
        }

        Drawable buildStart(Offset vMove0) => buildWith(vMove0);

        replaced = _clampCornerResizeByBisection(
          state: state,
          startRect: startRect,
          angle: angle,
          worldFixed: worldFixed,
          worldDesired: worldMove,
          action: state.dragAction,
          inset: 1.0,
          buildCandidate: buildWith,
          buildStartCandidate: buildStart,
        );
      }
    } else if (original is ImageBoxDrawable) {
      if (isCornerResize) {
        final angle = original.rotationAngle;
        final center0 = startRect.center;

        final worldFixed = state.dragFixedCorner!;
        final worldMove = scenePtWorld;

        Drawable buildWith(Offset vMoveLocal) {
          final vFixed = state._toLocalVec(worldFixed, center0, angle);
          Offset vCenter = (vFixed + vMoveLocal) / 2;
          Size newSize = Size(
            (vMoveLocal.dx - vFixed.dx).abs(),
            (vMoveLocal.dy - vFixed.dy).abs(),
          );
          if (state.lockRatio) {
            final size = math.max(newSize.width, newSize.height);
            final signX = (vMoveLocal.dx - vFixed.dx) >= 0 ? 1.0 : -1.0;
            final signY = (vMoveLocal.dy - vFixed.dy) >= 0 ? 1.0 : -1.0;
            final vMoveLocked = Offset(
              vFixed.dx + signX * size,
              vFixed.dy + signY * size,
            );
            vCenter = (vFixed + vMoveLocked) / 2;
            newSize = Size(size, size);
          }
          final newCenterWorld = state._fromLocalVec(vCenter, center0, angle);
          return original.copyWithExt(
            position: newCenterWorld,
            size: newSize,
            rotation: angle,
          );
        }

        Drawable buildStart(Offset vMove0) => buildWith(vMove0);

        replaced = _clampCornerResizeByBisection(
          state: state,
          startRect: startRect,
          angle: angle,
          worldFixed: worldFixed,
          worldDesired: worldMove,
          action: state.dragAction,
          inset: 1.0,
          buildCandidate: buildWith,
          buildStartCandidate: buildStart,
        );
      }
    } else if (original is TableDrawable) {
      if (isCornerResize) {
        final angle = original.rotationAngle;
        final center0 = startRect.center;

        final worldFixed = state.dragFixedCorner!;
        final worldMove = scenePtWorld;

        Drawable buildWith(Offset vMoveLocal) {
          final vFixed = state._toLocalVec(worldFixed, center0, angle);
          final minWidth = original.columns * 16.0;
          final minHeight = original.rows * 16.0;
          final width = (vMoveLocal.dx - vFixed.dx).abs().clamp(
            minWidth,
            double.infinity,
          );
          final height = (vMoveLocal.dy - vFixed.dy).abs().clamp(
            minHeight,
            double.infinity,
          );
          final signX = (vMoveLocal.dx - vFixed.dx) >= 0 ? 1.0 : -1.0;
          final signY = (vMoveLocal.dy - vFixed.dy) >= 0 ? 1.0 : -1.0;
          final vMoveAdjusted = Offset(
            vFixed.dx + signX * width,
            vFixed.dy + signY * height,
          );
          final vCenter = (vFixed + vMoveAdjusted) / 2;
          final newCenterWorld = state._fromLocalVec(vCenter, center0, angle);
          return original.copyWith(
            position: newCenterWorld,
            size: Size(width, height),
            rotation: angle,
          );
        }

        Drawable buildStart(Offset vMove0) => buildWith(vMove0);

        replaced = _clampCornerResizeByBisection(
          state: state,
          startRect: startRect,
          angle: angle,
          worldFixed: worldFixed,
          worldDesired: worldMove,
          action: state.dragAction,
          inset: 1.0,
          buildCandidate: buildWith,
          buildStartCandidate: buildStart,
        );
      }
    } else if (original is LineDrawable || original is ArrowDrawable) {
      if (state._laFixedEnd != null) {
        final fixed = state._laFixedEnd!;
        final allowed = _allowedLabelRect(state, inset: 1.0);
        final pnt = _clampPointToRect(scenePtWorld, allowed);

        double ang;
        double len;
        if (state.endpointDragRotates) {
          ang = math.atan2((pnt - fixed).dy, (pnt - fixed).dx);
          ang = state._snapAngle(ang);
          len = (pnt - fixed).distance.clamp(
            _PainterPageState._laMinLen,
            double.infinity,
          );
        } else {
          final dir =
              state._laDir ??
              Offset(
                math.cos(state._laAngle ?? 0),
                math.sin(state._laAngle ?? 0),
              );
          final v = pnt - fixed;
          final t = v.dx * dir.dx + v.dy * dir.dy;
          ang = state._laAngle ?? math.atan2(dir.dy, dir.dx);
          len = (dir * t).distance.clamp(
            _PainterPageState._laMinLen,
            double.infinity,
          );
        }

        final dir2 = Offset(math.cos(ang), math.sin(ang));
        final movingEnd = fixed + dir2 * len;
        final newCenter = (fixed + movingEnd) / 2;

        if (original is LineDrawable) {
          replaced = original.copyWith(
            position: newCenter,
            length: len,
            rotation: ang,
          );
        } else if (original is ArrowDrawable) {
          replaced = original.copyWith(
            position: newCenter,
            length: len,
            rotation: ang,
          );
        }

        state._laAngle = ang;
        state._laDir = dir2;
      }
    }
  }

  if (replaced != null) {
    state.controller.replaceDrawable(original, replaced);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    state.controller.notifyListeners();
    state.safeSetState(() => state.selectedDrawable = replaced);
  }
}

void handleOverlayPanEnd(_PainterPageState state) {
  state._pressSnapTimer?.cancel();
  state._dragSnapAngle = null;
  state._isCreatingLineLike = false;
  state._firstAngleLockPending = false;
  state.dragAction = DragAction.none;
  state.dragStartBounds = null;
  state.dragStartPointer = null;
  state.dragFixedCorner = null;
  state.startAngle = null;
  state._startPointerAngle = null;

  state._laFixedEnd = null;
  state._laAngle = null;
  state._laDir = null;

  state._pressOnSelection = false;
  state._movedSinceDown = false;
  state._downScene = null;
  state._downHitDrawable = null;
}

Offset _fixedCornerForAction(Rect rect, DragAction action) {
  switch (action) {
    case DragAction.resizeNW:
      return rect.bottomRight;
    case DragAction.resizeNE:
      return rect.bottomLeft;
    case DragAction.resizeSW:
      return rect.topRight;
    case DragAction.resizeSE:
      return rect.topLeft;
    default:
      return rect.center;
  }
}

void handleCanvasTap(_PainterPageState state) {
  if (state._quillController != null) {
    state._commitInlineEditor();
  }
  if (state.currentTool != tool.Tool.select) return;

  final hadHit = state._downHitDrawable != null;

  if (!hadHit && !state._pressOnSelection && !state._movedSinceDown) {
    state.safeSetState(() {
      state.selectedDrawable = null;
      state.dragAction = DragAction.none;
      state._clearCellSelection();
    });
  } else if (hadHit && state._downHitDrawable is TableDrawable) {
    final table = state._downHitDrawable as TableDrawable;
    final scenePoint = state._downScene!;

    final local = state._toLocal(
      scenePoint,
      table.position,
      table.rotationAngle,
    );
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: table.size.width,
      height: table.size.height,
    );

    if (rect.contains(local)) {
      double x = rect.left;
      var col = -1;
      for (var c = 0; c < table.columns; c++) {
        final double width = c < table.columnFractions.length
            ? rect.width * table.columnFractions[c]
            : rect.right - x;
        final double xRight = (c == table.columns - 1) ? rect.right : x + width;
        if (local.dx >= x && local.dx <= xRight) {
          col = c;
          break;
        }
        x = xRight;
      }
      if (col == -1) {
        col = table.columns - 1;
      }

      int row;
      // Determine row by rowFractions (fallback equal)
      double sum = 0.0;
      for (final v in table.rowFractions) {
        if (v.isFinite && v > 0) sum += v;
      }
      if (sum <= 0 || table.rowFractions.length < table.rows) {
        final rowH = rect.height / table.rows;
        row = (((local.dy - rect.top) / rowH).floor()).clamp(0, table.rows - 1);
      } else {
        double acc = rect.top;
        row = 0;
        for (int r = 0; r < table.rows; r++) {
          final rh = rect.height * (table.rowFractions[r] / sum);
          if (local.dy < acc + rh) {
            row = r;
            break;
          }
          acc += rh;
          if (r == table.rows - 1) row = r;
        }
      }

      var range = state._rangeForCell(table, row, col);
      if (state._isShiftPressed) {
        final current = state._currentCellSelectionRange();
        if (current != null) {
          range = state._expandRangeForMerges(table, current.union(range));
        }
      } else {
        range = state._expandRangeForMerges(table, range);
      }

      state.safeSetState(() {
        state._selectionAnchorCell = (range.topRow, range.leftCol);
        state._selectionFocusCell = (range.bottomRow, range.rightCol);
      });
    }
  }

  state._pressOnSelection = false;
  state._movedSinceDown = false;
  state._downScene = null;
  state._downHitDrawable = null;
}

void clearCellSelection(_PainterPageState state) {
  if (state._selectionAnchorCell != null || state._selectionFocusCell != null) {
    state.safeSetState(() {
      state._selectionAnchorCell = null;
      state._selectionFocusCell = null;
    });
  }
}

void applyInspector(
  _PainterPageState state, {
  Color? newStrokeColor,
  double? newStrokeWidth,
  double? newCornerRadius,
}) {
  final drawable = state.selectedDrawable;
  if (drawable == null) return;
  Drawable? replaced;

  if (drawable is RectangleDrawable) {
    replaced = RectangleDrawable(
      position: drawable.position,
      size: drawable.size,
      paint: state._strokePaint(
        newStrokeColor ?? state.strokeColor,
        newStrokeWidth ?? state.strokeWidth,
      ),
      borderRadius: BorderRadius.all(
        Radius.circular(newCornerRadius ?? drawable.borderRadius.topLeft.x),
      ),
    );
  } else if (drawable is OvalDrawable) {
    replaced = OvalDrawable(
      position: drawable.position,
      size: drawable.size,
      paint: state._strokePaint(
        newStrokeColor ?? state.strokeColor,
        newStrokeWidth ?? state.strokeWidth,
      ),
    );
  } else if (drawable is LineDrawable) {
    replaced = drawable.copyWith(
      paint: state._strokePaint(
        newStrokeColor ?? state.strokeColor,
        newStrokeWidth ?? state.strokeWidth,
      ),
    );
  } else if (drawable is ArrowDrawable) {
    replaced = drawable.copyWith(
      paint: state._strokePaint(
        newStrokeColor ?? state.strokeColor,
        newStrokeWidth ?? state.strokeWidth,
      ),
    );
  } else {
    return;
  }

  state.controller.replaceDrawable(drawable, replaced);
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  state.controller.notifyListeners();
  state.safeSetState(() {
    state.selectedDrawable = replaced;
    if (newStrokeColor != null) state.strokeColor = newStrokeColor;
    if (newStrokeWidth != null) state.strokeWidth = newStrokeWidth;
  });
}

Future<void> createTextAt(_PainterPageState state, Offset scenePoint) async {
  final controllerText = TextEditingController();
  double tempSize = state.textFontSize;
  bool tempBold = state.textBold;
  bool tempItalic = state.textItalic;
  String tempFamily = state.textFontFamily;
  Color tempColor = state.strokeColor;
  tool.TxtAlign tempAlign = state.defaultTextAlign;
  double tempMaxWidth = state.defaultTextMaxWidth;

  final result = await showDialog<bool>(
    context: state.context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Add Text'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controllerText,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Text',
                    hintText: 'Enter text...',
                  ),
                  minLines: 1,
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Size'),
                    Expanded(
                      child: Slider(
                        min: 8,
                        max: 96,
                        value: tempSize,
                        onChanged: (value) =>
                            setStateDialog(() => tempSize = value),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(tempSize.toStringAsFixed(0)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Bold'),
                      selected: tempBold,
                      onSelected: (value) =>
                          setStateDialog(() => tempBold = value),
                    ),
                    FilterChip(
                      label: const Text('Italic'),
                      selected: tempItalic,
                      onSelected: (value) =>
                          setStateDialog(() => tempItalic = value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Font'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: tempFamily,
                      items: const [
                        DropdownMenuItem(
                          value: 'Roboto',
                          child: Text('Roboto'),
                        ),
                        DropdownMenuItem(
                          value: 'NotoSans',
                          child: Text('NotoSans'),
                        ),
                        DropdownMenuItem(
                          value: 'Monospace',
                          child: Text('Monospace'),
                        ),
                      ],
                      onChanged: (value) => setStateDialog(() {
                        if (value != null) tempFamily = value;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Align'),
                    const SizedBox(width: 8),
                    DropdownButton<tool.TxtAlign>(
                      value: tempAlign,
                      items: const [
                        DropdownMenuItem(
                          value: tool.TxtAlign.left,
                          child: Text('Left'),
                        ),
                        DropdownMenuItem(
                          value: tool.TxtAlign.center,
                          child: Text('Center'),
                        ),
                        DropdownMenuItem(
                          value: tool.TxtAlign.right,
                          child: Text('Right'),
                        ),
                      ],
                      onChanged: (value) => setStateDialog(() {
                        if (value != null) tempAlign = value;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Max Width'),
                    Expanded(
                      child: Slider(
                        min: 40,
                        max: 800,
                        value: tempMaxWidth,
                        onChanged: (value) =>
                            setStateDialog(() => tempMaxWidth = value),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(tempMaxWidth.toStringAsFixed(0)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      );
    },
  );

  if (result != true) return;
  final txt = controllerText.text.trim();
  if (txt.isEmpty) return;

  final style = TextStyle(
    color: tempColor,
    fontSize: tempSize,
    fontWeight: tempBold ? FontWeight.bold : FontWeight.normal,
    fontStyle: tempItalic ? FontStyle.italic : FontStyle.normal,
    fontFamily: tempFamily,
  );

  final drawable = ConstrainedTextDrawable(
    text: txt,
    position: scenePoint,
    rotationAngle: 0.0,
    style: style,
    align: tempAlign,
    maxWidth: tempMaxWidth,
    direction: TextDirection.ltr,
  );

  state.controller.addDrawables([drawable]);
  state.safeSetState(() {
    state.selectedDrawable = drawable;
    state.currentTool = tool.Tool.select;
    state.controller.freeStyleMode = FreeStyleMode.none;
    state.controller.scalingEnabled = true;
    state.textFontSize = tempSize;
    state.textBold = tempBold;
    state.textItalic = tempItalic;
    state.textFontFamily = tempFamily;
    state.strokeColor = tempColor;
    state.defaultTextAlign = tempAlign;
    state.defaultTextMaxWidth = tempMaxWidth;
  });
}

void handleTableInsert(_PainterPageState state, int rows, int columns) {
  if (rows <= 0 || columns <= 0) return;
  state._createTableDrawable(rows, columns);
}

void createTableDrawable(_PainterPageState state, int rows, int columns) {
  final renderObject = state._painterKey.currentContext?.findRenderObject();
  Size painterSize;
  if (renderObject is RenderBox && renderObject.hasSize) {
    painterSize = renderObject.size;
  } else {
    painterSize = const Size(640, 640);
  }

  const double horizontalMargin = 1.0;
  const double topMargin = 1.0;
  final double availableWidth = math.max(
    1.0,
    painterSize.width - horizontalMargin * 2,
  );
  final double desiredHeight = math.max(32.0, rows * 32.0);
  final double maxHeight = math.max(1.0, painterSize.height - topMargin);
  final double tableHeight = math.min(desiredHeight, maxHeight);
  final tableSize = Size(availableWidth, tableHeight);

  final fractions = List<double>.filled(columns, 1.0 / columns);

  final table = TableDrawable(
    rows: rows,
    columns: columns,
    columnFractions: fractions,
    position: Offset(
      horizontalMargin + tableSize.width / 2,
      topMargin + tableSize.height / 2,
    ),
    size: tableSize,
  );

  state.controller.addDrawables([table]);
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  state.controller.notifyListeners();
  state.safeSetState(() {
    state.selectedDrawable = table;
  });
  state._setTool(tool.Tool.select);
}
