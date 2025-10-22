import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:tabbed_view/tabbed_view.dart';

import 'package:label_printer/core/app.dart';
import 'package:label_printer/models/brand.dart';
import 'package:label_printer/home_page_manager_logic.dart';
import 'package:label_printer/models/customer.dart';
import 'package:label_printer/models/user.dart';
import 'package:label_printer/utils/on_messages.dart';

/// 로그인 이후 표시되는 본문 UI를 별도 파일로 분리한 위젯
class HomePageManager extends StatefulWidget {
  final String selectedBrand;
  final ValueChanged<String?> onBrandChanged;
  final String selectedLabelSize;
  final ValueChanged<String?> onLabelSizeChanged;

  const HomePageManager({
    super.key,
    required this.selectedBrand,
    required this.onBrandChanged,
    required this.selectedLabelSize,
    required this.onLabelSizeChanged,
  });

  @override
  State<HomePageManager> createState() => _HomePageManagerState();
}

class _HomePageManagerState extends State<HomePageManager> {
  static const cn = '_HomePageManagerState';
  final HomePageManagerLogic _logic = HomePageManagerLogic();
  late final TabbedViewController _tabController;
  final TextEditingController _tabSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabbedViewController(_buildInitialTabs());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _loadBrands();
      }
    });
  }

  Future<void> _loadBrands() async {
    const String fn = '_loadBrands';

    try {
      debugPrint('$cn.$fn: $START');
      BlockingOverlay.show(context, message: '사용자 데이터를 불러오고 있습니다...');

      final brands = await _logic.fetchBrands(Customer.instance!.customerId);

      if (!mounted) return;
      setState(() {});

      final resolved = _logic.resolveSelectedBrand(
        brands,
        widget.selectedBrand,
      );

      final fallback = _logic.firstBrandName(brands);

      if (resolved == null && fallback != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onBrandChanged(fallback);
        });
      }
    }
		finally {
      BlockingOverlay.hide();
      debugPrint('$cn.$fn: $END');
    }
  }

  List<TabData> _buildInitialTabs() {
    return [
      TabData(
        value: 'items',
        text: '품목관리(F1)',
        content: const _ItemManageTab(),
        closable: false,
      ),
      TabData(
        value: 'favorites',
        text: '공용라벨 관리(F2)',
        content: const _PlaceholderTab(title: '공용라벨 관리'),
        closable: false,
      ),
      TabData(
        value: 'promotion',
        text: '라벨출력(F3)',
        content: const _PlaceholderTab(title: '라벨출력'),
        closable: false,
      ),
      TabData(
        value: 'auto',
        text: '자동 품목갱신',
        content: const _PlaceholderTab(title: '자동 품목갱신'),
        closable: false,
      ),
      TabData(
        value: 'analysis',
        text: '저울출력',
        content: const _PlaceholderTab(title: '저울출력'),
        closable: false,
      ),
    ];
  }

  TabbedViewThemeData _buildTabbedTheme() {
    final theme = TabbedViewThemeData.minimalist(
      brightness: Brightness.light,
      colorSet: Colors.grey,
      fontSize: 13,
      tabRadius: 3,
    );

    theme.tabsArea
      ..color = const Color(0xFFF7F8FA)
      ..border = const BorderSide(color: Color(0xFFE6E6E6))
      ..initialGap = 0
      ..middleGap = 4
      ..buttonsGap = 0
      ..buttonColor = Colors.transparent
      ..hoveredButtonColor = Colors.transparent
      ..disabledButtonColor = Colors.transparent;

    theme.tab
      ..padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 10)
      ..paddingWithoutButton = const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 10,
      )
      ..textStyle = const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2429),
      )
      ..buttonsGap = 0
      ..buttonColor = Colors.transparent
      ..hoveredButtonColor = Colors.transparent
      ..disabledButtonColor = Colors.transparent
      ..buttonPadding = EdgeInsets.zero;

    theme.contentArea
      ..color = Colors.white
      ..padding = EdgeInsets.zero;

    theme.divider = const BorderSide(color: Color(0xFFE6E6E6));
    theme.isDividerWithinTabArea = true;

    return theme;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tabSearchController.dispose();
    super.dispose();
  }

  void _onTabSearch() {
    final query = _tabSearchController.text.trim();
    if (query.isEmpty) { return; }
    // TODO(hwang): 연동 시점에 맞춰 검색 로직을 주입합니다.
  }

  Widget _buildTabTrailing(BuildContext context) {
    final double fieldWidth = isDesktop ? 260.0 : 200.0;
    const double fieldHeight = 38.0;
    final theme = Theme.of(context);
    final Color buttonColor = theme.colorScheme.secondaryFixed;
    final Color onButtonColor = theme.colorScheme.onSecondaryFixed;

    return SizedBox(
      height: fieldHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: fieldWidth,
            child: TextField(
              controller: _tabSearchController,
              style: const TextStyle(fontSize: 12),
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onTabSearch(),
              decoration: InputDecoration(
                isDense: true,
                hintText: '검색어 입력',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: isDesktop ? 8 : 4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFCED4DA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFCED4DA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: fieldHeight - 10,
            child: FilledButton.icon(
              onPressed: _onTabSearch,
              icon: Icon(Icons.search, size: 14, color: onButtonColor),
              label: Text(
                '검색',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onButtonColor,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, fieldHeight - 10),
                maximumSize: const Size(double.infinity, fieldHeight - 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabbedView = TabbedViewTheme(
      data: _buildTabbedTheme(),
      child: TabbedView(
        controller: _tabController,
        tabReorderEnabled: false,
        trailing: _buildTabTrailing(context),
      ),
    );
    final brands = Brand.array ?? const <Brand>[];
    final brandItems = _logic.toDropdownItems(brands);
    final resolvedBrand = _logic.resolveSelectedBrand(
      brands,
      widget.selectedBrand,
    );

    return Column(
      children: [
        // 상단 컨트롤 영역
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Card(
            elevation: 2,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            child: _TopControlArea(
              selectedBrand: widget.selectedBrand,
              onBrandChanged: widget.onBrandChanged,
              selectedLabelSize: widget.selectedLabelSize,
              onLabelSizeChanged: widget.onLabelSizeChanged,
              brandItems: brandItems,
              resolvedBrand: resolvedBrand,
            ),
          ),
        ),

        // 탭 메뉴 + 콘텐츠를 카드 섹션으로 구성
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Card(
              elevation: 2,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE6E6E6)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [Expanded(child: tabbedView)]),
            ),
          ),
        ),
      ],
    );
  }
}

