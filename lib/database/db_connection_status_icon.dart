import 'package:flutter/material.dart';
import 'package:label_printer/database/db_connection_status.dart';

/// AppBar 액션 영역에서 사용할 원형 상태 아이콘
class DbConnectionStatusIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const DbConnectionStatusIcon({super.key, this.onTap, this.padding = const EdgeInsets.symmetric(horizontal: 6)});

  @override
  Widget build(BuildContext context) {
    final hub = DbConnectionStatus.instance;
    return Padding(
      padding: padding,
      child: ValueListenableBuilder<bool?>(
        valueListenable: hub.up,
        builder: (context, up, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: hub.reconnecting,
            builder: (context, reconnecting, __) {
              Color color;
              IconData icon;
              String tip;
              if (up == null) {
                color = const Color(0xFF9E9E9E);
                icon = Icons.help_outline;
                tip = '서버 상태: 확인 중';
              } else if (up) {
                color = const Color(0xFF2E7D32);
                icon = Icons.circle;
                tip = '서버 상태: 연결 양호';
              } else {
                color = const Color(0xFFC62828);
                icon = reconnecting ? Icons.sync : Icons.error_outline;
                tip = reconnecting ? '서버 상태: 끊김 - 재연결 중' : '서버 상태: 끊김';
              }

              final child = Icon(icon, size: 18, color: color);
              return Tooltip(
                message: tip,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onTap,
                  child: SizedBox(width: 32, height: 32, child: Center(child: child)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
