// UTF-8, 한국어 주석
// flutter_quill: ^11.4.2 기준 헬퍼 모음
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../models/tool.dart' as tool; // TxtAlign, Tool 등 공용 enum/모델

/// TxtAlign -> quill Attribute 매핑
quill.Attribute alignToAttr(tool.TxtAlign a) {
  switch (a) {
    case tool.TxtAlign.left:
      return quill.Attribute.leftAlignment;
    case tool.TxtAlign.center:
      return quill.Attribute.centerAlignment;
    case tool.TxtAlign.right:
      return quill.Attribute.rightAlignment;
  }
}

/// 현재 선택 영역의 스타일(굵게 활성화 여부 등)을 확인
bool isBoldOn(quill.QuillController c) =>
    c.getSelectionStyle().attributes.containsKey(quill.Attribute.bold.key);

bool isItalicOn(quill.QuillController c) =>
    c.getSelectionStyle().attributes.containsKey(quill.Attribute.italic.key);

/// 굵게 토글/강제설정
void applyBold(quill.QuillController c, {bool? value}) {
  final on = isBoldOn(c);
  final next = value ?? !on;
  c.formatSelection(
    next ? quill.Attribute.bold : quill.Attribute.clone(quill.Attribute.bold, null),
  );
}

/// 이탤릭 토글/강제설정
void applyItalic(quill.QuillController c, {bool? value}) {
  final on = isItalicOn(c);
  final next = value ?? !on;
  c.formatSelection(
    next ? quill.Attribute.italic : quill.Attribute.clone(quill.Attribute.italic, null),
  );
}

/// 폰트 크기 설정(문자열 값 사용). null이면 제거
void applyFontSize(quill.QuillController c, double? px) {
  final attr = quill.Attribute.clone(
    quill.Attribute.size, px == null ? null : px.toInt().toString(),
  );
  c.formatSelection(attr);
}

/// 정렬 적용
void applyAlign(quill.QuillController c, tool.TxtAlign a) {
  c.formatSelection(alignToAttr(a));
}

/// 복수 속성을 순차 적용
void applyAttributes(quill.QuillController c, List<quill.Attribute> attrs) {
  for (final a in attrs) {
    c.formatSelection(a);
  }
}