/// 상단 컨트롤 영역: 좌(회사/사용자), 우(브랜드 + 라벨크기 한 줄), 맨 우측 배너
class _TopControlArea extends StatelessWidget {
  final String selectedBrand;
  final ValueChanged<String?> onBrandChanged;
  final String selectedLabelSize;
  final ValueChanged<String?> onLabelSizeChanged;
  final List<DropdownMenuItem<String>> brandItems;
  final String? resolvedBrand;

  const _TopControlArea({
    required this.selectedBrand,
    required this.onBrandChanged,
    required this.selectedLabelSize,
    required this.onLabelSizeChanged,
    required this.brandItems,
    required this.resolvedBrand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), // 위젯 여백
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 왼쪽: 회사/사용자 (고정 너비)
            SizedBox(
              width: isDesktop ? 250 : 200,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFCED4DA)),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  '${Customer.instance?.customerName ?? ''} (${User.instance?.userId ?? ''})',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 가운데: 브랜드 + 라벨 (가변 너비)
            Row(
              children: [
                _DropdownField(
                  label: '브랜드',
                  value: resolvedBrand,
                  items: brandItems,
                  onChanged: brandItems.isEmpty ? null : onBrandChanged,
                  width: isDesktop ? 220 : 150, // 너비 설정
                  labelWidth: 48,
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(60, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('관리', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                _DropdownField(
                  label: '라벨',
                  value: selectedLabelSize,
                  items: const ['바코드 test2']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: onLabelSizeChanged,
                  width: isDesktop ? 220 : 150, // 너비 설정
                  labelWidth: 48,
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(60, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('관리', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            // 오른쪽: 대시보드 영역
            const Spacer(),
            // 미리보기
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 450 : 400,
              ), // 최대 너비 제한
              child: Container(
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Theme.of(context).cardColor,
                  image: isShowLogo
                      ? DecorationImage(
                          image: const AssetImage(
                            'assets/images/LogoPhone.webp',
                          ),
                          fit: BoxFit.fill,
                          alignment: Alignment.center,
                          colorFilter: ColorFilter.mode(
                            Theme.of(context).cardColor,
                            BlendMode.multiply,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;
  final double width;
  final double labelWidth;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
    this.width = 170,
    this.labelWidth = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            '$label:',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: width,
          child: DropdownButtonFormField2<String>(
            value: (value != null && value!.isNotEmpty) ? value : null,
            items: items,
            onChanged: (onChanged != null && items.isNotEmpty)
                ? onChanged
                : null,
            style: const TextStyle(fontSize: 13, color: Colors.black),
            isExpanded: true,
            buttonStyleData: const ButtonStyleData(
              height: 28,
              padding: EdgeInsets.symmetric(horizontal: 2),
            ),
            dropdownStyleData: DropdownStyleData(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            menuItemStyleData: const MenuItemStyleData(height: 28),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFCED4DA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFCED4DA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemManageTab extends StatelessWidget {
  const _ItemManageTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 그리드 헤더(남색 바)
        Container(
          color: const Color(0xFF0E2F66),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: const [
              _HeaderCell(text: '발행', width: 60),
              _HeaderCell(text: '라벨크기', width: 100),
              _HeaderCell(text: '품명', width: 280),
              _HeaderCell(text: '주원료', width: 180),
              _HeaderCell(text: '바코드', width: 180),
            ],
          ),
        ),
        // 리스트(샘플 한 줄)
        Expanded(
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              return Container(
                height: 28,
                decoration: BoxDecoration(
                  color: index.isEven ? Colors.white : const Color(0xFFF2F4F7),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE6E8EB)),
                  ),
                ),
                child: Row(
                  children: const [
                    _BodyCell(text: '', width: 60),
                    _BodyCell(text: '바코드 test2', width: 100),
                    _BodyCell(text: '바코드 test2', width: 280),
                    _BodyCell(text: '', width: 180),
                    _BodyCell(text: 'R004055000001', width: 180),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  const _HeaderCell({required this.text, required this.width});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final double width;
  const _BodyCell({required this.text, required this.width});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  const _PlaceholderTab({required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title (준비 중)'));
  }
}
