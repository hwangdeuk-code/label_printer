// UTF-8, 한국어 주석
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:label_printer/core/app.dart';
import 'package:label_printer/models/login_event.dart';

/// 공통(데스크톱/태블릿) 로그인 이력 조회 페이지
class LoginHistoryPage extends StatefulWidget {
  const LoginHistoryPage({super.key});

  @override
  State<LoginHistoryPage> createState() => _LoginHistoryPageState();
}

class _LoginHistoryPageState extends State<LoginHistoryPage> {
  // 필터 상태
  late DateTime _from;
  late DateTime _to;
  String? _selectedCompany;
  String? _selectedPartner;
  final TextEditingController _keywordCtrl = TextEditingController();
  final ScrollController _tableScrollController = ScrollController();

  // 목록 상태
  List<LoginEvent> _rows = [];
  bool _loading = false;
  bool _intlReady = false;

  late DateFormat _dateFmt;
  late DateFormat _timeFmt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 27)); // 최근 4주

    // 세션에서 기본 회사명/협력업체 힌트 (없으면 null)
    _selectedCompany = gUserSession?.companyName;
    _selectedPartner = gUserSession?.branchName;

    _initIntlAndQuery();
  }

  Future<void> _initIntlAndQuery() async {
    // 기본 포맷(시스템 로케일)으로 먼저 세팅
    _dateFmt = DateFormat('yyyy-MM-dd');
    _timeFmt = DateFormat('a hh:mm:ss');
    try {
      await initializeDateFormatting('ko_KR', null);
      _dateFmt = DateFormat('yyyy-MM-dd', 'ko_KR');
      _timeFmt = DateFormat('a hh:mm:ss', 'ko_KR');
      _intlReady = true;
    } catch (_) {
      _intlReady = false;
    }
    await _query();
    if (mounted) setState(() {});
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _to = picked);
  }

  // 실제로는 서버에서 받아오면 됨. 지금은 데모 데이터를 생성한다.
  Future<void> _query() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    final demo = <LoginEvent>[];
    final base = DateTime(
      _to.year,
      _to.month,
      _to.day,
    ).subtract(const Duration(days: 7));
    for (int i = 0; i < 28; i++) {
      final timestamp = base.add(Duration(hours: 6 + i * 3));
      demo.add(
        LoginEvent(
          userId: '5931I103',
          userGrade: i.isEven ? '책임자' : '관리자',
          timestamp: timestamp,
          action: i % 3 == 0 ? '로그아웃' : '로그인',
          ip: '192.1.${i % 10}',
          companyName: _selectedCompany ?? '한길만푸드 250731',
          programVersion: '2.7.5.${2 + (i % 3)}',
        ),
      );
    }
    setState(() {
      _rows = demo;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = _buildToolbar(context);
    final table = _buildTable(context);

    return Scaffold(
      appBar: AppBar(title: const Text('사용자 접속 이력')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: header,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: table),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final dateRange = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DateButton(label: _dateFmt.format(_from), onTap: _pickFrom),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(' - '),
        ),
        _DateButton(label: _dateFmt.format(_to), onTap: _pickTo),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _query,
          icon: const Icon(Icons.search),
          label: const Text('검색'),
        ),
      ],
    );

    final dropdowns = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LabeledDropdown(
          label: '거래처 이름',
          value: _selectedCompany,
          items: {
            if (_selectedCompany != null) _selectedCompany!,
            '한길만푸드 250731',
            '미소식품 251012',
            '그린유통 250991',
          }.toList(),
          onChanged: (v) => setState(() => _selectedCompany = v),
          width: 220,
        ),
        const SizedBox(width: 12),
        _LabeledDropdown(
          label: '협력 업체',
          value: _selectedPartner,
          items: {
            if (_selectedPartner != null) _selectedPartner!,
            '하이웨이엔지',
            '지노모터리스',
            '푸른빛테크',
          }.toList(),
          onChanged: (v) => setState(() => _selectedPartner = v),
          width: 160,
        ),
      ],
    );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [dateRange, dropdowns],
    );
  }

  Widget _buildTable(BuildContext context) {
    final columns = const <DataColumn>[
      DataColumn(label: Text('사용자 ID')),
      DataColumn(label: Text('사용자 등급')),
      DataColumn(label: Text('시간')),
      DataColumn(label: Text('로그인/로그아웃')),
      DataColumn(label: Text('IP주소')),
      DataColumn(label: Text('거래처 이름')),
      DataColumn(label: Text('프로그램 버전')),
    ];

    final rows = _rows.map((e) {
      final day = _dateFmt.format(e.timestamp);
      final time = _timeFmt.format(e.timestamp);
      return DataRow(
        cells: [
          DataCell(Text(e.userId)),
          DataCell(Text(e.userGrade)),
          DataCell(Text('$day $time')),
          DataCell(Text(e.action)),
          DataCell(Text(e.ip)),
          DataCell(Text(e.companyName)),
          DataCell(Text(e.programVersion)),
        ],
      );
    }).toList();

    final table = DataTable(
      headingRowHeight: 40, // 헤더의 높이를 지정합니다.
      columns: columns,
      rows: rows,
      headingRowColor: WidgetStateProperty.resolveWith(
        (_) => const Color(0xFFEFF3F6),
      ),
      dataRowMinHeight: 34,
      dataRowMaxHeight: 34,
      columnSpacing: 22,
      showCheckboxColumn: false,
    );

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(128),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Scrollbar(
          controller: _tableScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            // Vertical scroll
            controller: _tableScrollController,
            primary: false,
            child: SizedBox(width: double.infinity, child: table),
          ), // Horizontal scroll is removed
        ),
      ),
    );
  }
}

/// 날짜 버튼(스크린샷의 콤보 느낌을 심플하게 표현)
class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.date_range, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}

/// 라벨 + Dropdown 일체형
class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final double width;
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          DropdownButtonFormField<String>(
            isDense: true,
            isExpanded: true,
            initialValue: value ?? (items.isNotEmpty ? items.first : null),
            items: items
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
