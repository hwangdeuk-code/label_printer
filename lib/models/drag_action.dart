/// 한글 주석: 드래그 동작 종류 정의
/// 선택/리사이즈/회전/이동 등의 편집 동작을 나타냅니다.

enum DragAction {
  none,
  move,
  rotate,
  resizeStart,
  resizeEnd,
  resizeNW,
  resizeNE,
  resizeSW,
  resizeSE,
}
