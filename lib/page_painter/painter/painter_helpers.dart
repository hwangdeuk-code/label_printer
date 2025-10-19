part of 'painter_page.dart';

void handleQuillFocusChange(_PainterPageState state) {
  if (!state._quillFocus.hasFocus) {
    if (state._guardSelectionDuringInspector) return;
    state._quillBlurCommitTimer?.cancel();
    state._quillBlurCommitTimer = Timer(const Duration(milliseconds: 180), () {
      if (state._suppressCommitOnce) {
        state._suppressCommitOnce = false;
        return;
      }
      if (!state._quillFocus.hasFocus) {
        state._commitInlineEditor();
      }
    });
  } else {
    state._quillBlurCommitTimer?.cancel();
  }
}

Offset sceneFromGlobal(_PainterPageState state, Offset global) {
  final renderObject = state._painterKey.currentContext?.findRenderObject();
  if (renderObject is! RenderBox) return global;
  final local = renderObject.globalToLocal(global);
  return state.controller.transformationController.toScene(local);
}

Paint strokePaint(_PainterPageState state, Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width * (state.scalePercent / 100.0);

Paint fillPaint(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill;

Offset lineStart(Drawable drawable) {
  if (drawable is LineDrawable) {
    final dir = Offset(
      math.cos(drawable.rotationAngle),
      math.sin(drawable.rotationAngle),
    );
    return drawable.position - dir * (drawable.length / 2);
  }
  if (drawable is ArrowDrawable) {
    final dir = Offset(
      math.cos(drawable.rotationAngle),
      math.sin(drawable.rotationAngle),
    );
    return drawable.position - dir * (drawable.length / 2);
  }
  return Offset.zero;
}

Offset lineEnd(Drawable drawable) {
  if (drawable is LineDrawable) {
    final dir = Offset(
      math.cos(drawable.rotationAngle),
      math.sin(drawable.rotationAngle),
    );
    return drawable.position + dir * (drawable.length / 2);
  }
  if (drawable is ArrowDrawable) {
    final dir = Offset(
      math.cos(drawable.rotationAngle),
      math.sin(drawable.rotationAngle),
    );
    return drawable.position + dir * (drawable.length / 2);
  }
  return Offset.zero;
}

Rect boundsOf(_PainterPageState state, Drawable drawable) {
  if (drawable is RectangleDrawable) {
    return Rect.fromCenter(
      center: drawable.position,
      width: drawable.size.width,
      height: drawable.size.height,
    );
  }
  if (drawable is OvalDrawable) {
    return Rect.fromCenter(
      center: drawable.position,
      width: drawable.size.width,
      height: drawable.size.height,
    );
  }
  if (drawable is BarcodeDrawable) {
    return Rect.fromCenter(
      center: drawable.position,
      width: drawable.size.width,
      height: drawable.size.height,
    );
  }
  if (drawable is ImageBoxDrawable) {
    return Rect.fromCenter(
      center: drawable.position,
      width: drawable.size.width,
      height: drawable.size.height,
    );
  }
  if (drawable is TableDrawable) {
    return Rect.fromCenter(
      center: drawable.position,
      width: drawable.size.width,
      height: drawable.size.height,
    );
  }
  if (drawable is LineDrawable) {
    final a = lineStart(drawable), b = lineEnd(drawable);
    return Rect.fromPoints(a, b);
  }
  if (drawable is ArrowDrawable) {
    final a = lineStart(drawable), b = lineEnd(drawable);
    return Rect.fromPoints(a, b);
  }
  if (drawable is ConstrainedTextDrawable) {
    final size = drawable.getSize(maxWidth: drawable.maxWidth);
    return Rect.fromCenter(
      center: drawable.position,
      width: size.width,
      height: size.height,
    );
  }
  if (drawable is TextDrawable) {
    final size = drawable.getSize();
    return Rect.fromCenter(
      center: drawable.position,
      width: size.width,
      height: size.height,
    );
  }
  return Rect.zero;
}

/// 회전된 객체의 축정렬 경계(AABB)를 계산한다. (컨트롤 패딩 제외, 콘텐츠 기준)
Rect rotatedAabbOf(_PainterPageState state, Drawable drawable) {
  if (drawable is LineDrawable || drawable is ArrowDrawable) {
    final a = lineStart(drawable);
    final b = lineEnd(drawable);
    return Rect.fromPoints(a, b);
  }
  if (drawable is ObjectDrawable) {
    Size contentSize;
    if (drawable is ConstrainedTextDrawable) {
      contentSize = drawable.getSize(maxWidth: drawable.maxWidth);
    } else if (drawable is TextDrawable) {
      contentSize = drawable.getSize();
    } else if (drawable is Sized2DDrawable) {
      contentSize = drawable.getSize();
    } else {
      contentSize = drawable.getSize();
    }

    final angle = drawable.rotationAngle;
    final cosA = math.cos(angle).abs();
    final sinA = math.sin(angle).abs();
    final rotW = contentSize.width * cosA + contentSize.height * sinA;
    final rotH = contentSize.width * sinA + contentSize.height * cosA;
    final halfW = rotW / 2;
    final halfH = rotH / 2;
    return Rect.fromLTRB(
      drawable.position.dx - halfW,
      drawable.position.dy - halfH,
      drawable.position.dx + halfW,
      drawable.position.dy + halfH,
    );
  }
  return boundsOf(state, drawable);
}

/// 후보 도형이 라벨(-inset) 허용 영역을 벗어나면 position을 평행이동해 완전히 안쪽으로 들여보낸다.
Drawable adjustInsideAllowed(
  _PainterPageState state,
  Drawable candidate, {
  double inset = 1.0,
}) {
  final Size label = state.labelPixelSize;
  final Rect allowed = Rect.fromLTWH(
    inset,
    inset,
    (label.width - inset * 2).clamp(0.0, double.infinity),
    (label.height - inset * 2).clamp(0.0, double.infinity),
  );

  final Rect b = rotatedAabbOf(state, candidate);
  double dx = 0.0;
  double dy = 0.0;
  if (b.left < allowed.left) {
    dx = allowed.left - b.left;
  } else if (b.right > allowed.right) {
    dx = allowed.right - b.right;
  }
  if (b.top < allowed.top) {
    dy = allowed.top - b.top;
  } else if (b.bottom > allowed.bottom) {
    dy = allowed.bottom - b.bottom;
  }
  if (dx == 0.0 && dy == 0.0) return candidate;

  if (candidate is ObjectDrawable) {
    final Offset newPos = candidate.position + Offset(dx, dy);
    if (candidate is LineDrawable) {
      return candidate.copyWith(position: newPos);
    } else if (candidate is ArrowDrawable) {
      return candidate.copyWith(position: newPos);
    } else if (candidate is ConstrainedTextDrawable) {
      return candidate.copyWith(position: newPos);
    } else if (candidate is TextDrawable) {
      return candidate.copyWith(position: newPos);
    } else if (candidate is BarcodeDrawable) {
      return candidate.copyWith(position: newPos);
    } else if (candidate is ImageBoxDrawable) {
      return candidate.copyWithExt(position: newPos);
    } else if (candidate is TableDrawable) {
      return candidate.copyWith(position: newPos);
    }
  }
  return candidate;
}

bool isPainterGestureTool(_PainterPageState state) =>
    state.currentTool == tool.Tool.pen ||
    state.currentTool == tool.Tool.eraser ||
    state.currentTool == tool.Tool.select;

void setTool(_PainterPageState state, tool.Tool value) {
  state.safeSetState(() {
    state.currentTool = value;
    switch (value) {
      case tool.Tool.pen:
        state.controller.freeStyleMode = FreeStyleMode.draw;
        state.controller.scalingEnabled = true;
        break;
      case tool.Tool.eraser:
        state.controller.freeStyleMode = FreeStyleMode.erase;
        state.controller.scalingEnabled = true;
        break;
      case tool.Tool.select:
        state.controller.freeStyleMode = FreeStyleMode.none;
        state.controller.scalingEnabled = true;
        break;
      case tool.Tool.text:
      case tool.Tool.image:
        state.controller.freeStyleMode = FreeStyleMode.none;
        state.controller.scalingEnabled = false;
        break;
      default:
        state.controller.freeStyleMode = FreeStyleMode.none;
        state.controller.scalingEnabled = false;
        break;
    }
  });

  if (value == tool.Tool.image) {
    unawaited(
      state._pickImageAndAdd().then((_) {
        if (!state.mounted) return;
        state.safeSetState(() {
          state.currentTool = tool.Tool.select;
          state.controller.freeStyleMode = FreeStyleMode.none;
          state.controller.scalingEnabled = true;
        });
      }),
    );
  }
}

double snapAngle(_PainterPageState state, double raw) {
  if (!state.angleSnap) return raw;
  double normalize(double rad) {
    final twoPi = 2 * math.pi;
    var angle = rad % twoPi;
    if (angle >= math.pi) angle -= twoPi;
    if (angle < -math.pi) angle += twoPi;
    return angle;
  }

  final norm = normalize(raw);
  final target =
      (normalize(norm / state._snapStep).roundToDouble()) * state._snapStep;
  if (state._isCreatingLineLike && state._firstAngleLockPending) {
    state._dragSnapAngle = target;
    state._firstAngleLockPending = false;
    return state._dragSnapAngle!;
  }
  if ((norm - target).abs() <= state._snapTol) {
    state._dragSnapAngle ??= target;
    return state._dragSnapAngle!;
  }
  if (state._dragSnapAngle != null) {
    final exitTol = state._snapTol * 1.5;
    if ((norm - state._dragSnapAngle!).abs() <= exitTol)
      return state._dragSnapAngle!;
  }
  return norm;
}

Drawable? makeShape(
  _PainterPageState state,
  Offset a,
  Offset b, {
  Drawable? previewOf,
}) {
  var dx = b.dx - a.dx;
  var dy = b.dy - a.dy;
  var w = dx.abs();
  var h = dy.abs();

  if (state.lockRatio &&
      (state.currentTool == tool.Tool.rect ||
          state.currentTool == tool.Tool.oval ||
          state.currentTool == tool.Tool.barcode)) {
    final size = math.max(w, h);
    dx = dx.isNegative ? -size : size;
    dy = dy.isNegative ? -size : size;
    w = size;
    h = size;
  }

  final cx = math.min(a.dx, a.dx + dx) + w / 2;
  final cy = math.min(a.dy, a.dy + dy) + h / 2;
  final center = Offset(cx, cy);

  switch (state.currentTool) {
    case tool.Tool.rect:
      return RectangleDrawable(
        position: center,
        size: Size(w, h),
        paint: state.fillColor.a == 0
            ? strokePaint(state, state.strokeColor, state.strokeWidth)
            : fillPaint(state.fillColor),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      );
    case tool.Tool.oval:
      return OvalDrawable(
        position: center,
        size: Size(w, h),
        paint: state.fillColor.a == 0
            ? strokePaint(state, state.strokeColor, state.strokeWidth)
            : fillPaint(state.fillColor),
      );
    case tool.Tool.barcode:
      final existing = previewOf is BarcodeDrawable ? previewOf : null;
      final size = Size(math.max(w, 1), math.max(h, 1));
      return BarcodeDrawable(
        data: existing?.data ?? state.barcodeData,
        type: existing?.type ?? state.barcodeType,
        showValue: existing?.showValue ?? state.barcodeShowValue,
        fontSize: existing?.fontSize ?? state.barcodeFontSize,
        foreground: existing?.foreground ?? state.barcodeForeground,
        background: existing?.background ?? state.barcodeBackground,
        bold: existing?.bold ?? false,
        italic: existing?.italic ?? false,
        fontFamily: existing?.fontFamily ?? 'Roboto',
        textAlign: existing?.textAlign,
        maxTextWidth: existing?.maxTextWidth ?? 0,
        position: center,
        size: size,
      );
    case tool.Tool.line:
    case tool.Tool.arrow:
      final length = (b - a).distance;
      var angle = math.atan2(dy, dx);
      if (state._isCreatingLineLike &&
          state._firstAngleLockPending &&
          length >= _PainterPageState._firstLockMinLen) {
        state._dragSnapAngle =
            (angle / state._snapStep).roundToDouble() * state._snapStep;
        state._firstAngleLockPending = false;
      }
      angle = snapAngle(state, angle);

      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      if (state.currentTool == tool.Tool.line) {
        return LineDrawable(
          position: mid,
          length: length,
          rotationAngle: angle,
          paint: strokePaint(state, state.strokeColor, state.strokeWidth),
        );
      }
      return ArrowDrawable(
        position: mid,
        length: length,
        rotationAngle: angle,
        arrowHeadSize: 16,
        paint: strokePaint(state, state.strokeColor, state.strokeWidth),
      );
    default:
      return null;
  }
}

bool hitTest(_PainterPageState state, Drawable drawable, Offset point) {
  final rect = boundsOf(
    state,
    drawable,
  ).inflate(math.max(8, state.strokeWidth));
  if (drawable is LineDrawable || drawable is ArrowDrawable) {
    final a = lineStart(drawable);
    final b = lineEnd(drawable);
    final dist = distanceToSegment(point, a, b);
    return dist <= math.max(8, state.strokeWidth) || rect.contains(point);
  }
  return rect.contains(point);
}

double distanceToSegment(Offset p, Offset a, Offset b) {
  final ap = p - a;
  final ab = b - a;
  final denom = ab.dx * ab.dx + ab.dy * ab.dy;
  if (denom == 0) return (p - a).distance;
  final t = (ap.dx * ab.dx + ap.dy * ab.dy) / denom;
  final tt = t.clamp(0.0, 1.0);
  final proj = Offset(a.dx + ab.dx * tt, a.dy + ab.dy * tt);
  return (p - proj).distance;
}

bool hitSelectionChromeScene(_PainterPageState state, Offset point) {
  final selected = state.selectedDrawable;
  if (selected == null) return false;

  if (selected is LineDrawable) {
    final a = lineStart(selected);
    final b = lineEnd(selected);
    if ((point - a).distance <= state.handleTouchRadius) return true;
    if ((point - b).distance <= state.handleTouchRadius) return true;
    final r = boundsOf(state, selected);
    if (r.inflate(4).contains(point)) return true;
    return false;
  } else if (selected is ArrowDrawable) {
    final a = lineStart(selected);
    final b = lineEnd(selected);
    if ((point - a).distance <= state.handleTouchRadius) return true;
    if ((point - b).distance <= state.handleTouchRadius) return true;
    final r = boundsOf(state, selected);
    if (r.inflate(4).contains(point)) return true;
    return false;
  }

  final r = boundsOf(state, selected);
  // 회전 객체에 대한 히트 테스트 정합성: 선택 크롬은 회전된 상태로 그려지므로,
  // 검사는 포인터를 객체 로컬(비회전) 좌표로 역변환하여 수행한다.
  Offset adjustedPoint = point;
  if (selected is ObjectDrawable &&
      selected is! LineDrawable &&
      selected is! ArrowDrawable) {
    final angle = selected.rotationAngle;
    if (angle != 0) {
      final center = r.center;
      final dx = point.dx - center.dx;
      final dy = point.dy - center.dy;
      final cosA = math.cos(-angle);
      final sinA = math.sin(-angle);
      adjustedPoint = Offset(
        cosA * dx - sinA * dy + center.dx,
        sinA * dx + cosA * dy + center.dy,
      );
    }
  }
  final corners = [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight];
  final rotCenter = rotateHandlePos(state, r);
  final topCenter = r.topCenter;

  for (final corner in corners) {
    if ((adjustedPoint - corner).distance <= state.handleTouchRadius) return true;
  }
  if ((adjustedPoint - rotCenter).distance <= state.handleTouchRadius) return true;
  final distToLine = distanceToSegment(adjustedPoint, topCenter, rotCenter);
  if (distToLine <= state.handleTouchRadius * 0.7) return true;
  if (r.inflate(4).contains(adjustedPoint)) return true;
  return false;
}

DragAction hitHandle(_PainterPageState state, Rect bounds, Offset point) {
  final selected = state.selectedDrawable;
  if (selected is LineDrawable) {
    final a = lineStart(selected);
    final b = lineEnd(selected);
    if ((point - a).distance <= state.handleTouchRadius)
      return DragAction.resizeStart;
    if ((point - b).distance <= state.handleTouchRadius)
      return DragAction.resizeEnd;

    final rotCenter = rotateHandlePos(state, bounds);
    if ((point - rotCenter).distance <= state.handleTouchRadius)
      return DragAction.rotate;

    if (bounds.inflate(4).contains(point)) return DragAction.move;
    return DragAction.none;
  } else if (selected is ArrowDrawable) {
    final a = lineStart(selected);
    final b = lineEnd(selected);
    if ((point - a).distance <= state.handleTouchRadius)
      return DragAction.resizeStart;
    if ((point - b).distance <= state.handleTouchRadius)
      return DragAction.resizeEnd;

    final rotCenter = rotateHandlePos(state, bounds);
    if ((point - rotCenter).distance <= state.handleTouchRadius)
      return DragAction.rotate;

    if (bounds.inflate(4).contains(point)) return DragAction.move;
    return DragAction.none;
  }

  Offset adjusted = point;
  // 모든 회전 가능한 사각형 계열(ObjectDrawable, 선/화살표 제외)에 대해 포인터를 역회전
  if (selected is ObjectDrawable &&
      selected is! LineDrawable &&
      selected is! ArrowDrawable) {
    final angle = selected.rotationAngle;
    if (angle != 0) {
      final center = bounds.center;
      final dx = point.dx - center.dx;
      final dy = point.dy - center.dy;
      final cosA = math.cos(-angle);
      final sinA = math.sin(-angle);
      adjusted = Offset(
        cosA * dx - sinA * dy + center.dx,
        sinA * dx + cosA * dy + center.dy,
      );
    }
  }

  final corners = [
    bounds.topLeft,
    bounds.topRight,
    bounds.bottomLeft,
    bounds.bottomRight,
  ];
  final rotCenter = rotateHandlePos(state, bounds);

  if ((adjusted - corners[0]).distance <= state.handleTouchRadius)
    return DragAction.resizeNW;
  if ((adjusted - corners[1]).distance <= state.handleTouchRadius)
    return DragAction.resizeNE;
  if ((adjusted - corners[2]).distance <= state.handleTouchRadius)
    return DragAction.resizeSW;
  if ((adjusted - corners[3]).distance <= state.handleTouchRadius)
    return DragAction.resizeSE;
  if ((adjusted - rotCenter).distance <= state.handleTouchRadius)
    return DragAction.rotate;

  final distToLine = distanceToSegment(adjusted, bounds.topCenter, rotCenter);
  if (distToLine <= state.handleTouchRadius * 0.7) return DragAction.rotate;
  if (bounds.inflate(4).contains(adjusted)) return DragAction.move;
  return DragAction.none;
}

Offset rotateHandlePos(_PainterPageState state, Rect rect) =>
    Offset(rect.center.dx, rect.top - state.rotateHandleOffset);

Offset rotPoint(Offset point, Offset center, double angle) {
  final v = point - center;
  final ca = math.cos(angle), sa = math.sin(angle);
  return Offset(ca * v.dx - sa * v.dy, sa * v.dx + ca * v.dy) + center;
}

Offset toLocalVec(Offset worldPoint, Offset center, double angle) {
  final v = worldPoint - center;
  final cosA = math.cos(-angle), sinA = math.sin(-angle);
  return Offset(cosA * v.dx - sinA * v.dy, sinA * v.dx + cosA * v.dy);
}

Offset fromLocalVec(Offset localVec, Offset center, double angle) {
  final cosA = math.cos(angle), sinA = math.sin(angle);
  final w = Offset(
    cosA * localVec.dx - sinA * localVec.dy,
    sinA * localVec.dx + cosA * localVec.dy,
  );
  return center + w;
}

Offset toLocal(Offset worldPoint, Offset center, double angle) {
  final dx = worldPoint.dx - center.dx;
  final dy = worldPoint.dy - center.dy;
  final ca = math.cos(-angle);
  final sa = math.sin(-angle);
  return Offset(ca * dx - sa * dy, sa * dx + ca * dy);
}
