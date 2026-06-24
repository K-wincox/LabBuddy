import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:labbuddy_android/main.dart';

Finder findFormulaEditorTitle({bool skipOffstage = true}) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data == '自定义公式' &&
        widget.style?.fontWeight == FontWeight.w900,
    skipOffstage: skipOffstage,
  );
}

void main() {
  const timerChannel = MethodChannel('labbuddy/timers');
  const dataCardChannel = MethodChannel('labbuddy/data_card');
  const platformChannel = MethodChannel('flutter/platform', JSONMethodCodec());
  String? clipboardText;
  Map<String, dynamic>? lastDataCardPayload;

  setUp(() {
    clipboardText = null;
    lastDataCardPayload = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timerChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(dataCardChannel, (call) async {
          if (call.method == 'saveDataCard' || call.method == 'shareDataCard') {
            lastDataCardPayload = Map<String, dynamic>.from(
              call.arguments as Map,
            );
            return '/tmp/labbuddy-data-card.png';
          }
          if (call.method == 'pickDataCardImage') return null;
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            clipboardText = args['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return clipboardText == null ? null : {'text': clipboardText};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timerChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(dataCardChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformChannel, null);
  });

  testWidgets('IosProgressBar renders a bounded iOS-style track', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: IosProgressBar(value: 1.4, color: Colors.teal),
          ),
        ),
      ),
    );

    expect(find.byType(IosProgressBar), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsOneWidget);
    final fill = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fill.widthFactor, 1);
  });

  testWidgets('Theme uses iOS-style LabBuddy surface tokens', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LabBuddyAndroidApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(context);

    expect(theme.scaffoldBackgroundColor, const Color(0xFFF2F7F7));
    expect(theme.cardTheme.color, const Color(0xFFFFFFFC));
    expect(theme.inputDecorationTheme.fillColor, const Color(0xFFE6F2F2));
    expect(theme.bottomSheetTheme.backgroundColor, const Color(0xFFFFFFFC));
    expect(theme.bottomSheetTheme.showDragHandle, isTrue);
  });

  testWidgets('Shell renders iOS-style full-width tab bar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.isAuthenticated = true;
    store.todayRuns = [sampleRuns.first];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: LabBuddyShell(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('Protocol'), findsOneWidget);
    expect(find.text('工具'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    final tabContainer = tester
        .widgetList<Container>(find.byType(Container))
        .where((container) => container.constraints == null)
        .toList();
    expect(tabContainer.isNotEmpty, isTrue);
  });

  testWidgets('LabBuddy Android shows the local demo login gate', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LabBuddyAndroidApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(
      find.text('使用演示账号进入').evaluate().isNotEmpty ||
          find.text('今日工作台').evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('Auth gate uses preset local demo credentials', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(MaterialApp(home: AuthScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Wincox'), findsNothing);
    expect(find.text('2388504180@qq.com'), findsNothing);
    expect(find.text(demoLoginEmail), findsWidgets);
    expect(find.text(demoLoginPassword), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, '演示密码'),
      'wrong-password',
    );
    await tester.tap(find.text('使用演示账号进入'));
    await tester.pumpAndSettle();

    expect(store.isAuthenticated, isFalse);
    expect(find.text('邮箱或密码不正确，请使用页面上的演示账号。'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '演示密码'),
      demoLoginPassword,
    );
    await tester.tap(find.text('使用演示账号进入'));
    await tester.pumpAndSettle();

    expect(store.isAuthenticated, isTrue);
    expect(store.userName, demoLoginName);
    expect(store.userEmail, demoLoginEmail);
  });

  testWidgets('App shows iOS-style new day rollover prompt', (
    WidgetTester tester,
  ) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final today = sampleRuns.first.copyWith(id: 'new-day-today', status: '进行中');
    final tomorrow = sampleRuns[1].copyWith(
      id: 'new-day-tomorrow',
      status: '明日计划',
    );
    SharedPreferences.setMockInitialValues({
      'auth': jsonEncode({
        'isAuthenticated': true,
        'userName': 'New Day User',
        'userEmail': 'newday@labbuddy.test',
        'labName': 'New Day Lab',
      }),
      'labBuddyData': jsonEncode({
        'todayRuns': [today.toJson()],
        'tomorrowRuns': [tomorrow.toJson()],
        'pastRuns': <Map<String, dynamic>>[],
        'lastOpenDate': yesterdayKey,
      }),
    });

    await tester.pumpWidget(const LabBuddyAndroidApp());
    await tester.pumpAndSettle();

    expect(find.text('检测到新的一天'), findsOneWidget);
    expect(find.text('是否将昨天的实验归档，并将明天的计划移入今天？'), findsOneWidget);
    expect(find.text('开始新的一天'), findsOneWidget);
    expect(find.text('暂时保持现状'), findsOneWidget);

    await tester.tap(find.text('开始新的一天'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final data = jsonDecode(prefs.getString('labBuddyData')!) as Map;
    final todayRuns = data['todayRuns'] as List;
    final pastRuns = data['pastRuns'] as List;
    expect(todayRuns.single['id'], 'new-day-tomorrow');
    expect(todayRuns.single['status'], '已排期');
    expect(pastRuns.single['id'], startsWith('past-'));
    expect(pastRuns.single['status'], '进行中');
    expect(data['tomorrowRuns'], isEmpty);
  });

  testWidgets('Protocol editor exposes iOS-style structured fields', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProtocolEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新增 Protocol'), findsOneWidget);
    expect(
      find.byKey(const Key('protocol-editor-cancel-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('protocol-editor-save-button')),
      findsOneWidget,
    );
    expect(find.text('保存 Protocol'), findsNothing);
    expect(find.text('基准体积'), findsOneWidget);
    expect(find.text('预计时长'), findsOneWidget);
    expect(find.text('单位'), findsWidgets);
    expect(find.text('单位定义'), findsOneWidget);
    expect(find.text('配方成分'), findsOneWidget);

    final topFieldsBeforeScroll = tester.widgetList<TextField>(
      find.byType(TextField),
    );
    expect(
      topFieldsBeforeScroll.any((field) => field.controller?.text == '50'),
      isTrue,
    );
    expect(
      topFieldsBeforeScroll.any((field) => field.controller?.text == '15'),
      isTrue,
    );
    expect(
      topFieldsBeforeScroll.any((field) => field.controller?.text == '成分 A'),
      isTrue,
    );

    await tester.scrollUntilVisible(
      find.text('公式变量'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('公式变量'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();

    expect(find.text('实验步骤'), findsOneWidget);
    expect(find.text('增加试剂'), findsWidgets);

    final stepFields = tester.widgetList<TextField>(find.byType(TextField));
    expect(stepFields.any((field) => field.controller?.text == '第一步'), isTrue);
    expect(
      stepFields.any((field) => field.controller?.text == '填写操作条件'),
      isTrue,
    );
  });

  testWidgets('Protocol editor reagent rows use iOS-style inline delete', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = LabProtocol(
      id: 'protocol-inline-reagent-delete',
      name: '试剂删除 Protocol',
      area: '细胞实验',
      expectedDuration: '15 min',
      baseVolumeLabel: '50 ml',
      baseScaleValue: 50,
      scaleUnit: 'ml',
      ingredients: const [],
      variables: const [],
      steps: const [
        LabStep(
          id: 'step-inline-delete',
          title: '配制',
          detail: '删除试剂测试',
          durationMinutes: null,
          carryOver: false,
          reagents: [
            StepReagent(
              id: 'reagent-inline-delete',
              name: '待删除试剂',
              amountExpression: '1',
              unit: 'ml',
            ),
          ],
        ),
      ],
    );
    store.protocols = [protocol];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProtocolEditorSheet(store: store, existing: protocol),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('待删除试剂'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('待删除试剂'), findsOneWidget);
    expect(find.byTooltip('删除试剂'), findsOneWidget);

    await tester.tap(find.byTooltip('删除试剂'));
    await tester.pumpAndSettle();

    expect(find.text('删除试剂？'), findsNothing);
    expect(find.text('待删除试剂'), findsNothing);

    await tester.tap(find.byKey(const Key('protocol-editor-save-button')));
    await tester.pumpAndSettle();

    expect(store.protocols.single.steps.single.reagents, isEmpty);
  });

  testWidgets('Protocol variable units use iOS-style unit picker', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.customUnits = ['mM'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProtocolEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('公式变量'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    const addVariableButton = Key('protocol-add-variable-button');
    await tester.tap(find.byKey(addVariableButton));
    await tester.pumpAndSettle();

    final unitDropdowns = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .toList();
    expect(unitDropdowns, isNotEmpty);

    final visibleFields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      visibleFields.any((field) => field.controller?.text == '新变量'),
      isTrue,
    );
    expect(
      visibleFields.any((field) => field.controller?.text == 'v1'),
      isTrue,
    );
    expect(find.text('公式符号'), findsWidgets);
    expect(find.text('最小值'), findsWidgets);
    expect(find.text('最大值'), findsWidgets);
    expect(find.textContaining('公式中使用：'), findsWidgets);
    expect(
      visibleFields.any((field) => field.decoration?.hintText == '单位'),
      isFalse,
    );
  });

  testWidgets('Protocol editor saves iOS-style structured scale and duration', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProtocolEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    fields
            .firstWhere((field) => field.decoration?.labelText == '基准体积')
            .controller
            ?.text =
        '50';
    fields
            .firstWhere((field) => field.decoration?.labelText == '预计时长')
            .controller
            ?.text =
        '2';
    await tester.pump();

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ml').last);
    await tester.pumpAndSettle();

    await tester.tap(dropdowns.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('h').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('protocol-editor-save-button')));
    await tester.pumpAndSettle();

    expect(store.protocols.first.baseVolumeLabel, '50 ml');
    expect(store.protocols.first.baseScaleValue, 50);
    expect(store.protocols.first.scaleUnit, 'ml');
    expect(store.protocols.first.expectedDuration, '2 h');
  });

  testWidgets('Protocol editor opens iOS-style formula picker sheet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = LabProtocol(
      id: 'protocol-formula-picker',
      name: '公式 Protocol',
      area: '细胞实验',
      baseVolumeLabel: '1 reaction',
      baseScaleValue: 10,
      scaleUnit: 'ml',
      expectedDuration: '20 min',
      ingredients: const [],
      variables: const [
        ProtocolVariable(
          id: 'var-total',
          symbol: 'V_total',
          name: '总体积',
          baseValue: 10,
          unit: 'ml',
          isScalable: true,
        ),
      ],
      steps: const [
        LabStep(
          id: 'formula-step',
          title: '配制反应',
          detail: '按变量计算试剂体积',
          durationMinutes: 10,
          carryOver: false,
          reagents: [
            StepReagent(
              id: 'formula-reagent',
              name: 'Buffer',
              amountExpression: '',
              unit: 'ml',
              isFormula: true,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProtocolEditorSheet(store: store, existing: protocol),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('公式变量'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('最小值'), findsWidgets);
    expect(find.text('最大值'), findsWidgets);
    final variableFields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      variableFields.any((field) => field.controller?.text == 'V_total'),
      isTrue,
    );

    await tester.scrollUntilVisible(
      find.text('输入公式'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('输入公式'), findsOneWidget);

    await tester.tap(find.text('输入公式'));
    await tester.pumpAndSettle();

    expect(find.text('插入公式'), findsOneWidget);
    expect(find.text('点击插入变量'), findsOneWidget);
    expect(find.text('运算符'), findsOneWidget);
    expect(find.text('总体积'), findsWidgets);

    await tester.tap(find.text('总体积').last);
    await tester.pumpAndSettle();
    final formulaFields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      formulaFields.any((field) => field.controller?.text == '总体积'),
      isTrue,
    );
    expect(
      formulaFields.any((field) => field.controller?.text == 'V_total'),
      isFalse,
    );
    expect(find.text('10 ml'), findsOneWidget);

    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();
    final operatorFormulaFields = tester.widgetList<TextField>(
      find.byType(TextField),
    );
    expect(
      operatorFormulaFields.any((field) => field.controller?.text == '总体积 * '),
      isTrue,
    );

    await tester.tap(find.byTooltip('清空公式'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('总体积').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('总体积').last);
    await tester.pumpAndSettle();
    final multipliedFormulaFields = tester.widgetList<TextField>(
      find.byType(TextField),
    );
    expect(
      multipliedFormulaFields.any(
        (field) => field.controller?.text == '总体积 * 总体积',
      ),
      isTrue,
    );
  });

  testWidgets('Step reagent infers legacy formula expressions like iOS', (
    WidgetTester tester,
  ) async {
    final formulaReagent = StepReagent.fromJson({
      'id': 'legacy-formula',
      'name': 'Buffer',
      'amountExpression': 'V_total * 0.9',
      'unit': 'ml',
    });
    final fixedReagent = StepReagent.fromJson({
      'id': 'legacy-fixed',
      'name': 'Water',
      'amountExpression': '125',
      'unit': 'μl',
    });

    expect(formulaReagent.isFormula, isTrue);
    expect(fixedReagent.isFormula, isFalse);
  });

  testWidgets('Protocol formula picker inserts symbol fallback like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = LabProtocol(
      id: 'protocol-token-fallback',
      name: '公式变量回退',
      area: '细胞实验',
      expectedDuration: '15 min',
      baseVolumeLabel: '50 ml',
      baseScaleValue: 50,
      scaleUnit: 'ml',
      ingredients: const [],
      variables: const [
        ProtocolVariable(
          id: 'variable-symbol',
          symbol: 'v1',
          name: '',
          baseValue: 2,
          unit: 'ml',
          isScalable: true,
        ),
      ],
      steps: const [
        LabStep(
          id: 'step-symbol',
          title: '公式步骤',
          detail: '检查变量符号回退',
          durationMinutes: null,
          carryOver: false,
          reagents: [
            StepReagent(
              id: 'reagent-symbol',
              name: '试剂',
              amountExpression: '',
              unit: 'ml',
              isFormula: true,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProtocolEditorSheet(store: store, existing: protocol),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('输入公式'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final formulaButton = find
        .ancestor(of: find.text('输入公式'), matching: find.byType(TextButton))
        .first;
    await tester.ensureVisible(formulaButton);
    await tester.pumpAndSettle();
    await tester.tap(formulaButton);
    await tester.pumpAndSettle();

    expect(find.text('点击插入变量'), findsOneWidget);
    expect(find.text('v1'), findsWidgets);

    await tester.tap(find.text('v1').last);
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.any((field) => field.controller?.text == 'v1'), isTrue);
  });

  testWidgets('Protocol editor shows iOS-style consistency issues', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = LabProtocol(
      id: 'protocol-consistency-issues',
      name: '一致性检查 Protocol',
      area: '细胞实验',
      expectedDuration: '15 min',
      baseVolumeLabel: '50 ml',
      baseScaleValue: 50,
      scaleUnit: 'ml',
      ingredients: const [],
      variables: const [
        ProtocolVariable(
          id: 'variable-a',
          symbol: 'v1',
          name: '变量 A',
          baseValue: 1,
          unit: 'ml',
          isScalable: true,
        ),
        ProtocolVariable(
          id: 'variable-b',
          symbol: 'v1',
          name: '变量 B',
          baseValue: 2,
          unit: 'ml',
          isScalable: true,
        ),
      ],
      steps: const [
        LabStep(
          id: 'step-missing-ref',
          title: '公式步骤',
          detail: '引用不存在变量',
          durationMinutes: null,
          carryOver: false,
          reagents: [
            StepReagent(
              id: 'reagent-missing-ref',
              name: 'Buffer',
              amountExpression: 'missingVar * 2',
              unit: 'ml',
              isFormula: true,
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProtocolEditorSheet(store: store, existing: protocol),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('protocol-consistency-issues-panel')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('一致性检查'), findsOneWidget);
    expect(find.text('步骤引用了未定义变量 missingVar'), findsOneWidget);
    expect(find.text('变量 v1 重复定义'), findsOneWidget);
  });

  testWidgets('Protocol editor preserves iOS-style source metadata', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = sampleProtocols.first;
    store.protocols = [protocol];
    await store.upsertProtocol(
      existingId: protocol.id,
      name: protocol.name,
      area: protocol.area,
      duration: protocol.expectedDuration,
      scale: protocol.baseVolumeLabel,
      baseScaleValue: protocol.baseScaleValue,
      scaleUnit: protocol.scaleUnit,
      ingredients: protocol.ingredients,
      variables: protocol.variables,
      steps: protocol.steps,
      sourceTitle: 'TIANGEN DP304 用户提供手册',
      confidence: 0.82,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProtocolEditorSheet(
            store: store,
            existing: store.protocols.first,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('来源'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('来源'), findsOneWidget);
    expect(find.text('来源类型'), findsOneWidget);
    expect(find.text('来源标题'), findsNothing);
    expect(find.text('识别置信度'), findsNothing);

    await tester.tap(find.byKey(const Key('protocol-editor-save-button')));
    await tester.pumpAndSettle();

    final saved = store.protocols.firstWhere((item) => item.id == protocol.id);
    expect(saved.sourceTitle, 'TIANGEN DP304 用户提供手册');
    expect(saved.confidence, 0.82);
  });

  testWidgets('Protocol editor saves iOS-style source type metadata', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProtocolEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('来源'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('来源类型'), findsOneWidget);

    final sourceTypeDropdown = find
        .byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<String> &&
              widget.decoration.labelText == '来源类型',
        )
        .first;
    await tester.tap(sourceTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('文献').last);
    await tester.pumpAndSettle();
    expect(find.text('来源标题'), findsNothing);
    expect(find.text('识别置信度'), findsNothing);

    await tester.tap(find.byKey(const Key('protocol-editor-save-button')));
    await tester.pumpAndSettle();

    expect(store.protocols.first.sourceType, '文献');
    expect(store.protocols.first.sourceTitle, '文献');
  });

  testWidgets('Protocol editor defaults new manual source like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProtocolEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('来源'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('手动创建'), findsOneWidget);
    expect(find.text('来源标题'), findsNothing);
    expect(find.text('识别置信度'), findsNothing);

    await tester.tap(find.byKey(const Key('protocol-editor-save-button')));
    await tester.pumpAndSettle();

    expect(store.protocols.first.sourceType, '手动创建');
    expect(store.protocols.first.sourceTitle, '手动创建');
  });

  testWidgets('Protocol extraction exposes iOS-style source workflow', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    LabProtocol? extracted;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  extracted = await showModalBottomSheet<LabProtocol>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ProtocolExtractionSheet(store: store),
                  );
                },
                child: const Text('打开提取'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开提取'));
    await tester.pumpAndSettle();

    expect(find.text('提取 Protocol 草稿'), findsOneWidget);
    expect(find.text('选择 PDF/文本'), findsOneWidget);
    expect(find.text('导入文本'), findsOneWidget);
    expect(find.text('图片/OCR'), findsOneWidget);
    expect(find.text('粘贴 OCR'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('草稿预览'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('草稿预览'), findsOneWidget);
    expect(find.text('生成草稿并继续编辑'), findsOneWidget);

    await tester.tap(find.text('生成草稿并继续编辑'));
    await tester.pumpAndSettle();

    expect(extracted, isNotNull);
    expect(extracted!.steps, isNotEmpty);
  });

  testWidgets('Protocol detail exposes iOS-style variable adjustment panel', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = sampleProtocols.first;
    store.protocols = [protocol];

    await tester.pumpWidget(
      MaterialApp(
        home: ProtocolDetailScreen(store: store, protocol: protocol),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('公式变量'), findsOneWidget);
    expect(find.text(protocol.variables.first.name), findsWidgets);

    final variableField = find
        .descendant(
          of: find.byType(ProtocolVariableAdjustCard),
          matching: find.byType(TextField),
        )
        .first;
    await tester.enterText(variableField, '2');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('配方'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('配方'), findsOneWidget);
    expect(find.textContaining(protocol.ingredients.first.unit), findsWidgets);
  });

  testWidgets('Protocol detail exposes iOS-style share action', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = sampleProtocols.first;

    await tester.pumpWidget(
      MaterialApp(
        home: ProtocolDetailScreen(store: store, protocol: protocol),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('分享 Protocol'), findsOneWidget);

    await tester.tap(find.byTooltip('分享 Protocol'));
    await tester.pumpAndSettle();

    expect(lastDataCardPayload, isNotNull);
    expect(lastDataCardPayload!['kind'], 'protocol');
    expect(lastDataCardPayload!['title'], protocol.name);
    expect(lastDataCardPayload!['subtitle'], protocol.area);
    final lines = List<String>.from(lastDataCardPayload!['lines'] as List);
    expect(lines, contains('类型: ${protocol.area}'));
    expect(lines.any((line) => line.startsWith('配方:')), isTrue);
    expect(lines.any((line) => line.startsWith('步骤:')), isTrue);
  });

  testWidgets('Protocol detail supports iOS-style focused step navigation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = sampleProtocols.first;
    store.protocols = [protocol];

    await tester.pumpWidget(
      MaterialApp(
        home: ProtocolDetailScreen(store: store, protocol: protocol),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('实验步骤'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(protocol.steps.first.title).first);
    await tester.pumpAndSettle();

    expect(find.text('第 1 步 / 共 ${protocol.steps.length} 步'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.text('第 2 步 / 共 ${protocol.steps.length} 步'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);
    expect(find.byTooltip('关闭聚焦步骤'), findsOneWidget);
  });

  testWidgets('Bench mode exposes step editing and custom timer flow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.todayRuns = [sampleRuns.first];

    await tester.pumpWidget(
      MaterialApp(
        home: BenchModeScreen(
          store: store,
          run: sampleRuns.first,
          readonly: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('编辑全部步骤'), findsOneWidget);
    expect(find.byTooltip('编辑此步骤'), findsWidgets);

    await tester.tap(find.byTooltip('编辑全部步骤'));
    await tester.pumpAndSettle();
    expect(find.text('编辑详细步骤'), findsOneWidget);
    expect(find.text('准备完全培养基'), findsWidgets);

    Navigator.of(tester.element(find.text('编辑详细步骤'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.timer_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('自定义计时时长'), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNWidgets(3));
    expect(find.text('开始计时'), findsOneWidget);
  });

  testWidgets('Bench step editor appends iOS-style numbered substeps', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final run = sampleRuns.first.copyWith(
      steps: [
        sampleRuns.first.steps.first.copyWith(
          id: 'substep-edit-step',
          detail: '原始说明',
          durationMinutes: null,
        ),
      ],
    );
    store.todayRuns = [run];

    await tester.pumpWidget(
      MaterialApp(
        home: BenchModeScreen(store: store, run: run, readonly: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑此步骤').first);
    await tester.pumpAndSettle();

    expect(find.text('编辑步骤'), findsOneWidget);
    expect(find.text('添加分步骤'), findsOneWidget);
    expect(find.text('需要计时'), findsOneWidget);

    await tester.tap(find.text('添加分步骤'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存步骤'));
    await tester.pumpAndSettle();

    expect(store.todayRuns.first.steps.first.detail, contains('原始说明'));
    expect(store.todayRuns.first.steps.first.detail, contains('1. 新分步骤'));
    expect(store.todayRuns.first.steps.first.durationMinutes, isNull);
  });

  testWidgets('Today timeline exposes direct step edit and timer actions', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.todayRuns = [sampleRuns.first];
    store.projects = const [
      LabProject(id: 'proj-detail', name: '详情项目', colorValue: 0xFF00C7BE),
    ];

    await tester.pumpWidget(MaterialApp(home: TodayScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('步骤'), findsWidgets);
    expect(find.text('Timer'), findsWidgets);

    await tester.tap(find.text('步骤').first);
    await tester.pumpAndSettle();
    expect(find.text('编辑实验详情'), findsOneWidget);
    expect(find.text('保存实验详情'), findsNothing);
    expect(find.byKey(const Key('run-detail-save-button')), findsOneWidget);
    expect(find.text('实验信息'), findsOneWidget);
    expect(find.text('详细步骤'), findsOneWidget);
    expect(find.text('项目'), findsOneWidget);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    fields.first.controller?.text = '更新后的实验';

    await tester.tap(find.text('时间').last);
    await tester.pumpAndSettle();
    expect(find.text('选择实验时间'), findsOneWidget);
    expect(find.byKey(const Key('run-time-cancel-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('run-time-cancel-button')));
    await tester.pumpAndSettle();
    expect(find.text('选择实验时间'), findsNothing);

    await tester.tap(find.text('时间').last);
    await tester.pumpAndSettle();
    final hourPicker = tester.widget<CupertinoPicker>(
      find.descendant(
        of: find.byKey(const Key('run-time-hour-wheel')),
        matching: find.byType(CupertinoPicker),
      ),
    );
    final minutePicker = tester.widget<CupertinoPicker>(
      find.descendant(
        of: find.byKey(const Key('run-time-minute-wheel')),
        matching: find.byType(CupertinoPicker),
      ),
    );
    hourPicker.onSelectedItemChanged?.call(8);
    minutePicker.onSelectedItemChanged?.call(1);
    await tester.pump();
    await tester.tap(find.text('应用时间'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(store.todayRuns.first.title, '更新后的实验');
    expect(store.todayRuns.first.timeLabel, '08:15');
  });

  testWidgets('Today run detail includes iOS-style active timer controls', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final run = sampleRuns.first;
    final step = run.steps.first;
    store.todayRuns = [run];
    store.timers = [
      LabTimer(
        id: '${run.id}-${step.id}',
        runId: run.id,
        runTitle: run.title,
        stepTitle: step.title,
        endsAtMs: DateTime.now()
            .add(const Duration(minutes: 3))
            .millisecondsSinceEpoch,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunDetailEditorSheet(store: store, run: run),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('编辑实验详情'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('运行中的计时器'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('运行中的计时器'), findsOneWidget);
    expect(find.text(step.title), findsWidgets);
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    await tester.tap(find.text('暂停'));
    await tester.pumpAndSettle();
    expect(store.timers.single.isPaused, isTrue);
  });

  testWidgets('Today run detail supports per-step edit and timer like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final run = sampleRuns.first;
    store.todayRuns = [run];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunDetailEditorSheet(store: store, run: run),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Timer'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, '步骤'), findsWidgets);

    await tester.tap(find.byTooltip('编辑此步骤').first);
    await tester.pumpAndSettle();
    expect(find.text('编辑步骤'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, '步骤名称').last,
      '详情页单步编辑',
    );
    await tester.tap(find.text('保存步骤'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.controller?.text == '详情页单步编辑'),
      isTrue,
    );

    await tester.tap(find.byTooltip('计时此步骤').first);
    await tester.pumpAndSettle();
    expect(find.text('自定义计时时长'), findsOneWidget);
    expect(find.byKey(const Key('custom-timer-cancel-button')), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('custom-timer-cancel-button')));
    await tester.pumpAndSettle();
    expect(find.text('自定义计时时长'), findsNothing);
    expect(store.timers, isEmpty);

    await tester.tap(find.byTooltip('计时此步骤').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始计时'));
    await tester.pumpAndSettle();

    expect(store.timers.single.runId, run.id);
    expect(store.timers.single.stepTitle, '详情页单步编辑');
    expect(store.timers.single.remainingSeconds, inInclusiveRange(298, 300));
  });

  testWidgets('Today run detail exposes Data Card entry like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final run = sampleRuns.first;
    store.todayRuns = [run];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (hostContext) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: hostContext,
                    isScrollControlled: true,
                    builder: (_) => RunDetailEditorSheet(
                      store: store,
                      run: run,
                      onDataCard: () {
                        showModalBottomSheet<void>(
                          context: hostContext,
                          isScrollControlled: true,
                          builder: (_) => DataCardSheet(run: run, store: store),
                        );
                      },
                    ),
                  );
                },
                child: const Text('打开详情'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();

    expect(find.text('编辑实验详情'), findsOneWidget);
    expect(find.byTooltip('Data Card'), findsOneWidget);

    await tester.tap(find.byTooltip('Data Card'));
    await tester.pumpAndSettle();

    expect(find.text('结果卡片'), findsOneWidget);
    expect(find.text(run.title), findsWidgets);
  });

  testWidgets('Today timers replace existing run timer like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final run = sampleRuns.first;

    await store.startTimer(run, run.steps.first, customMinutes: 5);
    await store.startTimer(run, run.steps[1], customMinutes: 3);

    expect(store.timers, hasLength(1));
    expect(store.timers.single.runId, run.id);
    expect(store.timers.single.id, '${run.id}-${run.steps[1].id}');
    expect(store.timers.single.stepTitle, run.steps[1].title);
  });

  testWidgets('Today run detail opens editor immediately when adding a step', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final run = sampleRuns.first;
    store.todayRuns = [run];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunDetailEditorSheet(store: store, run: run),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const addStepButton = Key('run-detail-add-step-button');
    await tester.scrollUntilVisible(
      find.byKey(addStepButton),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(addStepButton));
    await tester.pumpAndSettle();
    expect(find.text('编辑步骤'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '步骤名称').last,
      '新增详情步骤',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '详细说明').last,
      '新增步骤说明',
    );
    await tester.tap(find.text('保存步骤'));
    await tester.pumpAndSettle();

    expect(find.text('新增详情步骤'), findsOneWidget);
    expect(find.text('新增步骤说明'), findsOneWidget);

    expect(find.text('保存实验详情'), findsNothing);
    await tester.tap(find.byKey(const Key('run-detail-save-button')));
    await tester.pumpAndSettle();

    expect(
      store.todayRuns.single.steps.any(
        (step) => step.title == '新增详情步骤' && step.detail == '新增步骤说明',
      ),
      isTrue,
    );
  });

  testWidgets('Today add run editor uses iOS-style schedule picker', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.protocols = [sampleProtocols.first];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunEditorSheet(store: store, target: DayMode.today),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加到今天'), findsOneWidget);
    expect(find.text('插入位置'), findsOneWidget);
    expect(find.text('今天 10:00'), findsOneWidget);
    expect(find.byKey(const Key('run-editor-cancel-button')), findsOneWidget);
    expect(find.byKey(const Key('run-editor-save-button')), findsOneWidget);
    expect(find.widgetWithText(TextField, '时间，例如 09:30'), findsNothing);
    expect(find.text('保存实验'), findsNothing);

    await tester.tap(find.text('今天 10:00'));
    await tester.pumpAndSettle();

    expect(find.text('选择插入时间'), findsOneWidget);
    final hourPicker = tester.widget<CupertinoPicker>(
      find.descendant(
        of: find.byKey(const Key('run-schedule-hour-wheel')),
        matching: find.byType(CupertinoPicker),
      ),
    );
    final minutePicker = tester.widget<CupertinoPicker>(
      find.byKey(const Key('run-schedule-minute-picker')),
    );
    hourPicker.onSelectedItemChanged?.call(8);
    minutePicker.onSelectedItemChanged?.call(1);
    await tester.pump();
    await tester.tap(find.text('应用时间'));
    await tester.pumpAndSettle();

    expect(find.text('今天 08:15'), findsOneWidget);

    await tester.tap(find.byKey(const Key('run-editor-save-button')));
    await tester.pumpAndSettle();

    expect(store.todayRuns.single.timeLabel, '08:15');
    expect(store.todayRuns.single.title, sampleProtocols.first.name);
  });

  testWidgets('Today project filter shows projects without runs like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.projects = const [
      LabProject(id: 'proj-active', name: '有实验项目', colorValue: 0xFF00C7BE),
      LabProject(id: 'proj-empty', name: '空项目', colorValue: 0xFFFF9500),
    ];
    store.todayRuns = [sampleRuns.first.copyWith(projectId: 'proj-active')];

    await tester.pumpWidget(MaterialApp(home: TodayScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('有实验项目'), findsWidgets);
    expect(find.text('空项目'), findsOneWidget);

    await tester.tap(find.text('空项目'));
    await tester.pumpAndSettle();
    expect(find.text('今天还没有安排实验'), findsOneWidget);
  });

  test('End day rollover preserves archived run status like iOS', () async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('labbuddy/timers');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    final store = LabStore();
    final today = sampleRuns.first.copyWith(
      id: 'today-rollover',
      status: '进行中',
      timeLabel: '14:30',
    );
    final tomorrow = sampleRuns[1].copyWith(
      id: 'tomorrow-rollover',
      status: '明日计划',
      timeLabel: '09:00',
      planDateKey: _testDayKey(DateTime.now().add(const Duration(days: 1))),
    );
    final laterFuture = sampleRuns[1].copyWith(
      id: 'later-future-rollover',
      status: '未来计划',
      timeLabel: '15:00',
      planDateKey: _testDayKey(DateTime.now().add(const Duration(days: 2))),
    );
    store.todayRuns = [today];
    store.tomorrowRuns = [tomorrow, laterFuture];
    store.pastRuns = [];
    store.timers = [
      LabTimer(
        id: 'timer-rollover',
        runId: today.id,
        runTitle: today.title,
        stepTitle: today.steps.first.title,
        endsAtMs: DateTime.now()
            .add(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      ),
    ];

    await store.endDay();

    expect(store.timers, isEmpty);
    expect(store.pastRuns.single.id, startsWith('past-'));
    expect(store.pastRuns.single.status, '进行中');
    expect(store.todayRuns.single.id, tomorrow.id);
    expect(store.todayRuns.single.status, '已排期');
    expect(store.todayRuns.single.planDateKey, isNull);
    expect(store.tomorrowRuns.single.id, laterFuture.id);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('New day rollover can be dismissed like iOS', () async {
    SharedPreferences.setMockInitialValues({});
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final store = LabStore();
    store.todayRuns = [sampleRuns.first.copyWith(id: 'dismiss-today')];
    store.tomorrowRuns = [sampleRuns[1].copyWith(id: 'dismiss-tomorrow')];
    store.pastRuns = [];
    store.lastOpenDate = yesterdayKey;

    expect(store.needsNewDayRollover, isTrue);

    await store.dismissNewDayRollover();

    expect(store.needsNewDayRollover, isFalse);
    expect(store.todayRuns.single.id, 'dismiss-today');
    expect(store.tomorrowRuns.single.id, 'dismiss-tomorrow');
    expect(store.pastRuns, isEmpty);
  });

  testWidgets('Bench detail supports iOS-style single step edit', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final run = sampleRuns.first.copyWith(
      steps: [
        sampleRuns.first.steps.first.copyWith(
          id: 'single-edit-step',
          durationMinutes: null,
        ),
      ],
    );
    store.todayRuns = [run];

    await tester.pumpWidget(
      MaterialApp(
        home: BenchModeScreen(store: store, run: run, readonly: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('计时'), findsOneWidget);
    await tester.tap(find.byTooltip('编辑此步骤').first);
    await tester.pumpAndSettle();
    expect(find.text('编辑步骤'), findsOneWidget);
    expect(find.text('步骤信息'), findsOneWidget);
    expect(find.text('计时'), findsWidgets);

    final titleField = tester.widget<TextField>(find.byType(TextField).first);
    titleField.controller?.text = '更新后的步骤';
    await tester.tap(find.text('保存步骤'));
    await tester.pumpAndSettle();

    expect(find.text('更新后的步骤'), findsOneWidget);
    expect(store.todayRuns.first.steps.first.title, '更新后的步骤');
  });

  testWidgets('Formula editor exposes iOS-style workflow sections', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FormulaEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(findFormulaEditorTitle(skipOffstage: false), findsOneWidget);
    expect(
      find.byKey(const Key('formula-editor-close-button')),
      findsOneWidget,
    );
    expect(find.text('计算名称'), findsOneWidget);
    expect(find.text('输入变量'), findsOneWidget);
    expect(find.text('计算步骤'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('展示结果'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('参考表'), findsOneWidget);
    expect(find.text('保存为工作流模板'), findsOneWidget);
    expect(
      find.byKey(const Key('formula-editor-close-button')),
      findsOneWidget,
    );
  });

  testWidgets('Formula editor reference table edits rows like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FormulaEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('参考表'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('可添加培养体系、反应体系、推荐用量等参考数据；只用于展示和模板保存，不参与公式计算。'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('添加参考项'));
    await tester.pumpAndSettle();
    expect(find.text('编辑参考'), findsOneWidget);
    expect(
      find.byKey(const Key('formula-reference-cancel-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('formula-reference-save-button')),
      findsOneWidget,
    );
    expect(find.text('保存参考项'), findsNothing);

    tester
            .widget<TextField>(
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is TextField &&
                        widget.decoration?.labelText == '名称',
                  )
                  .first,
            )
            .controller
            ?.text =
        '6-well';
    tester
            .widget<TextField>(
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is TextField &&
                        widget.decoration?.labelText == '数值',
                  )
                  .first,
            )
            .controller
            ?.text =
        '2 ml';

    await tester.tap(find.byKey(const Key('formula-reference-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('条件'), findsOneWidget);
    expect(find.text('数值'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('6-well'), findsOneWidget);
    expect(find.text('2 ml'), findsOneWidget);

    await tester.tap(find.text('6-well'));
    await tester.pumpAndSettle();
    expect(find.text('编辑参考'), findsOneWidget);
    expect(find.text('删除这条参考'), findsOneWidget);
    expect(find.text('删除参考项'), findsNothing);

    await tester.tap(find.text('删除这条参考'));
    await tester.pumpAndSettle();
    expect(find.text('6-well'), findsNothing);
    expect(
      find.text('可添加培养体系、反应体系、推荐用量等参考数据；只用于展示和模板保存，不参与公式计算。'),
      findsOneWidget,
    );
  });

  testWidgets('Formula editor units use iOS-style unit pickers', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FormulaEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    final unitPickers = find.byType(DropdownButtonFormField<String>);
    expect(unitPickers, findsNWidgets(2));
    expect(find.text('单位'), findsWidgets);
    expect(find.text('公式输出单位'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(find.text('展示单位'), findsOneWidget);

    final percentFormula = SavedFormula(
      id: 'formula-percent-editor',
      label: '百分比公式',
      formula: 'ratio',
      resultUnit: '%',
      variables: const [FormulaVariable(name: 'ratio', value: 50, unit: '%')],
      steps: const [
        CustomCalculationStep(
          outputName: 'ratioOut',
          formula: 'ratio',
          outputUnit: '',
        ),
      ],
      resultFields: const [
        CustomResultField(
          variableName: 'ratioOut',
          label: '比例',
          displayUnit: '%',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormulaEditorSheet(store: store, existing: percentFormula),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除公式'), findsNothing);
    expect(
      find.byType(DropdownButtonFormField<String>),
      findsAtLeastNWidgets(2),
    );
    await tester.scrollUntilVisible(
      find.text('展示单位'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('展示单位'), findsOneWidget);
  });

  testWidgets('Formula editor keeps one variable step and result like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FormulaEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IosSwipeDelete), findsNothing);
    expect(find.byTooltip('删除变量'), findsNothing);
    expect(find.byTooltip('删除计算步骤'), findsNothing);
    expect(find.byTooltip('删除展示结果'), findsNothing);

    await tester.tap(find.bySemanticsLabel('添加公式变量'));
    await tester.pumpAndSettle();
    expect(find.byType(IosSwipeDelete), findsNothing);
    expect(find.byTooltip('删除变量'), findsNWidgets(2));
    await tester.enterText(
      find.byKey(const Key('formula-variable-name-field')).last,
      'temporary',
    );
    await tester.tap(find.byTooltip('删除变量').last);
    await tester.pumpAndSettle();
    expect(find.text('temporary'), findsNothing);
    expect(find.byTooltip('删除变量'), findsNothing);

    await tester.tap(find.bySemanticsLabel('添加计算步骤'));
    await tester.pumpAndSettle();
    expect(find.byType(IosSwipeDelete), findsNothing);
    expect(find.byTooltip('删除计算步骤'), findsNWidgets(2));
    await tester.ensureVisible(find.byTooltip('删除计算步骤').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除计算步骤').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('删除计算步骤'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('展示结果'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('添加展示结果'));
    await tester.pumpAndSettle();

    expect(find.byType(IosSwipeDelete), findsNothing);
    expect(find.byTooltip('删除展示结果'), findsNWidgets(2));
    await tester.ensureVisible(find.byTooltip('删除展示结果').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除展示结果').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('删除展示结果'), findsNothing);
  });

  testWidgets('Formula editor saves current result like iOS custom sheet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    Future<void> openFormulaEditor() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FormulaEditorSheet(store: store),
                ),
                child: const Text('打开自定义公式'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开自定义公式'));
      await tester.pumpAndSettle();
    }

    Future<void> fillValidFormula() async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('formula-variable-name-field')),
        -420,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('formula-variable-name-field')).first,
        'mass',
      );
      await tester.enterText(
        find.byKey(const Key('formula-variable-value-field')).first,
        '10',
      );
      await tester.enterText(
        find.byKey(const Key('formula-step-output-field')).first,
        'result',
      );
      await tester.enterText(
        find.byKey(const Key('formula-step-expression-field')).first,
        'mass / 2',
      );
      await tester.enterText(
        find.byKey(const Key('formula-result-variable-field')).first,
        'result',
      );
      await tester.pumpAndSettle();
    }

    await openFormulaEditor();

    await tester.scrollUntilVisible(
      find.text('计算结果'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('计算结果'), findsOneWidget);
    expect(find.text('公式或变量无效'), findsOneWidget);
    expect(find.text('复制结果'), findsOneWidget);
    expect(find.text('保存结果'), findsOneWidget);
    expect(store.savedFormulas, isEmpty);
    final invalidTemplateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存为工作流模板'),
    );
    expect(invalidTemplateButton.onPressed, isNull);

    await fillValidFormula();

    await tester.scrollUntilVisible(
      find.text('计算结果'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget);
    final validTemplateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存为工作流模板'),
    );
    expect(validTemplateButton.onPressed, isNotNull);

    await tester.tap(find.text('保存结果'));
    await tester.pumpAndSettle();

    expect(store.calcHistory.single.title, '自定义公式');
    expect(store.calcHistory.single.result, contains('结果: 5'));
    expect(store.calcHistory.single.mode, 'custom');
    expect(store.calcHistory.single.inputs, containsPair('mass', 10));
    expect(find.text('新增自定义公式'), findsNothing);

    await openFormulaEditor();
    await fillValidFormula();

    await tester.scrollUntilVisible(
      find.text('保存为工作流模板'),
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存为工作流模板'));
    await tester.pumpAndSettle();

    expect(store.savedFormulas.single.label, '自定义公式');
    expect(store.savedFormulas.single.formula, 'mass / 2');
    expect(store.savedFormulas.single.workflowResultFields.single.label, '结果');
  });

  testWidgets('Formula runner shows iOS-style result inputs and references', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final formula = SavedFormula(
      id: 'formula-runner-reference',
      label: '接种密度',
      formula: 'cells / volume',
      resultUnit: 'cells/ml',
      variables: const [
        FormulaVariable(name: 'cells', value: 1000000, unit: 'cells'),
        FormulaVariable(name: 'volume', value: 2, unit: 'ml'),
      ],
      steps: const [
        CustomCalculationStep(
          outputName: 'density',
          formula: 'cells / volume',
          outputUnit: 'cells/ml',
        ),
      ],
      resultFields: const [
        CustomResultField(
          variableName: 'density',
          label: '目标密度',
          displayUnit: 'cells/ml',
        ),
      ],
      referenceRows: const [
        CustomReferenceRow(
          name: '6-well',
          condition: '贴壁细胞',
          value: '2 ml',
          note: '常规接种',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FormulaRunnerScreen(store: store, formula: formula),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('计算结果'), findsOneWidget);
    expect(find.text('输入变量'), findsOneWidget);
    expect(find.text('目标密度'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('参考表'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('参考表'), findsOneWidget);
    expect(find.text('6-well'), findsOneWidget);
    expect(find.text('常规接种'), findsOneWidget);
  });

  testWidgets(
    'Formula runner converts display units like iOS workflow engine',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = LabStore();
      final formula = SavedFormula(
        id: 'unit-formula',
        label: '单位换算公式',
        formula: 'mass / volume',
        resultUnit: 'mg/ml',
        variables: const [
          FormulaVariable(name: 'mass', value: 10, unit: 'mg'),
          FormulaVariable(name: 'volume', value: 10, unit: 'ml'),
        ],
        steps: const [
          CustomCalculationStep(
            outputName: 'result',
            formula: 'mass / volume',
            outputUnit: 'mg/ml',
          ),
        ],
        resultFields: const [
          CustomResultField(
            variableName: 'result',
            label: '浓度',
            displayUnit: 'μg/ml',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FormulaRunnerScreen(store: store, formula: formula),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('单位换算公式'), findsOneWidget);
      expect(find.text('浓度'), findsOneWidget);
      expect(find.textContaining('1000 μg/ml'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('复制结果'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('复制结果'), findsOneWidget);
      expect(find.text('保存结果'), findsOneWidget);

      await tester.tap(find.text('复制结果'));
      await tester.pump();
      expect(find.text('已复制'), findsOneWidget);

      await tester.tap(find.text('保存结果'));
      await tester.pumpAndSettle();

      expect(store.calcHistory.single.title, '单位换算公式');
      expect(store.calcHistory.single.mode, 'custom');
      expect(store.calcHistory.single.result, contains('浓度: 1000 μg/ml'));
      expect(store.calcHistory.single.inputs, containsPair('mass', 10));
      expect(store.calcHistory.single.inputs, containsPair('volume', 10));
      expect(find.text('单位换算公式'), findsNothing);
    },
  );

  testWidgets('Saved formulas replace same label and formula like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await store.upsertSavedFormula(
      const SavedFormula(
        id: 'formula-old',
        label: '重复公式',
        formula: 'mass / volume',
        resultUnit: 'mg/ml',
        variables: [],
      ),
    );
    await store.upsertSavedFormula(
      const SavedFormula(
        id: 'formula-new',
        label: '重复公式',
        formula: 'mass / volume',
        resultUnit: 'mg/ml',
        variables: [],
      ),
    );

    expect(store.savedFormulas, hasLength(1));
    expect(store.savedFormulas.single.id, 'formula-new');

    await store.upsertSavedFormula(
      const SavedFormula(
        id: 'formula-new',
        label: '重复公式',
        formula: 'mass / volume',
        resultUnit: 'μg/ml',
        variables: [],
      ),
    );

    expect(store.savedFormulas, hasLength(1));
    expect(store.savedFormulas.single.resultUnit, 'μg/ml');
  });

  testWidgets('Preferences sheet exposes iOS-style My settings sections', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    await store.updateProfile(
      name: 'LabBuddy User',
      email: 'readonly@labbuddy.test',
      labName: '个人本地工作区',
      avatarPath: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PreferencesSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('偏好设置'), findsOneWidget);
    expect(find.text('个人信息'), findsOneWidget);
    expect(find.text('点击更换头像'), findsOneWidget);
    expect(find.text('登录邮箱'), findsOneWidget);
    expect(find.text('readonly@labbuddy.test'), findsOneWidget);
    expect(find.text('实验室 / 项目空间'), findsOneWidget);
    expect(find.text('保存个人信息'), findsNothing);
    expect(find.text('实验室 / 工作区名称'), findsNothing);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.decoration?.labelText == '登录邮箱'),
      isFalse,
    );
    expect(find.text('本地演示版'), findsOneWidget);
    expect(find.textContaining('当前 APK 不需要服务器登录'), findsOneWidget);
    expect(find.text('保存服务器设置'), findsNothing);
    expect(find.text('用于未来 AI/同步服务。当前本地模式不会上传实验数据。'), findsNothing);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any(
            (field) =>
                field.decoration?.labelText == 'API 地址' &&
                field.controller?.text == 'http://127.0.0.1:18088',
          ),
      isFalse,
    );

    await tester.scrollUntilVisible(
      find.text('外观'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('系统'), findsNothing);
    expect(find.text('小'), findsWidgets);
    expect(find.text('标准'), findsWidgets);
    expect(find.text('超大'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('实验台'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('实验台'), findsOneWidget);
    expect(find.text('大字号实验台模式'), findsOneWidget);
    expect(find.text('大字号 Bench Mode'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('通知与反馈'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('通知与反馈'), findsOneWidget);
    expect(find.text('触感反馈（Haptics）'), findsOneWidget);
    expect(find.text('触感反馈'), findsNothing);
    expect(find.text('Data Card 水印'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('单位管理'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('单位管理'), findsOneWidget);
    expect(find.text('0 个'), findsAtLeastNWidgets(2));
    expect(find.text('0 个自定义单位'), findsNothing);
    expect(find.text('0 个自定义类型'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('语音播报内容'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('语音播报内容'), findsOneWidget);
    expect(find.text('Pro 功能：计时到点时自动语音播报'), findsOneWidget);
    expect(find.text('计时到点时自动语音播报，模板可使用 {实验} 和 {步骤}。'), findsNothing);
    expect(find.text('升级 Pro 解锁语音自定义'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pro 订阅权益'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pro 订阅权益'), findsOneWidget);
    expect(find.text('去除结果卡片水印 · AI 助手 · 语音调度 · 即将推出'), findsOneWidget);
    expect(find.text('已解锁：AI 助手 · 语音调度'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('退出登录'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.byKey(const Key('preferences-sign-out-row')), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.text('退出登录不会删除本机实验记录、Protocol 或库存数据。'), findsOneWidget);
  });

  testWidgets('Preferences hides server login settings for local demo APK', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    await store.updatePreferences(apiBaseUrl: 'http://172.16.8.18:18088');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PreferencesSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地演示版'), findsOneWidget);
    expect(find.textContaining('当前 APK 不需要服务器登录'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'API 地址'), findsNothing);
    expect(store.preferences.apiBaseUrl, 'http://127.0.0.1:18088');
  });

  testWidgets('My identity card opens preferences like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    await store.updateProfile(
      name: 'LabBuddy User',
      email: 'local@labbuddy',
      labName: '个人本地工作区',
      avatarPath: null,
    );

    await tester.pumpWidget(MaterialApp(home: MyScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('偏好设置'), findsNothing);
    expect(find.text('编辑资料'), findsNothing);
    expect(find.text('退出登录'), findsNothing);

    await tester.tap(find.text(store.userName));
    await tester.pumpAndSettle();

    expect(find.text('偏好设置'), findsOneWidget);
    expect(find.text('个人信息'), findsOneWidget);
    expect(find.text('登录邮箱'), findsOneWidget);
    expect(find.text('local@labbuddy'), findsAtLeastNWidgets(1));

    expect(find.byKey(const Key('preferences-done-button')), findsOneWidget);
    expect(find.widgetWithIcon(FilledButton, Icons.check), findsNothing);

    await tester.tap(find.byKey(const Key('preferences-done-button')));
    await tester.pumpAndSettle();

    expect(find.text('偏好设置'), findsNothing);
  });

  testWidgets('My identity card shows unauthenticated state like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore()
      ..isAuthenticated = false
      ..userName = ''
      ..userEmail = ''
      ..labName = '个人本地工作区';

    await tester.pumpWidget(MaterialApp(home: MyScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('未登录用户'), findsOneWidget);
    expect(find.text('个人本地工作区'), findsOneWidget);
    expect(find.text('未登录 · 本地个人工具'), findsOneWidget);
    expect(find.text('已登录 · 本地数据仍存本机'), findsNothing);
  });

  testWidgets('Preferences personal info keeps login email readonly like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    await store.updateProfile(
      name: 'Old Name',
      email: 'fixed@labbuddy.test',
      labName: 'Old Lab',
      avatarPath: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PreferencesSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '昵称'), 'New Name');
    await tester.enterText(
      find.widgetWithText(TextField, '实验室 / 项目空间'),
      'New Lab',
    );
    await tester.pumpAndSettle();

    expect(store.userName, 'New Name');
    expect(store.labName, 'New Lab');
    expect(store.userEmail, 'fixed@labbuddy.test');
  });

  testWidgets('Preferences sheet exposes iOS-style Pro voice controls', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    await store.updatePreferences(
      isProUser: true,
      voiceAnnouncementEnabled: true,
      voiceAnnouncementTemplate: '{实验} 的 {步骤} 完成',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PreferencesSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('语音播报内容'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('启用语音播报'), findsOneWidget);
    expect(find.text('计时到点时自动语音播报，模板可使用 {实验} 和 {步骤}。'), findsOneWidget);
    expect(find.text('Pro 功能：计时到点时自动语音播报'), findsNothing);
    expect(find.text('播报模板'), findsOneWidget);
    expect(find.text('可用变量：{实验} {步骤}'), findsOneWidget);
    expect(find.text('预览'), findsOneWidget);
    expect(find.text('293T 细胞传代 的 胰酶消化 完成'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);

    await tester.tap(
      find
          .ancestor(of: find.text('启用语音播报'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();

    expect(store.preferences.timerSound, isFalse);
    expect(find.text('播报模板'), findsNothing);
    expect(find.text('预览'), findsNothing);

    await tester.tap(
      find
          .ancestor(of: find.text('启用语音播报'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();

    expect(store.preferences.timerSound, isTrue);
    expect(find.text('播报模板'), findsOneWidget);

    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();

    expect(
      store.preferences.voiceAnnouncementTemplate,
      LabPreferences.defaultVoiceAnnouncementTemplate,
    );
    expect(find.text('293T 细胞传代，胰酶消化已完成'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '播报模板'),
      '{实验} - {步骤} 完成',
    );
    await tester.pumpAndSettle();

    expect(store.preferences.voiceAnnouncementTemplate, '{实验} - {步骤} 完成');
    expect(find.text('293T 细胞传代 - 胰酶消化 完成'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Pro 订阅权益'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('已解锁：AI 助手 · 语音调度'), findsOneWidget);
  });

  testWidgets('Preferences color order can save and reset like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PreferencesSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('实验颜色顺序'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('${defaultExperimentPalette.length} 色'), findsOneWidget);

    await tester.tap(find.text('实验颜色顺序'));
    await tester.pumpAndSettle();
    expect(find.text('恢复 Apple 默认配色'), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(store.projectPaletteValues.first, defaultExperimentPalette[1]);

    await tester.scrollUntilVisible(
      find.text('实验颜色顺序'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('实验颜色顺序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复 Apple 默认配色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(store.projectPaletteValues, defaultExperimentPalette);
    expect(store.activeProjectPalette, defaultProjectPalette);
  });

  testWidgets('Project editor uses fixed iOS project palette', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.projectPaletteValues = List.of(defaultExperimentPalette);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProjectEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.activeProjectPalette, defaultProjectPalette);
    expect(store.activeProjectPalette.length, 10);
    expect(store.activeExperimentPalette.length, 12);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('Project editor defaults to next iOS palette color', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.projects = [
      LabProject(
        id: 'project-one',
        name: 'Project One',
        colorValue: defaultProjectPalette.first,
      ),
      LabProject(
        id: 'project-two',
        name: 'Project Two',
        colorValue: defaultProjectPalette[1],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProjectEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '项目名称'),
      'Project Three',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-editor-save-button')));
    await tester.pumpAndSettle();

    expect(store.projects, hasLength(3));
    expect(store.projects.last.colorValue, defaultProjectPalette[2]);
  });

  test(
    'Store migrates old 8-color Android palette to iOS experiment palette',
    () async {
      SharedPreferences.setMockInitialValues({
        'labBuddyData': jsonEncode({
          'projectPaletteValues': defaultProjectPalette.take(8).toList(),
        }),
      });

      final store = LabStore();
      await store.load();

      expect(store.projectPaletteValues, defaultExperimentPalette);
      expect(store.activeProjectPalette, defaultProjectPalette);
    },
  );

  testWidgets('Experiment type manager exposes iOS-style built-in locks', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExperimentTypeManagementSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('实验类型管理'), findsOneWidget);
    expect(find.text('内置实验类型'), findsOneWidget);
    expect(find.text('Pro 可修改'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsWidgets);
    expect(find.text('添加自定义实验类型'), findsOneWidget);
    expect(find.text('自定义类型将在新建实验和 Protocol 编辑中可用'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '免疫实验');
    await tester.tap(find.text('添加自定义实验类型'));
    await tester.pumpAndSettle();

    expect(store.customAreas, contains('免疫实验'));
    expect(find.text('免疫实验'), findsOneWidget);
    expect(find.byType(IosSwipeDelete), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('Unit manager exposes iOS-style built-in categories', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UnitManagementSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('单位管理'), findsOneWidget);
    expect(find.text('内置单位'), findsOneWidget);
    expect(find.text('Pro 可修改'), findsOneWidget);
    expect(find.text('体积'), findsOneWidget);
    expect(find.text('质量'), findsOneWidget);
    expect(find.text('浓度'), findsOneWidget);
    expect(find.text('添加自定义单位'), findsOneWidget);
    expect(find.textContaining('内置单位根据使用场景自动显示'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('自定义单位会在所有场景'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('自定义单位会在所有场景'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'U');
    await tester.tap(find.text('添加自定义单位'));
    await tester.pumpAndSettle();

    expect(store.customUnits, contains('U'));
    await tester.scrollUntilVisible(
      find.text('U'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(IosSwipeDelete), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('Project editor exposes iOS-style time fields', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final project = LabProject(
      id: 'project-test',
      name: 'CRISPR 敲除验证',
      description: '验证 sgRNA 编辑效率',
      colorValue: defaultProjectPalette.first,
      createdAtMs: DateTime(2026, 6, 1).millisecondsSinceEpoch,
      endsAtMs: DateTime(2026, 7, 1, 9, 30).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectEditorSheet(store: store, existing: project),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑项目'), findsOneWidget);
    expect(find.text('项目信息'), findsOneWidget);
    expect(find.text('项目名称'), findsOneWidget);
    expect(find.text('颜色标识'), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('设置结束时间'), findsOneWidget);
    expect(find.text('结束时间'), findsOneWidget);
    expect(find.text('创建时间'), findsOneWidget);
    expect(find.byKey(const Key('project-editor-save-button')), findsOneWidget);
    expect(
      find.byKey(const Key('project-editor-delete-button')),
      findsOneWidget,
    );
    expect(find.text('保存项目'), findsNothing);
    expect(find.byIcon(Icons.check), findsWidgets);
  });

  testWidgets('Project editor deletes project tag like iOS detail view', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final project = LabProject(
      id: 'project-editor-delete',
      name: '编辑页删除项目',
      description: '只删除标签',
      colorValue: defaultProjectPalette.first,
      createdAtMs: DateTime(2026, 6, 1).millisecondsSinceEpoch,
    );
    store.projects = [project];
    store.todayRuns = [sampleRuns.first.copyWith(projectId: project.id)];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectEditorSheet(store: store, existing: project),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('project-editor-delete-button')));
    await tester.pumpAndSettle();

    expect(find.text('删除项目'), findsWidgets);
    expect(find.textContaining('不会删除已经创建的实验记录'), findsOneWidget);

    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(store.projects, isEmpty);
    expect(store.todayRuns.single.projectId, project.id);
  });

  testWidgets('Project editor requires a name like iOS create flow', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProjectEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新建项目'), findsOneWidget);
    expect(
      find.byKey(const Key('project-editor-cancel-button')),
      findsOneWidget,
    );
    expect(find.text('保存项目'), findsNothing);
    final saveButton = tester.widget<TextButton>(
      find.byKey(const Key('project-editor-save-button')),
    );
    expect(saveButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '蛋白互作验证');
    await tester.pumpAndSettle();

    final enabledSaveButton = tester.widget<TextButton>(
      find.byKey(const Key('project-editor-save-button')),
    );
    expect(enabledSaveButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('project-editor-save-button')));
    await tester.pumpAndSettle();

    expect(store.projects.single.name, '蛋白互作验证');
  });

  test('Project deletion keeps run links like iOS detail view', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final project = LabProject(
      id: 'project-delete',
      name: '待删除项目',
      description: '确认删除前应保留',
      colorValue: defaultProjectPalette.first,
      createdAtMs: DateTime(2026, 6, 1).millisecondsSinceEpoch,
    );
    store.projects = [project];
    store.todayRuns = [sampleRuns.first.copyWith(projectId: project.id)];
    store.tomorrowRuns = [sampleRuns[1].copyWith(projectId: project.id)];
    store.pastRuns = [sampleRuns[2].copyWith(projectId: project.id)];

    await store.deleteProject(project.id);

    expect(store.projects, isEmpty);
    expect(store.todayRuns.single.projectId, project.id);
    expect(store.tomorrowRuns.single.projectId, project.id);
    expect(store.pastRuns.single.projectId, project.id);
  });

  testWidgets('My project rows expose iOS-style metadata', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.projects = [
      LabProject(
        id: 'project-row',
        name: 'ACE2 entry screen',
        description: 'Track CRISPR validation',
        colorValue: defaultProjectPalette.first,
        createdAtMs: DateTime(2026, 6, 1).millisecondsSinceEpoch,
        endsAtMs: DateTime(2026, 7, 1, 9, 30).millisecondsSinceEpoch,
      ),
      LabProject(
        id: 'project-empty-description',
        name: 'No description project',
        description: '',
        colorValue: defaultProjectPalette[1],
        createdAtMs: DateTime(2026, 6, 2).millisecondsSinceEpoch,
        endsAtMs: DateTime(2026, 8, 2, 10).millisecondsSinceEpoch,
      ),
    ];
    store.todayRuns = [sampleRuns.first.copyWith(projectId: 'project-row')];

    await tester.pumpWidget(MaterialApp(home: MyScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('项目管理'), findsOneWidget);
    expect(find.byType(IosSwipeDelete), findsNWidgets(2));
    expect(find.text('ACE2 entry screen'), findsOneWidget);
    expect(find.text('Track CRISPR validation'), findsOneWidget);
    expect(find.textContaining('创建 2026/6/1'), findsOneWidget);
    expect(find.textContaining('结束 2026/7/1 09:30'), findsOneWidget);
    expect(find.text('No description project'), findsOneWidget);
    expect(find.text('无备注'), findsNothing);
    expect(find.textContaining('创建 2026/6/2'), findsOneWidget);
    expect(find.textContaining('结束 2026/8/2 10:00'), findsOneWidget);
    expect(find.text('0 实验'), findsNothing);
    expect(find.text('1 实验'), findsNothing);
  });

  testWidgets('My local data management matches iOS cleanup entry', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(MaterialApp(home: MyScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('本地数据管理'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('导出备份'), findsOneWidget);
    expect(find.text('导入恢复'), findsOneWidget);
    expect(find.text('清理缓存与演示数据'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('未来能力'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('未来能力'), findsOneWidget);
    expect(find.text('云同步与协作'), findsOneWidget);
    expect(find.text('v1 保持关闭，数据仅存本机'), findsOneWidget);
    expect(find.text('Pro 订阅'), findsOneWidget);
    expect(find.text('去除结果卡片水印、AI 助手、语音调度等 · 即将推出'), findsOneWidget);
    expect(find.text('重置本地 demo 数据'), findsNothing);
  });

  testWidgets('Inventory page exposes iOS-style category manager', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.inventory = [
      const LabInventoryItem(
        id: 'inv-test',
        name: 'DMEM',
        category: '培养基',
        quantity: 100,
        unit: 'ml',
        threshold: 20,
        storage: '4°C',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: InventoryPageScreen(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('库存管理'), findsOneWidget);
    expect(find.byTooltip('分类管理'), findsOneWidget);
    expect(find.byType(IosSwipeDelete), findsOneWidget);

    await tester.tap(find.byTooltip('分类管理'));
    await tester.pumpAndSettle();

    expect(find.text('库存分类'), findsOneWidget);
    expect(find.text('当前分类'), findsOneWidget);
    expect(find.text('添加分类'), findsOneWidget);
  });

  testWidgets('Inventory editor creates custom category like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InventoryEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新增库存项'), findsOneWidget);
    expect(
      find.byKey(const Key('inventory-editor-cancel-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('inventory-editor-save-button')),
      findsOneWidget,
    );
    expect(find.widgetWithIcon(FilledButton, Icons.save), findsNothing);
    final disabledSaveButton = tester.widget<TextButton>(
      find.byKey(const Key('inventory-editor-save-button')),
    );
    expect(disabledSaveButton.onPressed, isNull);
    expect(find.text('试剂名称'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('培养基'), findsWidgets);
    expect(find.text('新建分类'), findsOneWidget);
    expect(find.text('当前数量'), findsOneWidget);
    expect(find.text('低库存阈值'), findsOneWidget);
    expect(find.text('存储位置'), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any(
            (field) =>
                field.decoration?.labelText == '当前数量' &&
                field.controller?.text == '0',
          ),
      isTrue,
    );
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any(
            (field) =>
                field.decoration?.labelText == '低库存阈值' &&
                field.controller?.text == '10',
          ),
      isTrue,
    );

    await tester.tap(find.text('新建分类'));
    await tester.pumpAndSettle();
    expect(find.text('分类名称'), findsOneWidget);

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, '细胞培养');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('添加')),
    );
    await tester.pumpAndSettle();

    expect(store.customInventoryCategories, contains('细胞培养'));
    expect(find.text('细胞培养'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, '试剂名称'), 'DMEM');
    await tester.pumpAndSettle();
    final enabledSaveButton = tester.widget<TextButton>(
      find.byKey(const Key('inventory-editor-save-button')),
    );
    expect(enabledSaveButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('inventory-editor-save-button')));
    await tester.pumpAndSettle();

    expect(store.inventory.single.name, 'DMEM');
  });

  testWidgets('Inventory editor omits Android-only delete action like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    const item = LabInventoryItem(
      id: 'inv-edit',
      name: 'DMEM',
      category: '培养基',
      quantity: 100,
      unit: 'ml',
      threshold: 20,
      storage: '4°C',
    );
    store.inventory = [item];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryEditorSheet(store: store, existing: item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑库存'), findsOneWidget);
    expect(find.text('删除库存项'), findsNothing);
    expect(
      find.byKey(const Key('inventory-editor-save-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('inventory-editor-cancel-button')),
      findsOneWidget,
    );
    expect(find.widgetWithIcon(FilledButton, Icons.save), findsNothing);
    expect(store.inventory.single.id, item.id);
  });

  test('Inventory transactions match iOS manual adjustment behavior', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await store.addInventory(
      name: 'DMEM',
      category: '培养基',
      quantity: 100,
      unit: 'ml',
      threshold: 20,
      storage: '4°C',
      supplier: '',
      lotNumber: '',
      notes: '',
    );

    expect(store.inventory, hasLength(1));
    expect(store.inventoryTransactions, isEmpty);

    final itemId = store.inventory.single.id;
    await store.adjustInventory(itemId, -5);
    await store.adjustInventory(itemId, 10);

    expect(store.inventory.single.quantity, 105);
    expect(store.inventoryTransactions, hasLength(2));
    expect(store.inventoryTransactions.first.note, '手动补货');
    expect(store.inventoryTransactions.first.delta, 10);
    expect(store.inventoryTransactions.last.note, '手动扣减');
    expect(store.inventoryTransactions.last.delta, -5);
  });

  test('Custom timer preserves second-level duration like iOS', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final run = sampleRuns.first.copyWith(id: 'timer-seconds-run');
    final step = run.steps.first.copyWith(id: 'timer-seconds-step');

    await store.startTimer(run, step, customSeconds: 80);

    expect(store.timers, hasLength(1));
    expect(store.timers.single.id, '${run.id}-${step.id}');
    expect(store.timers.single.remainingSeconds, inInclusiveRange(78, 80));
  });

  testWidgets('Past calendar uses iOS-style project color dots', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final project = LabProject(
      id: 'proj-calendar',
      name: 'Calendar Project',
      colorValue: 0xFFFF9500,
    );
    final run = sampleRuns.first.copyWith(
      id: 'past-$key',
      projectId: project.id,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PastCalendarCard(
            displayMonth: DateTime(now.year, now.month),
            records: {
              key: PastDayRecord.fromRuns(key, [run]),
            },
            selectableRecords: {
              key: PastDayRecord.fromRuns(key, [run]),
            },
            selectedDayKey: null,
            projects: [project],
            selectedProjectId: null,
            onMonthChanged: (_) {},
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PastCalendarCard), findsOneWidget);
    expect(find.text('${now.day}'), findsOneWidget);
    expect(find.text('双指缩放可调整大小'), findsOneWidget);
    final orangeDots = tester
        .widgetList<Container>(find.byType(Container))
        .where((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle &&
              decoration.color == const Color(0xFFFF9500);
        });
    expect(orangeDots.length, greaterThanOrEqualTo(1));
  });

  testWidgets('Past calendar keeps non-matching project days muted and disabled', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final matchingDate = DateTime(now.year, now.month, 5);
    final otherDate = DateTime(now.year, now.month, 6);
    final matchingKey =
        '${matchingDate.year}-${matchingDate.month.toString().padLeft(2, '0')}-${matchingDate.day.toString().padLeft(2, '0')}';
    final otherKey =
        '${otherDate.year}-${otherDate.month.toString().padLeft(2, '0')}-${otherDate.day.toString().padLeft(2, '0')}';
    final selectedProject = LabProject(
      id: 'proj-selected-filter',
      name: 'Selected Filter',
      colorValue: 0xFF00C7BE,
    );
    final otherProject = LabProject(
      id: 'proj-other-filter',
      name: 'Other Filter',
      colorValue: 0xFFFF9500,
    );
    final matchingRun = sampleRuns.first.copyWith(
      id: 'past-$matchingKey-match',
      projectId: selectedProject.id,
    );
    final otherRun = sampleRuns.first.copyWith(
      id: 'past-$otherKey-other',
      projectId: otherProject.id,
    );
    String? selectedKey;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PastCalendarCard(
              displayMonth: DateTime(now.year, now.month),
              records: {
                matchingKey: PastDayRecord.fromRuns(matchingKey, [matchingRun]),
                otherKey: PastDayRecord.fromRuns(otherKey, [otherRun]),
              },
              selectableRecords: {
                matchingKey: PastDayRecord.fromRuns(matchingKey, [matchingRun]),
              },
              selectedDayKey: selectedKey,
              projects: [selectedProject, otherProject],
              selectedProjectId: selectedProject.id,
              onMonthChanged: (_) {},
              onDaySelected: (key) => setState(() => selectedKey = key),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    final selectedColorDots = tester
        .widgetList<Container>(find.byType(Container))
        .where((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle &&
              decoration.color == const Color(0xFF00C7BE);
        });
    expect(selectedColorDots.length, greaterThanOrEqualTo(1));

    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    expect(selectedKey, isNull);

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(selectedKey, matchingKey);
  });

  testWidgets('Tomorrow tab uses calendar planning for future dates', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.protocols = [sampleProtocols.first];
    store.todayRuns = [];
    store.tomorrowRuns = [];
    store.projects = [];

    final futureDate = DateTime.now().add(const Duration(days: 3));
    await store.addRun(
      target: DayMode.tomorrow,
      title: 'Future Plan',
      area: sampleProtocols.first.area,
      timeLabel: '09:30',
      protocol: sampleProtocols.first,
      scale: sampleProtocols.first.baseVolumeLabel,
      projectId: null,
      date: futureDate,
    );

    expect(store.futureRunsForDate(futureDate).single.title, 'Future Plan');
    expect(
      store.futureRunsForDate(DateTime.now().add(const Duration(days: 1))),
      isEmpty,
    );

    await tester.pumpWidget(MaterialApp(home: TodayScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('明天'));
    await tester.pumpAndSettle();

    expect(find.text('选择未来日期，提前安排实验计划'), findsOneWidget);
    expect(find.byType(PastCalendarCard), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.textContaining('个计划'), findsWidgets);
    expect(find.text('添加'), findsWidgets);
  });

  testWidgets('Past run opens iOS-style record detail before Data Card', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final project = LabProject(
      id: 'proj-past-detail',
      name: 'Past Detail Project',
      colorValue: 0xFF00C7BE,
    );
    final run = sampleRuns.first.copyWith(
      id: 'past-detail-run',
      projectId: project.id,
    );
    store.projects = [project];
    store.pastRuns = [run];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PastRecordsCalendarView(
            runs: store.pastRuns,
            store: store,
            projects: store.projects,
            selectedProjectId: null,
            showDataCard: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(run.title),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(run.title));
    await tester.pumpAndSettle();

    expect(find.text('实验记录'), findsOneWidget);
    expect(find.text('Past Detail Project'), findsOneWidget);
    expect(find.text('实验步骤'), findsOneWidget);
    expect(find.byTooltip('生成 Data Card'), findsOneWidget);
    expect(find.text(run.steps.first.title), findsOneWidget);
  });

  testWidgets('Data Card uses iOS-style field controls', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final project = LabProject(
      id: 'proj-data-card',
      name: 'Data Card Project',
      colorValue: 0xFF00C7BE,
    );
    final run = sampleRuns.first.copyWith(projectId: project.id);
    store.projects = [project];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataCardSheet(run: run, store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('结果卡片'), findsOneWidget);
    expect(find.text('实验条件'), findsOneWidget);
    expect(find.text('Protocol'), findsWidgets);
    expect(find.text('用量/规模'), findsWidgets);
    expect(find.text('实验类型'), findsWidgets);
    expect(find.text('步骤完成'), findsWidgets);
    expect(find.text('记录时间'), findsWidgets);
    expect(find.text('Project'), findsNothing);
    expect(find.text('步骤明细'), findsNothing);
    expect(find.text('Data Card Project'), findsNothing);
    expect(find.text('字段显示'), findsNothing);
    expect(find.text('LabBuddy watermark'), findsNothing);

    final protocolToggle = find
        .descendant(
          of: find.ancestor(
            of: find.text('Protocol').first,
            matching: find.byType(Row),
          ),
          matching: find.byIcon(Icons.visibility_outlined),
        )
        .first;
    await tester.tap(protocolToggle);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '补充实验备注（可选）'),
      '观察到条带清晰',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('复制实验条件'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制实验条件'));
    await tester.pumpAndSettle();

    expect(find.text('已复制'), findsOneWidget);

    final clipboard = await Clipboard.getData('text/plain');
    expect(clipboard?.text, isNot(contains('Protocol: ${run.protocolName}')));
    expect(clipboard?.text, contains('用量/规模: ${run.scaledVolumeLabel}'));
    expect(clipboard?.text, contains('实验类型: ${run.area}'));
    expect(
      clipboard?.text,
      contains('步骤完成: ${run.completedCount}/${run.steps.length}'),
    );
    expect(clipboard?.text, contains('记录时间: '));
    expect(clipboard?.text, contains('备注: 观察到条带清晰'));
    expect(clipboard?.text, isNot(contains('LabBuddy Data Card')));
    expect(clipboard?.text, isNot(contains('Experiment:')));
    expect(clipboard?.text, isNot(contains('Status:')));

    await tester.tap(find.text('保存到相册'));
    await tester.pumpAndSettle();

    expect(find.text('已保存到相册'), findsOneWidget);

    final dataCardLines = List<String>.from(
      lastDataCardPayload?['lines'] as List,
    );
    expect(dataCardLines, isNot(contains('Protocol: ${run.protocolName}')));
    expect(dataCardLines, contains('用量/规模: ${run.scaledVolumeLabel}'));
    expect(dataCardLines, contains('实验类型: ${run.area}'));
    expect(
      dataCardLines,
      contains('步骤完成: ${run.completedCount}/${run.steps.length}'),
    );
    expect(dataCardLines.any((line) => line.startsWith('记录时间: ')), isTrue);
    expect(dataCardLines, contains('备注: 观察到条带清晰'));
    expect(dataCardLines.any((line) => line.startsWith('Status:')), isFalse);
    expect(dataCardLines.any((line) => line.startsWith('Area:')), isFalse);
    expect(dataCardLines.any((line) => line.startsWith('Completed:')), isFalse);
  });

  testWidgets('Tools entries show iOS-style recent calculator results', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.calcHistory = const [
      CalcHistoryItem(
        id: 'calc-recent',
        title: '质量计算',
        result: '2.00 mg',
        mode: 'mass',
        inputs: {'amount': 1, 'concentration': 2},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ToolsScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('计算工具'), findsOneWidget);
    expect(find.text('质量浓度'), findsOneWidget);
    expect(find.text('2.00 mg'), findsOneWidget);
    expect(find.text('最近'), findsOneWidget);

    final iconTiles = tester
        .widgetList<Container>(find.byType(Container))
        .where((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.borderRadius == BorderRadius.circular(8) &&
              decoration.color == _testAlpha(const Color(0xFF00C7BE), 0.12);
        });
    expect(iconTiles.length, greaterThanOrEqualTo(1));

    await tester.scrollUntilVisible(
      find.text('可恢复输入'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('可恢复输入'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(store.calcHistory, isEmpty);
    expect(find.text('暂无计算历史'), findsOneWidget);
  });

  testWidgets('Calculator history stores restore metadata compatibly', (
    WidgetTester tester,
  ) async {
    final item = CalcHistoryItem.fromJson({
      'id': 'calc-json',
      'title': '质量计算',
      'result': '2.00 mg',
      'mode': 'mass',
      'inputs': {'amount': 1, 'concentration': 2},
    });
    final legacy = CalcHistoryItem.fromJson({
      'id': 'calc-legacy',
      'title': '稀释计算',
      'result': '1.00 ml stock',
    });

    expect(item.mode, 'mass');
    expect(item.inputs['amount'], 1);
    expect(item.toJson()['inputs'], isA<Map>());
    expect(legacy.mode, isNull);
    expect(legacy.inputs, isEmpty);
  });

  testWidgets('Calculator history replaces same mode and title like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    await store.addCalcHistory(
      '质量计算',
      '2.00 mg',
      mode: 'mass',
      inputs: {'amount': 1, 'concentration': 2},
    );
    await store.addCalcHistory(
      '质量计算',
      '21.00 mg',
      mode: 'mass',
      inputs: {'amount': 3, 'concentration': 7},
    );

    expect(store.calcHistory, hasLength(1));
    expect(store.calcHistory.single.result, '21.00 mg');
    expect(store.calcHistory.single.inputs, containsPair('amount', 3));

    await store.addCalcHistory('质量计算', 'legacy duplicate');

    expect(store.calcHistory, hasLength(2));
    expect(store.calcHistory.first.mode, isNull);
    expect(store.calcHistory.last.mode, 'mass');
  });

  testWidgets('Calculator history keeps latest 50 entries like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    for (var i = 0; i < 51; i++) {
      await store.addCalcHistory(
        '历史 $i',
        '结果 $i',
        mode: 'custom',
        inputs: {'value': i.toDouble()},
      );
    }

    expect(store.calcHistory, hasLength(50));
    expect(store.calcHistory.first.title, '历史 50');
    expect(store.calcHistory.last.title, '历史 1');
    expect(store.calcHistory.any((item) => item.title == '历史 0'), isFalse);
  });

  testWidgets('Tools history shows latest 8 rows like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.calcHistory = List.generate(
      9,
      (index) => CalcHistoryItem(
        id: 'history-$index',
        title: '历史 $index',
        result: '结果 $index',
        mode: 'custom',
        inputs: {'value': index.toDouble()},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ToolsScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('历史 7'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('历史 7'), findsOneWidget);
    expect(find.text('历史 8', skipOffstage: false), findsNothing);
  });

  testWidgets('Calculator history tap restores inputs like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.calcHistory = const [
      CalcHistoryItem(
        id: 'calc-restore',
        title: '质量计算',
        result: '21.00 mg',
        mode: 'mass',
        inputs: {'amount': 3, 'concentration': 7},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ToolsScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('可恢复输入'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('可恢复输入'));
    await tester.pumpAndSettle();

    expect(find.text('质量浓度'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Amount'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Concentration'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Amount'))
          .controller
          ?.text,
      '3',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Concentration'))
          .controller
          ?.text,
      '7',
    );
  });

  testWidgets(
    'Custom formula history tap restores saved formula inputs like iOS',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = LabStore();
      store.savedFormulas = const [
        SavedFormula(
          id: 'formula-history-restore',
          label: '单位换算公式',
          formula: 'mass / volume',
          resultUnit: 'mg/ml',
          variables: [
            FormulaVariable(name: 'mass', value: 10, unit: 'mg'),
            FormulaVariable(name: 'volume', value: 10, unit: 'ml'),
          ],
          steps: [
            CustomCalculationStep(
              outputName: 'result',
              formula: 'mass / volume',
              outputUnit: 'mg/ml',
            ),
          ],
          resultFields: [
            CustomResultField(
              variableName: 'result',
              label: '浓度',
              displayUnit: 'μg/ml',
            ),
          ],
        ),
      ];
      store.calcHistory = const [
        CalcHistoryItem(
          id: 'custom-history',
          title: '单位换算公式',
          result: '浓度: 2000 μg/ml',
          mode: 'custom',
          inputs: {'mass': 20, 'volume': 10},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ToolsScreen(store: store)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('可恢复输入'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('可恢复输入'));
      await tester.pumpAndSettle();

      expect(find.text('公式计算'), findsOneWidget);
      expect(find.text('单位换算公式'), findsOneWidget);
      expect(find.text('浓度'), findsOneWidget);
      expect(find.textContaining('2000 μg/ml'), findsOneWidget);
      expect(find.widgetWithText(TextField, '数值'), findsNWidgets(2));
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '数值').first)
            .controller
            ?.text,
        '20',
      );
    },
  );

  testWidgets('Buffer templates append new items and edit in place like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    const first = BufferTemplate(
      id: 'buffer-first',
      name: '第一个模板',
      area: '细胞实验',
      baseVolume: 100,
      volumeUnit: 'ml',
      ingredients: [],
    );
    const second = BufferTemplate(
      id: 'buffer-second',
      name: '第二个模板',
      area: '细胞实验',
      baseVolume: 50,
      volumeUnit: 'ml',
      ingredients: [],
    );

    await store.upsertBufferTemplate(first);
    await store.upsertBufferTemplate(second);

    expect(store.bufferTemplates.map((item) => item.id), [
      'buffer-first',
      'buffer-second',
    ]);

    await store.upsertBufferTemplate(second.copyWith(name: '第二个模板更新'));

    expect(store.bufferTemplates.map((item) => item.id), [
      'buffer-first',
      'buffer-second',
    ]);
    expect(store.bufferTemplates.last.name, '第二个模板更新');
  });

  testWidgets('Built-in buffer templates cannot be deleted like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.bufferTemplates = [
      ...sampleBufferTemplates.take(1),
      const BufferTemplate(
        id: 'custom-buffer-delete',
        name: '自定义模板',
        area: '细胞实验',
        baseVolume: 100,
        volumeUnit: 'ml',
        ingredients: [],
      ),
    ];

    await store.deleteBufferTemplate(sampleBufferTemplates.first.id);
    expect(
      store.bufferTemplates.any(
        (template) => template.id == sampleBufferTemplates.first.id,
      ),
      isTrue,
    );

    await store.deleteBufferTemplate('custom-buffer-delete');
    expect(
      store.bufferTemplates.any(
        (template) => template.id == 'custom-buffer-delete',
      ),
      isFalse,
    );
  });

  testWidgets('Buffer template editor uses iOS-style structured ingredients', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BufferTemplateEditorSheet(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新增模板'), findsOneWidget);
    expect(find.text('配方成分'), findsOneWidget);
    expect(find.text('成分A'), findsOneWidget);
    expect(find.textContaining('(缩放)'), findsOneWidget);
    expect(find.textContaining('scale/fixed'), findsNothing);

    await tester.tap(find.byType(IosPlusCircleButton).last);
    await tester.pumpAndSettle();
    expect(find.text('编辑成分'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '名称').last, 'Tris');
    await tester.enterText(find.widgetWithText(TextField, '用量'), '50');
    await tester.enterText(find.widgetWithText(TextField, '单位').last, 'mM');

    await tester.tap(find.text('保存成分'));
    await tester.pumpAndSettle();

    expect(find.text('Tris'), findsOneWidget);
    expect(find.textContaining('50 mM'), findsOneWidget);

    await tester.tap(find.text('保存模板'));
    await tester.pumpAndSettle();

    expect(store.bufferTemplates.first.ingredients.length, 2);
    expect(store.bufferTemplates.first.ingredients.last.name, 'Tris');
    expect(store.bufferTemplates.first.ingredients.last.unit, 'mM');
  });

  testWidgets(
    'Existing buffer template editor omits whole-template delete like iOS',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = LabStore();
      const template = BufferTemplate(
        id: 'buffer-editor-delete-entry',
        name: '编辑入口模板',
        area: '细胞实验',
        baseVolume: 100,
        volumeUnit: 'ml',
        ingredients: [
          BufferIngredient(
            id: 'buffer-editor-delete-ingredient',
            name: 'Tris',
            amount: 50,
            unit: 'mM',
            scalable: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BufferTemplateEditorSheet(store: store, existing: template),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('编辑模板'), findsOneWidget);
      expect(find.text('保存模板'), findsOneWidget);
      expect(find.text('删除模板'), findsNothing);
      expect(find.byType(IosSwipeDelete), findsOneWidget);
    },
  );

  testWidgets('Buffer template screen supports iOS-style direct recipe edits', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final template = BufferTemplate(
      id: 'buffer-direct-edit',
      name: '直接编辑模板',
      area: '细胞实验',
      baseVolume: 100,
      volumeUnit: 'ml',
      ingredients: const [
        BufferIngredient(
          id: 'buffer-direct-a',
          name: 'NaCl',
          amount: 1,
          unit: 'g',
          scalable: true,
        ),
      ],
    );
    store.bufferTemplates = [template];

    await tester.pumpWidget(
      MaterialApp(
        home: BufferTemplateScreen(store: store, template: template),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('配方缩放'), findsOneWidget);
    expect(find.byTooltip('保存模板'), findsOneWidget);
    expect(find.byTooltip('选择体积单位'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '模板名称'), '直接编辑后的模板');
    await tester.tap(find.byType(IosPlusCircleButton).last);
    await tester.pumpAndSettle();
    expect(find.text('编辑成分'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '名称').last, 'HEPES');
    await tester.enterText(find.widgetWithText(TextField, '用量'), '25');
    await tester.enterText(find.widgetWithText(TextField, '单位').last, 'mM');
    await tester.tap(find.text('保存成分'));
    await tester.pumpAndSettle();

    expect(find.text('HEPES'), findsOneWidget);
    await tester.tap(find.byTooltip('保存模板'));
    await tester.pumpAndSettle();

    expect(store.bufferTemplates.first.name, '直接编辑后的模板');
    expect(store.bufferTemplates.first.ingredients.length, 2);
    expect(store.bufferTemplates.first.ingredients.last.name, 'HEPES');
  });

  testWidgets('PEI calculator exposes dynamic plasmid groups like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();

    await tester.pumpWidget(MaterialApp(home: ToolsScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PEI 转染配方'));
    await tester.pumpAndSettle();

    expect(find.text('培养皿剂量'), findsOneWidget);
    expect(find.text('质粒分组'), findsOneWidget);
    expect(find.text('Transfer plasmid'), findsOneWidget);
    expect(find.text('psPAX2'), findsOneWidget);
    expect(find.text('pCMV-VSVG'), findsOneWidget);
    expect(find.text('目的质粒'), findsOneWidget);
    expect(find.text('辅助质粒'), findsOneWidget);
    expect(find.text('包膜质粒'), findsWidgets);
    expect(find.text('新增分组'), findsOneWidget);
    expect(find.byTooltip('删除分组'), findsWidgets);
    expect(find.byTooltip('删除质粒'), findsNothing);
    final plasmidSwipeRows = tester.widgetList<IosSwipeDelete>(
      find.byType(IosSwipeDelete),
    );
    expect(
      plasmidSwipeRows.where((row) => row.confirmTitle == '删除质粒？'),
      isNotEmpty,
    );
    expect(find.text('比例计算对象：目的质粒组合'), findsOneWidget);
    expect(find.text('比例计算对象：包装/辅助质粒'), findsOneWidget);
    expect(find.text('比例计算对象：包膜质粒'), findsWidgets);
    expect(find.byTooltip('选择比例计算对象'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byTooltip('选择比例计算对象').first,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('选择比例计算对象').first);
    await tester.pumpAndSettle();
    expect(find.text('目的质粒组合'), findsOneWidget);
    expect(find.text('包装/辅助质粒'), findsOneWidget);
    expect(find.text('包膜质粒'), findsWidgets);
    await tester.tap(find.text('包膜质粒').last);
    await tester.pumpAndSettle();
    expect(find.text('比例计算对象：包膜质粒'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byTooltip('添加质粒').first,
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加质粒').first);
    await tester.pumpAndSettle();
    expect(find.text('质粒 2'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('新增分组'),
      -220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增分组'));
    await tester.pumpAndSettle();
    expect(find.text('质粒分组 4'), findsOneWidget);
    expect(find.text('新质粒'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('不同培养容器转染用量'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('不同培养容器转染用量'), findsOneWidget);
    expect(find.text('仅供参考，实际计算仍按上方输入值执行。'), findsOneWidget);
    expect(find.text('DNA μg'), findsOneWidget);

    await tester.tap(find.text('添加').last);
    await tester.pumpAndSettle();
    expect(find.text('编辑参考'), findsOneWidget);
    expect(find.text('培养基总量'), findsOneWidget);

    tester
            .widget<TextField>(
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is TextField &&
                        widget.decoration?.labelText == '培养皿',
                  )
                  .first,
            )
            .controller
            ?.text =
        '新培养皿 A';
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('新培养皿 A').last,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('新培养皿 A'), findsWidgets);

    await tester.tap(find.text('新培养皿 A').last);
    await tester.pumpAndSettle();
    expect(find.text('删除这条参考'), findsOneWidget);
  });

  testWidgets('Saved formulas expose visible edit action like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    await store.upsertSavedFormula(
      const SavedFormula(
        id: 'formula-density',
        label: '细胞接种密度',
        formula: 'cells / area',
        resultUnit: 'cells/cm2',
        variables: [
          FormulaVariable(name: 'cells', value: 100000, unit: 'cells'),
          FormulaVariable(name: 'area', value: 10, unit: 'cm2'),
        ],
      ),
    );

    await tester.pumpWidget(MaterialApp(home: ToolsScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('已保存的公式'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('已保存的公式'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('细胞接种密度'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('细胞接种密度'), findsOneWidget);
    expect(find.byTooltip('编辑公式'), findsOneWidget);

    await tester.tap(find.text('细胞接种密度'));
    await tester.pumpAndSettle();
    expect(findFormulaEditorTitle(), findsOneWidget);
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.controller?.text == 'cells / area'),
      isTrue,
    );
    expect(find.text('删除公式'), findsNothing);
  });

  testWidgets('Protocol library sorts favorites first like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.protocols = [sampleProtocols[0], sampleProtocols[1]];
    store.favoriteProtocolIds = [sampleProtocols[1].id];

    await tester.pumpWidget(MaterialApp(home: ProtocolScreen(store: store)));
    await tester.pumpAndSettle();

    final favoriteY = tester.getTopLeft(find.text(sampleProtocols[1].name)).dy;
    final regularY = tester.getTopLeft(find.text(sampleProtocols[0].name)).dy;
    expect(favoriteY, lessThan(regularY));
  });

  testWidgets('Protocol library reorder mode moves protocols like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.protocols = [sampleProtocols[0], sampleProtocols[1]];

    await tester.pumpWidget(MaterialApp(home: ProtocolScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('排序'), findsOneWidget);
    await tester.tap(find.text('排序'));
    await tester.pumpAndSettle();

    expect(find.text('完成'), findsOneWidget);
    expect(find.byTooltip('上移 Protocol'), findsWidgets);
    await tester.tap(find.byTooltip('上移 Protocol').last);
    await tester.pumpAndSettle();

    expect(store.protocols.first.id, sampleProtocols[1].id);
    final movedY = tester.getTopLeft(find.text(sampleProtocols[1].name)).dy;
    final shiftedY = tester.getTopLeft(find.text(sampleProtocols[0].name)).dy;
    expect(movedY, lessThan(shiftedY));
  });

  testWidgets('Protocol library card opens editor like iOS', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    store.protocols = [sampleProtocols.first];

    await tester.pumpWidget(MaterialApp(home: ProtocolScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑 Protocol').first);
    await tester.pumpAndSettle();

    expect(find.text('编辑 Protocol'), findsOneWidget);
    expect(find.text(sampleProtocols.first.name), findsWidgets);
  });

  testWidgets('Protocol library explicit delete removes protocol and indexes', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = sampleProtocols.first;
    store.protocols = [protocol];
    store.favoriteProtocolIds = [protocol.id];
    store.recentProtocolIds = [protocol.id];

    await tester.pumpWidget(MaterialApp(home: ProtocolScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('删除 Protocol'), findsOneWidget);
    await tester.tap(find.byTooltip('删除 Protocol'));
    await tester.pumpAndSettle();

    expect(find.text('删除 Protocol？'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(store.protocols, isEmpty);
    expect(store.favoriteProtocolIds, isEmpty);
    expect(store.recentProtocolIds, isEmpty);
    expect(find.text(protocol.name), findsNothing);
  });

  testWidgets('Protocol library swipe delete button removes protocol', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LabStore();
    final protocol = sampleProtocols.first;
    store.protocols = [protocol];

    await tester.pumpWidget(MaterialApp(home: ProtocolScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(IosSwipeDelete).first, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(find.text('删除'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除 Protocol？'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(store.protocols, isEmpty);
  });

  testWidgets('Protocol cards use area-tinted iOS-style sections', (
    WidgetTester tester,
  ) async {
    final protocol = sampleProtocols.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProtocolLibraryTile(
            protocol: protocol,
            favorite: true,
            onFavorite: () {},
            onOpen: () {},
            onEdit: () {},
            onDelete: () async {},
            onCreateRun: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(protocol.name), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is IosGlyphIcon && widget.glyph == IosGlyph.star;
      }),
      findsOneWidget,
    );

    final expectedCellAccent = const Color(0xFF00C7BE);
    final tintedSections = tester
        .widgetList<Container>(find.byType(Container))
        .where((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.color == expectedCellAccent.withValues(alpha: 0.06);
        });
    expect(tintedSections.length, greaterThanOrEqualTo(1));
  });

  testWidgets('Timeline rule renders iOS-style active hour marker', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TimelineTimeRule(label: '11:00', active: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('11:00'), findsOneWidget);
    final tealDots = tester.widgetList<Container>(find.byType(Container)).where(
      (container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            decoration.color == const Color(0xFF00C7BE).withValues(alpha: 0.70);
      },
    );
    expect(tealDots.length, greaterThanOrEqualTo(1));
  });
}

Color _testAlpha(Color color, double alpha) => color.withValues(alpha: alpha);

String _testDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
