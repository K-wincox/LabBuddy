import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const LabBuddyAndroidApp());
}

const _teal = Color(0xFF00C7BE);
const _mint = Color(0xFFE6F7F6);
const _ink = Color(0xFF15201F);
const _muted = Color(0xFF7D8583);
const _line = Color(0xFFE7EEEC);
const _labBackground = Color(0xFFF2F7F7);
const _labPanel = Color(0xFFFFFFFC);
const _labInset = Color(0xFFE6F2F2);
const _labDarkBackground = Color(0xFF101816);
const _labDarkPanel = Color(0xFF18211F);
const _labDarkInset = Color(0xFF22302D);
const _iosTopOffset = 78.0;
const _iosToolsTopOffset = 72.0;
const defaultProjectPalette = [
  0xFF007AFF,
  0xFF34C759,
  0xFF5856D6,
  0xFFFF9500,
  0xFFAF52DE,
  0xFF00C7BE,
  0xFFFF3B30,
  0xFF32ADE6,
  0xFFFFCC00,
  0xFFFF375F,
];
const defaultExperimentPalette = [
  0xFF007AFF,
  0xFF34C759,
  0xFF5856D6,
  0xFFFF9500,
  0xFFAF52DE,
  0xFF00C7BE,
  0xFFFF3B30,
  0xFF32ADE6,
  0xFFFFCC00,
  0xFFFF375F,
  0xFF6366EA,
  0xFF3DAEE9,
];
const _dataCardChannel = MethodChannel('labbuddy/data_card');
const _timerChannel = MethodChannel('labbuddy/timers');
const _backupChannel = MethodChannel('labbuddy/backup');
const _profileChannel = MethodChannel('labbuddy/profile');
const _defaultAuthApiBaseUrl = 'http://127.0.0.1:18088';
const demoLoginEmail = 'demo@labbuddy.app';
const demoLoginPassword = 'labbuddy2026';
const demoLoginName = 'LabBuddy Demo';
const demoLoginLabName = '个人本地工作区';
const _defaultProfileAvatarAsset = 'assets/profile-avatar.png';
const builtInExperimentAreas = ['细胞实验', '分子克隆', 'WB/跑胶', '核酸实验', '蛋白实验'];
const builtInUnits = [
  'μl',
  'ml',
  'L',
  'ng',
  'μg',
  'mg',
  'g',
  'ng/μl',
  'μg/μl',
  'μg/ml',
  'mg/ml',
  'M',
  'mM',
  'μM',
  'nM',
  'g/mol',
  'kDa',
  'Da',
  'reaction',
  'tube',
  'flask',
];
const builtInUnitGroups = <String, List<String>>{
  '体积': ['μl', 'ml', 'L'],
  '质量': ['ng', 'μg', 'mg', 'g'],
  '浓度': ['ng/μl', 'μg/μl', 'μg/ml', 'mg/ml', 'M', 'mM', 'μM', 'nM'],
  '分子量': ['g/mol', 'kDa', 'Da'],
  '计数': ['reaction', 'tube', 'flask'],
};

enum IosGlyph {
  calendar,
  clipboard,
  personCircle,
  search,
  sliders,
  docText,
  chevronRight,
  function,
  tray,
  upload,
  download,
  beaker,
  drop,
  percent,
  waveform,
  sqrt,
  photo,
  plusCircle,
  plusCircleFill,
  palette,
  creditCard,
  star,
}

ImageProvider<Object> _profileAvatarImage(String? avatarPath) {
  final usablePath = _usableAvatarPath(avatarPath);
  if (usablePath != null) {
    return FileImage(File(usablePath));
  }
  return const AssetImage(_defaultProfileAvatarAsset);
}

String? _usableAvatarPath(String? avatarPath) {
  if (avatarPath == null || avatarPath.isEmpty) return null;
  final lower = avatarPath.toLowerCase();
  final looksLikeImage =
      lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp');
  if (!looksLikeImage) return null;
  final file = File(avatarPath);
  if (!file.existsSync() || file.lengthSync() <= 0) return null;
  return avatarPath;
}

String _formatNumber(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  return value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(value.abs() < 10 ? 2 : 1);
}

class IosProgressBar extends StatelessWidget {
  const IosProgressBar({
    super.key,
    required this.value,
    this.color = _teal,
    this.trackColor = _labInset,
    this.height = 5,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

String _scaledAmountLabel(String amount, double scaleFactor) {
  final parsed = double.tryParse(amount);
  if (parsed == null) return amount;
  return _formatNumber(parsed * scaleFactor);
}

String _stepReagentAmountLabel(
  StepReagent reagent,
  double scaleFactor,
  Map<String, double> variables,
) {
  if (reagent.isFormula) {
    try {
      return _formatNumber(
        FormulaParser(reagent.amountExpression, variables).parse(),
      );
    } on FormatException {
      return reagent.amountExpression;
    }
  }
  return _scaledAmountLabel(reagent.amountExpression, scaleFactor);
}

String _draftId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(9999)}';

String _safeFormulaName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'v';
  final normalized = trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  final startsWithDigit = RegExp(r'^[0-9]').hasMatch(normalized);
  return startsWithDigit ? 'v_$normalized' : normalized;
}

Map<String, double> _protocolVariableMap(Iterable<ProtocolVariable> variables) {
  final values = <String, double>{};
  for (final variable in variables) {
    values[variable.symbol] = variable.computedBaseValue;
    values[variable.name] = variable.computedBaseValue;
    values[_safeFormulaName(variable.name)] = variable.computedBaseValue;
  }
  return values;
}

String _formulaPreview(
  String expression,
  Iterable<_ProtocolVariableDraft> variables,
  String unit,
) {
  if (expression.trim().isEmpty) return '输入公式';
  final values = <String, double>{};
  for (final draft in variables) {
    final value = double.tryParse(draft.valueController.text.trim()) ?? 0;
    final symbol = draft.symbolController.text.trim();
    if (symbol.isNotEmpty) values[_safeFormulaName(symbol)] = value;
    final name = draft.nameController.text.trim();
    if (name.isNotEmpty) {
      values[name] = value;
      values[_safeFormulaName(name)] = value;
    }
  }
  try {
    final value = FormulaParser(expression, values).parse();
    return '${_formatNumber(value)} $unit';
  } on FormatException {
    return '无法计算';
  }
}

List<String> _protocolConsistencyIssuesFromDrafts({
  required Iterable<_ProtocolVariableDraft> variables,
  required Iterable<_ProtocolStepDraft> steps,
}) {
  final values = <String, double>{};
  final symbols = <String>[];
  for (final draft in variables) {
    final value = double.tryParse(draft.valueController.text.trim()) ?? 0;
    final symbol = _safeFormulaName(draft.symbolController.text.trim());
    if (symbol.isNotEmpty) {
      symbols.add(symbol);
      values[symbol] = value;
    }
    final name = draft.nameController.text.trim();
    if (name.isNotEmpty) {
      values[name] = value;
      values[_safeFormulaName(name)] = value;
    }
  }

  final missingRefs = <String>[];
  for (final step in steps) {
    for (final reagent in step.reagents) {
      if (!reagent.formulaMode.value) continue;
      final expression = reagent.amountController.text.trim();
      if (expression.isEmpty) continue;
      try {
        FormulaParser(expression, values).parse();
      } on FormatException catch (error) {
        final message = error.message;
        const prefix = '未知变量：';
        if (message.startsWith(prefix)) {
          missingRefs.add(message.substring(prefix.length));
        }
      }
    }
  }

  final duplicateSymbols = <String>[];
  final seen = <String>{};
  for (final symbol in symbols) {
    if (!seen.add(symbol)) duplicateSymbols.add(symbol);
  }

  return [
    if (missingRefs.isNotEmpty) '步骤引用了未定义变量 ${missingRefs.first}',
    if (duplicateSymbols.isNotEmpty) '变量 ${duplicateSymbols.first} 重复定义',
  ];
}

String _protocolVariableFormulaToken(_ProtocolVariableDraft variable) {
  final name = variable.nameController.text.trim();
  if (name.isNotEmpty) return name;
  final symbol = variable.symbolController.text.trim();
  if (symbol.isNotEmpty) return _safeFormulaName(symbol);
  return 'v';
}

String _protocolVariableDisplayName(_ProtocolVariableDraft variable) {
  final name = variable.nameController.text.trim();
  if (name.isNotEmpty) return name;
  final symbol = variable.symbolController.text.trim();
  if (symbol.isNotEmpty) return _safeFormulaName(symbol);
  return 'v';
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF3B30),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

class IosSwipeDelete extends StatefulWidget {
  const IosSwipeDelete({
    super.key,
    required this.child,
    required this.onDelete,
    required this.confirmTitle,
    required this.confirmMessage,
  });

  final Widget child;
  final Future<void> Function() onDelete;
  final String confirmTitle;
  final String confirmMessage;

  @override
  State<IosSwipeDelete> createState() => _IosSwipeDeleteState();
}

class _IosSwipeDeleteState extends State<IosSwipeDelete> {
  static const _deleteWidth = 86.0;
  double _offset = 0;

  bool get _revealed => _offset < -1;

  Future<void> _delete(BuildContext context) async {
    final ok = await _confirmDelete(
      context,
      title: widget.confirmTitle,
      message: widget.confirmMessage,
    );
    if (!mounted) return;
    if (ok) {
      await widget.onDelete();
    } else {
      setState(() => _offset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: _revealed
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _delete(context),
                      child: Container(
                        width: _deleteWidth,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                        ),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 23,
                            ),
                            SizedBox(height: 2),
                            Text(
                              '删除',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              final next = (_offset + details.delta.dx).clamp(
                -_deleteWidth,
                0.0,
              );
              if (next != _offset) setState(() => _offset = next);
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final shouldReveal = velocity < -250 || _offset < -36;
              setState(() => _offset = shouldReveal ? -_deleteWidth : 0);
            },
            onTap: _revealed ? () => setState(() => _offset = 0) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_offset, 0, 0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class LabBuddyAndroidApp extends StatelessWidget {
  const LabBuddyAndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppGate();
  }
}

ThemeData _buildLabTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? _labDarkBackground : _labBackground;
  final panel = dark ? _labDarkPanel : _labPanel;
  final inset = dark ? _labDarkInset : _labInset;
  final border = dark ? const Color(0xFF2D3A37) : _line;
  final scheme = ColorScheme.fromSeed(seedColor: _teal, brightness: brightness)
      .copyWith(
        primary: _teal,
        secondary: _teal,
        surface: panel,
        surfaceContainerLowest: background,
        surfaceContainerLow: panel,
        surfaceContainer: panel,
        surfaceContainerHigh: inset,
        surfaceContainerHighest: inset,
        onSurface: dark ? Colors.white : _ink,
        outline: border,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    splashColor: _teal.withValues(alpha: 0.08),
    highlightColor: _teal.withValues(alpha: 0.06),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: background,
      foregroundColor: dark ? Colors.white : _ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: dark ? Colors.white : _ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: dark ? border : const Color(0xFFE8EFEC),
          width: 0.55,
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: _iosLikeTextTheme(brightness),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inset,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _teal, width: 1.4),
      ),
      labelStyle: TextStyle(color: dark ? Colors.white70 : _muted),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: panel,
      elevation: 0,
      selectedItemColor: _teal,
      unselectedItemColor: dark ? Colors.white70 : _muted,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? _teal : panel,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : (dark ? Colors.white : _ink),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        visualDensity: VisualDensity.compact,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _teal,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        visualDensity: VisualDensity.compact,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _teal,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: _teal,
        disabledForegroundColor: dark ? Colors.white38 : _muted,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _teal,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: dark ? Colors.white24 : _muted.withValues(alpha: 0.28),
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: _teal,
      linearTrackColor: inset,
      circularTrackColor: inset,
    ),
    dividerTheme: DividerThemeData(color: border, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: inset,
      selectedColor: _teal.withValues(alpha: 0.14),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(color: dark ? Colors.white70 : _muted),
    ),
  );
}

TextTheme _iosLikeTextTheme(Brightness brightness) {
  final color = brightness == Brightness.dark ? Colors.white : _ink;
  final muted = brightness == Brightness.dark ? Colors.white70 : _muted;
  const family = '.SF Pro Text';
  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 31,
      height: 1.08,
      fontWeight: FontWeight.w800,
    ),
    displayMedium: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 28,
      height: 1.1,
      fontWeight: FontWeight.w800,
    ),
    headlineLarge: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 25,
      height: 1.14,
      fontWeight: FontWeight.w800,
    ),
    headlineMedium: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 22,
      height: 1.16,
      fontWeight: FontWeight.w800,
    ),
    headlineSmall: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 20,
      height: 1.18,
      fontWeight: FontWeight.w800,
    ),
    titleLarge: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 20,
      height: 1.18,
      fontWeight: FontWeight.w800,
    ),
    titleMedium: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 17,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 15,
      height: 1.22,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 16,
      height: 1.28,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 14,
      height: 1.28,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontFamily: family,
      color: muted,
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontFamily: family,
      color: color,
      fontSize: 15,
      height: 1.18,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: TextStyle(
      fontFamily: family,
      color: muted,
      fontSize: 13,
      height: 1.15,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontFamily: family,
      color: muted,
      fontSize: 11,
      height: 1.12,
      fontWeight: FontWeight.w600,
    ),
  );
}

class LabPreferences {
  const LabPreferences({
    this.largeBenchMode = true,
    this.dataCardWatermark = true,
    this.compactCards = false,
    this.showStepDuration = true,
    this.timerSound = true,
    this.haptics = true,
    this.autoSave = true,
    this.fontScale = 1.0,
    this.colorScheme = 'system',
    this.apiBaseUrl = _defaultAuthApiBaseUrl,
    this.isProUser = false,
    this.voiceAnnouncementEnabled = true,
    this.voiceAnnouncementTemplate = defaultVoiceAnnouncementTemplate,
  });

  static const defaultVoiceAnnouncementTemplate = '{实验}，{步骤}已完成';

  final bool largeBenchMode;
  final bool dataCardWatermark;
  final bool compactCards;
  final bool showStepDuration;
  final bool timerSound;
  final bool haptics;
  final bool autoSave;
  final double fontScale;
  final String colorScheme;
  final String apiBaseUrl;
  final bool isProUser;
  final bool voiceAnnouncementEnabled;
  final String voiceAnnouncementTemplate;

  LabPreferences copyWith({
    bool? largeBenchMode,
    bool? dataCardWatermark,
    bool? compactCards,
    bool? showStepDuration,
    bool? timerSound,
    bool? haptics,
    bool? autoSave,
    double? fontScale,
    String? colorScheme,
    String? apiBaseUrl,
    bool? isProUser,
    bool? voiceAnnouncementEnabled,
    String? voiceAnnouncementTemplate,
  }) => LabPreferences(
    largeBenchMode: largeBenchMode ?? this.largeBenchMode,
    dataCardWatermark: dataCardWatermark ?? this.dataCardWatermark,
    compactCards: compactCards ?? this.compactCards,
    showStepDuration: showStepDuration ?? this.showStepDuration,
    timerSound: timerSound ?? this.timerSound,
    haptics: haptics ?? this.haptics,
    autoSave: autoSave ?? this.autoSave,
    fontScale: fontScale ?? this.fontScale,
    colorScheme: colorScheme ?? this.colorScheme,
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    isProUser: isProUser ?? this.isProUser,
    voiceAnnouncementEnabled:
        voiceAnnouncementEnabled ?? this.voiceAnnouncementEnabled,
    voiceAnnouncementTemplate:
        voiceAnnouncementTemplate ?? this.voiceAnnouncementTemplate,
  );

  Map<String, dynamic> toJson() => {
    'largeBenchMode': largeBenchMode,
    'dataCardWatermark': dataCardWatermark,
    'compactCards': compactCards,
    'showStepDuration': showStepDuration,
    'timerSound': timerSound,
    'haptics': haptics,
    'autoSave': autoSave,
    'fontScale': fontScale,
    'colorScheme': colorScheme,
    'apiBaseUrl': apiBaseUrl,
    'isProUser': isProUser,
    'voiceAnnouncementEnabled': voiceAnnouncementEnabled,
    'voiceAnnouncementTemplate': voiceAnnouncementTemplate,
  };

  factory LabPreferences.fromJson(Map<String, dynamic> json) => LabPreferences(
    largeBenchMode: json['largeBenchMode'] as bool? ?? true,
    dataCardWatermark: json['dataCardWatermark'] as bool? ?? true,
    compactCards: json['compactCards'] as bool? ?? false,
    showStepDuration: json['showStepDuration'] as bool? ?? true,
    timerSound: json['timerSound'] as bool? ?? true,
    haptics: json['haptics'] as bool? ?? true,
    autoSave: json['autoSave'] as bool? ?? true,
    fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
    colorScheme: json['colorScheme'] as String? ?? 'system',
    apiBaseUrl: _normalizedAuthApiBaseUrl(json['apiBaseUrl'] as String?),
    isProUser: json['isProUser'] as bool? ?? false,
    voiceAnnouncementEnabled: json['voiceAnnouncementEnabled'] as bool? ?? true,
    voiceAnnouncementTemplate:
        json['voiceAnnouncementTemplate'] as String? ??
        LabPreferences.defaultVoiceAnnouncementTemplate,
  );
}

String _normalizedAuthApiBaseUrl(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return _defaultAuthApiBaseUrl;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return _defaultAuthApiBaseUrl;
  }
  if (uri.host.startsWith('172.16.') && uri.port == 18088) {
    return _defaultAuthApiBaseUrl;
  }
  return trimmed;
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  late final LabStore store;
  bool ready = false;
  bool _newDayPromptShown = false;

  @override
  void initState() {
    super.initState();
    store = LabStore();
    _load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await store.load();
    if (!mounted) return;
    setState(() => ready = true);
  }

  Future<void> _maybeShowNewDayPrompt(BuildContext sheetContext) async {
    if (_newDayPromptShown || !store.needsNewDayRollover) return;
    _newDayPromptShown = true;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !sheetContext.mounted || !store.needsNewDayRollover) {
      return;
    }
    final action = await showModalBottomSheet<bool>(
      context: sheetContext,
      isScrollControlled: true,
      builder: (_) => const _NewDayConfirmSheet(),
    );
    if (action == true) {
      await store.confirmNewDayRollover();
    } else {
      await store.dismissNewDayRollover();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final pref = store.preferences;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LabBuddy',
          themeMode: pref.colorScheme == 'dark'
              ? ThemeMode.dark
              : pref.colorScheme == 'light'
              ? ThemeMode.light
              : ThemeMode.system,
          theme: _buildLabTheme(Brightness.light),
          darkTheme: _buildLabTheme(Brightness.dark),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(pref.fontScale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: !ready
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : store.isAuthenticated
              ? Builder(
                  builder: (context) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _maybeShowNewDayPrompt(context);
                    });
                    return LabBuddyShell(store: store);
                  },
                )
              : AuthScreen(store: store),
        );
      },
    );
  }
}

class _NewDayConfirmSheet extends StatelessWidget {
  const _NewDayConfirmSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wb_twilight, color: _teal, size: 52),
            const SizedBox(height: 18),
            Text(
              '检测到新的一天',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '是否将昨天的实验归档，并将明天的计划移入今天？',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.35),
            ),
            const SizedBox(height: 16),
            const Text(
              '每一天的数据都值得被好好记录',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _teal,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('开始新的一天'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('暂时保持现状'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LabBuddyShell extends StatefulWidget {
  const LabBuddyShell({super.key, required this.store});

  final LabStore store;

  @override
  State<LabBuddyShell> createState() => _LabBuddyShellState();
}

class _LabBuddyShellState extends State<LabBuddyShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(store: widget.store),
      ProtocolScreen(store: widget.store),
      ToolsScreen(store: widget.store),
      MyScreen(store: widget.store),
    ];
    return Scaffold(
      body: Stack(
        children: [
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: pages[index],
          ),
          _IosStatusOverlay(pageIndex: index),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: _labPanel.withValues(alpha: 0.86),
                border: Border(
                  top: BorderSide(
                    color: _line.withValues(alpha: 0.92),
                    width: 0.7,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _IosTabBarItem(
                    glyph: IosGlyph.calendar,
                    label: '今日',
                    selected: index == 0,
                    onTap: () => setState(() => index = 0),
                  ),
                  _IosTabBarItem(
                    glyph: IosGlyph.clipboard,
                    label: 'Protocol',
                    selected: index == 1,
                    onTap: () => setState(() => index = 1),
                  ),
                  _IosTabBarItem(
                    glyph: IosGlyph.function,
                    label: '工具',
                    selected: index == 2,
                    onTap: () => setState(() => index = 2),
                  ),
                  _IosTabBarItem(
                    glyph: IosGlyph.personCircle,
                    label: '我的',
                    selected: index == 3,
                    onTap: () => setState(() => index = 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosStatusOverlay extends StatelessWidget {
  const _IosStatusOverlay({required this.pageIndex});

  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final timeLabel = switch (pageIndex) {
      0 => '11:31',
      1 => '11:40',
      2 => '11:41',
      _ => '11:42',
    };
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      child: IgnorePointer(
        child: SizedBox(
          height: 78,
          child: Stack(
            children: [
              Positioned(
                left: 52,
                top: 15,
                child: Text(
                  timeLabel,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 126,
                  height: 38,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              Positioned(
                right: 49,
                top: 11,
                child: const _IosStatusIndicators(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosStatusIndicators extends StatelessWidget {
  const _IosStatusIndicators();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '••••',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.22),
            fontSize: 19,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 8),
        const _IosWifiIcon(),
        const SizedBox(width: 8),
        const _IosBatteryIcon(),
      ],
    );
  }
}

class _IosWifiIcon extends StatelessWidget {
  const _IosWifiIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(23, 17), painter: _IosWifiPainter());
  }
}

class _IosWifiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final wifi = Path()
      ..moveTo(2.2, 5.6)
      ..quadraticBezierTo(11.5, -1.1, 20.8, 5.6)
      ..moveTo(6.6, 10.8)
      ..quadraticBezierTo(11.5, 7.0, 16.4, 10.8)
      ..moveTo(10.7, 15.0)
      ..quadraticBezierTo(11.5, 14.4, 12.3, 15.0);
    canvas.drawPath(wifi, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IosBatteryIcon extends StatelessWidget {
  const _IosBatteryIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(31, 17), painter: _IosBatteryPainter());
  }
}

class _IosBatteryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final fill = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.8, 2.7, 27, 13.5),
        const Radius.circular(3.8),
      ),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.4, 5.9, 18.3, 6.5),
        const Radius.circular(1.7),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28.8, 7.1, 2.3, 4.7),
        const Radius.circular(1.2),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IosTabBarItem extends StatelessWidget {
  const _IosTabBarItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IosGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _teal : _muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: TextStyle(
            color: color,
            fontSize: 10.8,
            height: 1,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: selected ? 1.02 : 1.0,
                child: IosGlyphIcon(glyph, color: color, size: 24),
              ),
              const SizedBox(height: 3),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class IosGlyphIcon extends StatelessWidget {
  const IosGlyphIcon(
    this.glyph, {
    super.key,
    required this.color,
    this.size = 24,
  });

  final IosGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IosGlyphPainter(glyph, color)),
    );
  }
}

class _IosGlyphPainter extends CustomPainter {
  const _IosGlyphPainter(this.glyph, this.color);

  final IosGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = math.max(1.7, s * 0.085);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    double x(double value) => value * s;
    double y(double value) => value * s;

    switch (glyph) {
      case IosGlyph.calendar:
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x(0.13), y(0.20), x(0.74), y(0.66)),
          Radius.circular(x(0.10)),
        );
        canvas.drawRRect(r, paint);
        canvas.drawLine(
          Offset(x(0.13), y(0.38)),
          Offset(x(0.87), y(0.38)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.30), y(0.13)),
          Offset(x(0.30), y(0.27)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.70), y(0.13)),
          Offset(x(0.70), y(0.27)),
          paint,
        );
        for (final dx in [0.32, 0.50, 0.68]) {
          for (final dy in [0.54, 0.70]) {
            canvas.drawCircle(Offset(x(dx), y(dy)), x(0.028), fill);
          }
        }
      case IosGlyph.clipboard:
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x(0.20), y(0.16), x(0.60), y(0.72)),
          Radius.circular(x(0.08)),
        );
        canvas.drawRRect(r, paint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x(0.36), y(0.09), x(0.28), y(0.16)),
            Radius.circular(x(0.06)),
          ),
          paint,
        );
        for (final dy in [0.42, 0.57, 0.72]) {
          canvas.drawLine(
            Offset(x(0.34), y(dy)),
            Offset(x(0.66), y(dy)),
            paint,
          );
        }
      case IosGlyph.personCircle:
        canvas.drawCircle(Offset(x(0.50), y(0.50)), x(0.39), paint);
        canvas.drawCircle(Offset(x(0.50), y(0.38)), x(0.12), fill);
        final body = Path()
          ..moveTo(x(0.28), y(0.72))
          ..cubicTo(x(0.34), y(0.58), x(0.66), y(0.58), x(0.72), y(0.72));
        canvas.drawPath(body, paint);
      case IosGlyph.search:
        canvas.drawCircle(Offset(x(0.43), y(0.43)), x(0.25), paint);
        canvas.drawLine(
          Offset(x(0.61), y(0.61)),
          Offset(x(0.83), y(0.83)),
          paint,
        );
      case IosGlyph.sliders:
        for (final dy in [0.25, 0.50, 0.75]) {
          canvas.drawLine(
            Offset(x(0.18), y(dy)),
            Offset(x(0.82), y(dy)),
            paint,
          );
        }
        canvas.drawCircle(Offset(x(0.35), y(0.25)), x(0.065), fill);
        canvas.drawCircle(Offset(x(0.64), y(0.50)), x(0.065), fill);
        canvas.drawCircle(Offset(x(0.45), y(0.75)), x(0.065), fill);
      case IosGlyph.docText:
        final doc = Path()
          ..moveTo(x(0.27), y(0.12))
          ..lineTo(x(0.60), y(0.12))
          ..lineTo(x(0.76), y(0.29))
          ..lineTo(x(0.76), y(0.88))
          ..lineTo(x(0.27), y(0.88))
          ..close();
        canvas.drawPath(doc, paint);
        canvas.drawLine(
          Offset(x(0.60), y(0.12)),
          Offset(x(0.60), y(0.30)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.60), y(0.30)),
          Offset(x(0.76), y(0.30)),
          paint,
        );
        for (final dy in [0.45, 0.58, 0.71]) {
          canvas.drawLine(
            Offset(x(0.38), y(dy)),
            Offset(x(0.65), y(dy)),
            paint,
          );
        }
      case IosGlyph.chevronRight:
        final path = Path()
          ..moveTo(x(0.38), y(0.22))
          ..lineTo(x(0.62), y(0.50))
          ..lineTo(x(0.38), y(0.78));
        canvas.drawPath(path, paint);
      case IosGlyph.function:
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'f(x)',
            style: TextStyle(
              color: color,
              fontSize: s * 0.84,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset((s - textPainter.width) / 2, (s - textPainter.height) / 2),
        );
      case IosGlyph.tray:
        final path = Path()
          ..moveTo(x(0.17), y(0.42))
          ..lineTo(x(0.29), y(0.22))
          ..lineTo(x(0.71), y(0.22))
          ..lineTo(x(0.83), y(0.42))
          ..lineTo(x(0.83), y(0.78))
          ..quadraticBezierTo(x(0.83), y(0.87), x(0.74), y(0.87))
          ..lineTo(x(0.26), y(0.87))
          ..quadraticBezierTo(x(0.17), y(0.87), x(0.17), y(0.78))
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawLine(
          Offset(x(0.17), y(0.42)),
          Offset(x(0.39), y(0.42)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.61), y(0.42)),
          Offset(x(0.83), y(0.42)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.39), y(0.42)),
          Offset(x(0.44), y(0.53)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.56), y(0.53)),
          Offset(x(0.61), y(0.42)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.44), y(0.53)),
          Offset(x(0.56), y(0.53)),
          paint,
        );
      case IosGlyph.upload:
      case IosGlyph.download:
        final box = RRect.fromRectAndRadius(
          Rect.fromLTWH(x(0.23), y(0.35), x(0.54), y(0.46)),
          Radius.circular(x(0.11)),
        );
        canvas.drawRRect(box, paint);
        if (glyph == IosGlyph.upload) {
          canvas.drawLine(
            Offset(x(0.50), y(0.17)),
            Offset(x(0.50), y(0.59)),
            paint,
          );
          canvas.drawLine(
            Offset(x(0.35), y(0.31)),
            Offset(x(0.50), y(0.16)),
            paint,
          );
          canvas.drawLine(
            Offset(x(0.65), y(0.31)),
            Offset(x(0.50), y(0.16)),
            paint,
          );
        } else {
          canvas.drawLine(
            Offset(x(0.50), y(0.13)),
            Offset(x(0.50), y(0.56)),
            paint,
          );
          canvas.drawLine(
            Offset(x(0.35), y(0.42)),
            Offset(x(0.50), y(0.57)),
            paint,
          );
          canvas.drawLine(
            Offset(x(0.65), y(0.42)),
            Offset(x(0.50), y(0.57)),
            paint,
          );
        }
      case IosGlyph.beaker:
        final path = Path()
          ..moveTo(x(0.30), y(0.85))
          ..lineTo(x(0.70), y(0.85))
          ..quadraticBezierTo(x(0.80), y(0.85), x(0.77), y(0.75))
          ..lineTo(x(0.66), y(0.39))
          ..lineTo(x(0.34), y(0.39))
          ..lineTo(x(0.23), y(0.75))
          ..quadraticBezierTo(x(0.20), y(0.85), x(0.30), y(0.85));
        canvas.drawPath(path, paint);
        canvas.drawLine(
          Offset(x(0.34), y(0.39)),
          Offset(x(0.66), y(0.39)),
          paint,
        );
        canvas.drawCircle(Offset(x(0.50), y(0.22)), x(0.065), paint);
        canvas.drawLine(
          Offset(x(0.50), y(0.285)),
          Offset(x(0.50), y(0.39)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.29), y(0.65)),
          Offset(x(0.71), y(0.65)),
          paint,
        );
      case IosGlyph.drop:
        final path = Path()
          ..moveTo(x(0.50), y(0.10))
          ..lineTo(x(0.82), y(0.70))
          ..quadraticBezierTo(x(0.86), y(0.79), x(0.77), y(0.85))
          ..quadraticBezierTo(x(0.50), y(0.98), x(0.23), y(0.85))
          ..quadraticBezierTo(x(0.14), y(0.79), x(0.18), y(0.70))
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawCircle(Offset(x(0.50), y(0.63)), x(0.105), fill);
      case IosGlyph.percent:
        canvas.drawLine(
          Offset(x(0.25), y(0.78)),
          Offset(x(0.75), y(0.22)),
          paint,
        );
        canvas.drawCircle(Offset(x(0.32), y(0.30)), x(0.10), paint);
        canvas.drawCircle(Offset(x(0.68), y(0.70)), x(0.10), paint);
      case IosGlyph.waveform:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x(0.13), y(0.25), x(0.74), y(0.50)),
            Radius.circular(x(0.08)),
          ),
          paint,
        );
        final path = Path()
          ..moveTo(x(0.22), y(0.55))
          ..lineTo(x(0.34), y(0.55))
          ..lineTo(x(0.40), y(0.40))
          ..lineTo(x(0.50), y(0.68))
          ..lineTo(x(0.58), y(0.45))
          ..lineTo(x(0.66), y(0.55))
          ..lineTo(x(0.78), y(0.55));
        canvas.drawPath(path, paint);
      case IosGlyph.sqrt:
        final path = Path()
          ..moveTo(x(0.20), y(0.57))
          ..lineTo(x(0.33), y(0.57))
          ..lineTo(x(0.43), y(0.78))
          ..lineTo(x(0.58), y(0.25))
          ..lineTo(x(0.82), y(0.25));
        canvas.drawPath(path, paint);
        final textPainter = TextPainter(
          text: TextSpan(
            text: 'x',
            style: TextStyle(
              color: color,
              fontSize: s * 0.34,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(x(0.59), y(0.34)));
      case IosGlyph.photo:
        final frame = RRect.fromRectAndRadius(
          Rect.fromLTWH(x(0.12), y(0.18), x(0.76), y(0.64)),
          Radius.circular(x(0.09)),
        );
        canvas.drawRRect(frame, paint);
        canvas.drawCircle(Offset(x(0.67), y(0.34)), x(0.07), paint);
        final mountains = Path()
          ..moveTo(x(0.20), y(0.70))
          ..lineTo(x(0.38), y(0.52))
          ..lineTo(x(0.50), y(0.64))
          ..lineTo(x(0.60), y(0.55))
          ..lineTo(x(0.80), y(0.74));
        canvas.drawPath(mountains, paint);
      case IosGlyph.plusCircle:
        canvas.drawCircle(Offset(x(0.50), y(0.50)), x(0.43), paint);
        canvas.drawLine(
          Offset(x(0.31), y(0.50)),
          Offset(x(0.69), y(0.50)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.50), y(0.31)),
          Offset(x(0.50), y(0.69)),
          paint,
        );
      case IosGlyph.plusCircleFill:
        canvas.drawCircle(Offset(x(0.50), y(0.50)), x(0.47), fill);
        final plusPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, s * 0.105)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawLine(
          Offset(x(0.31), y(0.50)),
          Offset(x(0.69), y(0.50)),
          plusPaint,
        );
        canvas.drawLine(
          Offset(x(0.50), y(0.31)),
          Offset(x(0.50), y(0.69)),
          plusPaint,
        );
      case IosGlyph.palette:
        final path = Path()
          ..moveTo(x(0.49), y(0.12))
          ..cubicTo(x(0.23), y(0.12), x(0.12), y(0.31), x(0.12), y(0.51))
          ..cubicTo(x(0.12), y(0.73), x(0.31), y(0.88), x(0.52), y(0.88))
          ..cubicTo(x(0.68), y(0.88), x(0.77), y(0.80), x(0.74), y(0.70))
          ..cubicTo(x(0.71), y(0.61), x(0.80), y(0.58), x(0.87), y(0.53))
          ..cubicTo(x(0.95), y(0.47), x(0.88), y(0.12), x(0.49), y(0.12));
        canvas.drawPath(path, paint);
        for (final point in [
          const Offset(0.34, 0.33),
          const Offset(0.58, 0.30),
          const Offset(0.31, 0.58),
        ]) {
          canvas.drawCircle(Offset(x(point.dx), y(point.dy)), x(0.055), fill);
        }
      case IosGlyph.creditCard:
        final card = RRect.fromRectAndRadius(
          Rect.fromLTWH(x(0.14), y(0.25), x(0.72), y(0.50)),
          Radius.circular(x(0.08)),
        );
        canvas.drawRRect(card, paint);
        canvas.drawLine(
          Offset(x(0.14), y(0.42)),
          Offset(x(0.86), y(0.42)),
          paint,
        );
        canvas.drawLine(
          Offset(x(0.25), y(0.62)),
          Offset(x(0.45), y(0.62)),
          paint,
        );
      case IosGlyph.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? x(0.40) : x(0.17);
          final point = Offset(
            x(0.50) + math.cos(angle) * radius,
            y(0.52) + math.sin(angle) * radius,
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IosGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.store});

  final LabStore store;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController(text: demoLoginEmail);
  final passwordController = TextEditingController(text: demoLoginPassword);
  String? errorText;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithDemoAccount() async {
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;
    if (email != demoLoginEmail || password != demoLoginPassword) {
      setState(() => errorText = '邮箱或密码不正确，请使用页面上的演示账号。');
      return;
    }
    setState(() => errorText = null);
    await widget.store.signIn(
      demoLoginName,
      demoLoginEmail,
      labName: demoLoginLabName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.science, color: _teal, size: 52),
              const SizedBox(height: 18),
              Text(
                'LabBuddy',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '本地优先的湿实验工作台助手',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: '演示邮箱',
                          helperText: demoLoginEmail,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: '演示密码',
                          helperText: demoLoginPassword,
                        ),
                        obscureText: true,
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _signInWithDemoAccount,
                          icon: const Icon(Icons.login),
                          label: const Text('使用演示账号进入'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const InfoPanel(
                icon: Icons.lock_outline,
                title: '本地模式',
                body: 'Android 版本先保持与 iOS v1 一致：无云同步、无账号服务、无 AI 依赖，数据存储在本机。',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.store});

  final LabStore store;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DayMode mode = DayMode.today;
  String? selectedProjectId;
  late DateTime selectedFutureDate = DateTime.now().add(
    const Duration(days: 1),
  );

  @override
  Widget build(BuildContext context) {
    final allRuns = switch (mode) {
      DayMode.past => widget.store.pastRuns,
      DayMode.today => widget.store.todayRuns,
      DayMode.tomorrow => widget.store.futureRunsForDate(selectedFutureDate),
    };
    final projectOptions = widget.store.projects;
    if (selectedProjectId != null &&
        !projectOptions.any((project) => project.id == selectedProjectId)) {
      selectedProjectId = null;
    }
    final runs = selectedProjectId == null
        ? allRuns
        : allRuns.where((run) => run.projectId == selectedProjectId).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, _iosTopOffset, 16, 10),
              child: IosDaySegmentedControl(
                selected: mode,
                onChanged: (value) => setState(() {
                  mode = value;
                  selectedProjectId = null;
                }),
              ),
            ),
            if (projectOptions.isNotEmpty)
              ProjectFilterStrip(
                projects: projectOptions,
                selectedProjectId: selectedProjectId,
                onSelected: (value) =>
                    setState(() => selectedProjectId = value),
              ),
            ActiveTimerStrip(store: widget.store),
            Expanded(
              child: mode == DayMode.past
                  ? PastRecordsCalendarView(
                      runs: allRuns,
                      store: widget.store,
                      projects: widget.store.projects,
                      selectedProjectId: selectedProjectId,
                      showDataCard: (run) => _showDataCard(context, run),
                    )
                  : mode == DayMode.tomorrow
                  ? FuturePlanCalendarView(
                      runs: allRuns,
                      allFutureRuns: widget.store.tomorrowRuns,
                      store: widget.store,
                      projects: widget.store.projects,
                      selectedDate: selectedFutureDate,
                      selectedProjectId: selectedProjectId,
                      onDateSelected: (date) =>
                          setState(() => selectedFutureDate = _dayStart(date)),
                      addRun: () => _showRunEditor(
                        context,
                        DayMode.tomorrow,
                        date: selectedFutureDate,
                      ),
                      openBench: (run) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BenchModeScreen(
                            store: widget.store,
                            run: run,
                            readonly: false,
                          ),
                        ),
                      ),
                      showDataCard: (run) => _showDataCard(context, run),
                      deleteRun: (run) => widget.store.deleteRun(
                        run.id,
                        DayMode.tomorrow,
                        date: selectedFutureDate,
                      ),
                    )
                  : runs.isEmpty
                  ? TodayEmptyState(
                      mode: mode,
                      addRun: () => _showRunEditor(context, mode),
                    )
                  : LabTimelineView(
                      runs: runs,
                      store: widget.store,
                      mode: mode,
                      addRun: () => _showRunEditor(context, mode),
                      endDay: widget.store.todayRuns.isEmpty
                          ? null
                          : () => _confirmEndDay(context),
                      openBench: (run) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BenchModeScreen(
                            store: widget.store,
                            run: run,
                            readonly: mode == DayMode.past,
                          ),
                        ),
                      ),
                      showDataCard: (run) => _showDataCard(context, run),
                      deleteRun: mode == DayMode.past
                          ? null
                          : (run) => widget.store.deleteRun(run.id, mode),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEndDay(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束今日实验？'),
        content: const Text('今天的计划会归档到过去，明天的计划会移动到今天。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.endDay();
    }
  }

  Future<void> _showRunEditor(
    BuildContext context,
    DayMode target, {
    DateTime? date,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          RunEditorSheet(store: widget.store, target: target, date: date),
    );
  }

  Future<void> _showDataCard(BuildContext context, LabRun run) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DataCardSheet(run: run, store: widget.store),
    );
  }
}

class LabTimelineView extends StatefulWidget {
  const LabTimelineView({
    super.key,
    required this.runs,
    required this.store,
    required this.mode,
    required this.addRun,
    required this.endDay,
    required this.openBench,
    required this.showDataCard,
    required this.deleteRun,
  });

  final List<LabRun> runs;
  final LabStore store;
  final DayMode mode;
  final VoidCallback addRun;
  final VoidCallback? endDay;
  final ValueChanged<LabRun> openBench;
  final ValueChanged<LabRun> showDataCard;
  final ValueChanged<LabRun>? deleteRun;

  @override
  State<LabTimelineView> createState() => _LabTimelineViewState();
}

class IosDaySegmentedControl extends StatelessWidget {
  const IosDaySegmentedControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DayMode selected;
  final ValueChanged<DayMode> onChanged;

  static const _items = [
    (DayMode.past, '过去'),
    (DayMode.today, '今天'),
    (DayMode.tomorrow, '明天'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E8E7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: _items.map((item) {
          final mode = item.$1;
          final label = item.$2;
          final active = mode == selected;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ProjectFilterStrip extends StatelessWidget {
  const ProjectFilterStrip({
    super.key,
    required this.projects,
    required this.selectedProjectId,
    required this.onSelected,
  });

  final List<LabProject> projects;
  final String? selectedProjectId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        scrollDirection: Axis.horizontal,
        children: [
          _FilterPill(
            label: '全部',
            selected: selectedProjectId == null,
            color: _teal,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...projects.expand(
            (project) => [
              _FilterPill(
                label: project.name,
                selected: selectedProjectId == project.id,
                color: project.color,
                onTap: () => onSelected(project.id),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : _labPanel,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class TodayEmptyState extends StatelessWidget {
  const TodayEmptyState({super.key, required this.mode, required this.addRun});

  final DayMode mode;
  final VoidCallback? addRun;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      DayMode.past => '暂无归档记录',
      DayMode.today => '今天还没有安排实验',
      DayMode.tomorrow => '明天还没有计划',
    };
    final body = switch (mode) {
      DayMode.past => '结束一天后，今日实验会归档到这里。',
      DayMode.today => '点击左上角 + 添加今天的实验计划',
      DayMode.tomorrow => '提前规划明天的实验安排',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Card(
        child: Column(
          children: [
            if (addRun != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '添加实验',
                      onPressed: addRun,
                      icon: const Icon(Icons.add_circle, color: _teal),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: EmptyState(
                icon: mode == DayMode.past
                    ? Icons.calendar_month
                    : Icons.calendar_month_outlined,
                title: title,
                body: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PastRecordsCalendarView extends StatefulWidget {
  const PastRecordsCalendarView({
    super.key,
    required this.runs,
    required this.store,
    required this.projects,
    required this.selectedProjectId,
    required this.showDataCard,
  });

  final List<LabRun> runs;
  final LabStore store;
  final List<LabProject> projects;
  final String? selectedProjectId;
  final ValueChanged<LabRun> showDataCard;

  @override
  State<PastRecordsCalendarView> createState() =>
      _PastRecordsCalendarViewState();
}

class FuturePlanCalendarView extends StatefulWidget {
  const FuturePlanCalendarView({
    super.key,
    required this.runs,
    required this.allFutureRuns,
    required this.store,
    required this.projects,
    required this.selectedDate,
    required this.selectedProjectId,
    required this.onDateSelected,
    required this.addRun,
    required this.openBench,
    required this.showDataCard,
    required this.deleteRun,
  });

  final List<LabRun> runs;
  final List<LabRun> allFutureRuns;
  final LabStore store;
  final List<LabProject> projects;
  final DateTime selectedDate;
  final String? selectedProjectId;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback addRun;
  final ValueChanged<LabRun> openBench;
  final ValueChanged<LabRun> showDataCard;
  final ValueChanged<LabRun> deleteRun;

  @override
  State<FuturePlanCalendarView> createState() => _FuturePlanCalendarViewState();
}

class _FuturePlanCalendarViewState extends State<FuturePlanCalendarView> {
  late DateTime displayMonth = _monthStart(widget.selectedDate);

  List<PastDayRecord> _recordsWhere(bool Function(LabRun run) include) {
    final buckets = <String, List<LabRun>>{};
    for (final run in widget.allFutureRuns) {
      if (!include(run)) continue;
      final key =
          run.planDateKey ??
          _dayKey(DateTime.now().add(const Duration(days: 1)));
      buckets.putIfAbsent(key, () => []).add(run);
    }
    return buckets.entries
        .map((entry) => PastDayRecord.fromRuns(entry.key, entry.value))
        .toList();
  }

  Map<String, PastDayRecord> get recordIndex => {
    for (final record in _recordsWhere((_) => true)) record.key: record,
  };

  Map<String, PastDayRecord> get selectableRecordIndex {
    final selectedProjectId = widget.selectedProjectId;
    if (selectedProjectId == null) return recordIndex;
    return {
      for (final record in _recordsWhere(
        (run) => _runMatchesProject(run, selectedProjectId, widget.projects),
      ))
        record.key: record,
    };
  }

  @override
  void didUpdateWidget(covariant FuturePlanCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      displayMonth = _monthStart(widget.selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRuns = widget.selectedProjectId == null
        ? widget.runs
        : widget.runs
              .where(
                (run) => _runMatchesProject(
                  run,
                  widget.selectedProjectId!,
                  widget.projects,
                ),
              )
              .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scheduleHeight = selectedRuns.isEmpty
            ? math.max(260.0, constraints.maxHeight * 0.42)
            : math.max(520.0, constraints.maxHeight * 0.72);
        return ListView(
          padding: const EdgeInsets.only(bottom: 104),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: PastCalendarCard(
                displayMonth: displayMonth,
                records: recordIndex,
                selectableRecords: selectableRecordIndex,
                selectedDayKey: _dayKey(widget.selectedDate),
                projects: widget.projects,
                selectedProjectId: widget.selectedProjectId,
                allowFutureMonths: true,
                allowEmptySelection: true,
                firstSelectableDate: _dayStart(DateTime.now()),
                footerText: '选择未来日期，提前安排实验计划',
                onMonthChanged: (month) => setState(() => displayMonth = month),
                onDaySelected: (key) =>
                    widget.onDateSelected(_dateFromDayKey(key)),
              ),
            ),
            SizedBox(
              height: scheduleHeight,
              child: selectedRuns.isEmpty
                  ? TodayEmptyState(
                      mode: DayMode.tomorrow,
                      addRun: widget.addRun,
                    )
                  : LabTimelineView(
                      runs: selectedRuns,
                      store: widget.store,
                      mode: DayMode.tomorrow,
                      addRun: widget.addRun,
                      endDay: null,
                      openBench: widget.openBench,
                      showDataCard: widget.showDataCard,
                      deleteRun: widget.deleteRun,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PastRecordsCalendarViewState extends State<PastRecordsCalendarView> {
  late DateTime displayMonth = _monthStart(DateTime.now());
  String? selectedDayKey;

  List<PastDayRecord> _dayRecordsWhere(bool Function(LabRun run) include) {
    final buckets = <String, List<LabRun>>{};
    for (var i = 0; i < widget.runs.length; i++) {
      final run = widget.runs[i];
      if (!include(run)) continue;
      final key = _pastRunDayKey(run, i);
      buckets.putIfAbsent(key, () => []).add(run);
    }
    final records =
        buckets.entries
            .map((entry) => PastDayRecord.fromRuns(entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  List<PastDayRecord> get dayRecords => _dayRecordsWhere((_) => true);

  List<PastDayRecord> get selectableDayRecords {
    final selectedProjectId = widget.selectedProjectId;
    if (selectedProjectId == null) return dayRecords;
    return _dayRecordsWhere(
      (run) => _runMatchesProject(run, selectedProjectId, widget.projects),
    );
  }

  Map<String, PastDayRecord> get recordIndex => {
    for (final record in dayRecords) record.key: record,
  };

  Map<String, PastDayRecord> get selectableRecordIndex => {
    for (final record in selectableDayRecords) record.key: record,
  };

  PastDayRecord? get selectedRecord {
    final allRecords = dayRecords;
    if (allRecords.isEmpty) return null;
    final selectableRecords = selectableDayRecords;
    final current = selectedDayKey;
    if (current != null && selectableRecordIndex.containsKey(current)) {
      return selectableRecordIndex[current];
    }
    if (selectableRecords.isNotEmpty) return selectableRecords.first;
    if (current != null && recordIndex.containsKey(current)) {
      return recordIndex[current];
    }
    return allRecords.first;
  }

  @override
  void didUpdateWidget(covariant PastRecordsCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProjectId != widget.selectedProjectId ||
        oldWidget.runs.length != widget.runs.length) {
      _syncSelection();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSelection());
  }

  void _syncSelection() {
    final record = selectedRecord;
    if (!mounted || record == null) return;
    setState(() {
      selectedDayKey = record.key;
      displayMonth = _monthStart(record.date);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.runs.isEmpty) {
      return TodayEmptyState(mode: DayMode.past, addRun: null);
    }
    final selected = selectedRecord;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      children: [
        PastCalendarCard(
          displayMonth: displayMonth,
          records: recordIndex,
          selectableRecords: selectableRecordIndex,
          selectedDayKey: selected?.key,
          projects: widget.projects,
          selectedProjectId: widget.selectedProjectId,
          onMonthChanged: (month) => setState(() => displayMonth = month),
          onDaySelected: (key) => setState(() => selectedDayKey = key),
        ),
        const SizedBox(height: 14),
        PastDayDetailCard(
          record: selected,
          store: widget.store,
          selectedProjectId: widget.selectedProjectId,
          showDataCard: widget.showDataCard,
        ),
      ],
    );
  }
}

class PastCalendarCard extends StatefulWidget {
  const PastCalendarCard({
    super.key,
    required this.displayMonth,
    required this.records,
    required this.selectableRecords,
    required this.selectedDayKey,
    required this.projects,
    required this.selectedProjectId,
    required this.onMonthChanged,
    required this.onDaySelected,
    this.allowFutureMonths = false,
    this.allowEmptySelection = false,
    this.firstSelectableDate,
    this.footerText = '双指缩放可调整大小',
  });

  final DateTime displayMonth;
  final Map<String, PastDayRecord> records;
  final Map<String, PastDayRecord> selectableRecords;
  final String? selectedDayKey;
  final List<LabProject> projects;
  final String? selectedProjectId;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<String> onDaySelected;
  final bool allowFutureMonths;
  final bool allowEmptySelection;
  final DateTime? firstSelectableDate;
  final String footerText;

  @override
  State<PastCalendarCard> createState() => _PastCalendarCardState();
}

class _PastCalendarCardState extends State<PastCalendarCard> {
  double cellScale = 1.0;
  double lastScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final monthDays = _calendarGridDays(widget.displayMonth);
    final nextMonth = _monthStart(
      DateTime(widget.displayMonth.year, widget.displayMonth.month + 1),
    );
    final canForward =
        widget.allowFutureMonths ||
        !nextMonth.isAfter(_monthStart(DateTime.now()));
    return GestureDetector(
      onScaleUpdate: (details) {
        final next = (lastScale * details.scale).clamp(0.6, 1.6);
        if (next != cellScale) setState(() => cellScale = next);
      },
      onScaleEnd: (_) => lastScale = cellScale,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CalendarNavButton(
                    reverse: true,
                    enabled: true,
                    onTap: () => widget.onMonthChanged(
                      _monthStart(
                        DateTime(
                          widget.displayMonth.year,
                          widget.displayMonth.month - 1,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.displayMonth.year}年${widget.displayMonth.month}月',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _CalendarNavButton(
                    reverse: false,
                    enabled: canForward,
                    onTap: () => widget.onMonthChanged(nextMonth),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: const ['一', '二', '三', '四', '五', '六', '日']
                    .map(
                      (label) => Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 5),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: monthDays.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.18 / cellScale,
                ),
                itemBuilder: (context, index) {
                  final day = monthDays[index];
                  if (day == null) return const SizedBox.shrink();
                  final key = _dayKey(day);
                  final isBeforeFirst =
                      widget.firstSelectableDate != null &&
                      _dayStart(
                        day,
                      ).isBefore(_dayStart(widget.firstSelectableDate!));
                  final canSelect =
                      !isBeforeFirst &&
                      (widget.allowEmptySelection ||
                          widget.selectableRecords[key] != null);
                  return PastCalendarCell(
                    date: day,
                    record: widget.records[key],
                    selectableRecord: widget.selectableRecords[key],
                    selected: key == widget.selectedDayKey,
                    projects: widget.projects,
                    selectedProjectId: widget.selectedProjectId,
                    cellScale: cellScale,
                    onTap: canSelect ? () => widget.onDaySelected(key) : null,
                  );
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  widget.footerText,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({
    required this.reverse,
    required this.enabled,
    required this.onTap,
  });

  final bool reverse;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 22,
      child: SizedBox.square(
        dimension: 36,
        child: Center(
          child: Transform.rotate(
            angle: reverse ? math.pi : 0,
            child: IosGlyphIcon(
              IosGlyph.chevronRight,
              color: enabled ? _teal : _muted.withValues(alpha: 0.25),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class PastCalendarCell extends StatelessWidget {
  const PastCalendarCell({
    super.key,
    required this.date,
    required this.record,
    required this.selectableRecord,
    required this.selected,
    required this.projects,
    required this.selectedProjectId,
    required this.cellScale,
    required this.onTap,
  });

  final DateTime date;
  final PastDayRecord? record;
  final PastDayRecord? selectableRecord;
  final bool selected;
  final List<LabProject> projects;
  final String? selectedProjectId;
  final double cellScale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final today = _isSameDay(date, DateTime.now());
    final isSelectable = selectableRecord != null;
    final projectColorRuns = selectedProjectId == null
        ? record?.runs ?? const <LabRun>[]
        : selectableRecord?.runs ?? const <LabRun>[];
    final projectColors = _projectColors(projectColorRuns, projects).take(3);
    final activeColor = selectedProjectId == null
        ? _teal
        : projects
                  .where((project) => project.id == selectedProjectId)
                  .firstOrNull
                  ?.color ??
              _teal;
    final hasRecord = record != null;
    final shouldLightDate = hasRecord && isSelectable;
    final inactiveRecordOpacity = selectedProjectId == null ? 0.35 : 0.16;
    final visibleDots = projectColors.isEmpty && shouldLightDate
        ? [activeColor]
        : projectColors.toList();
    final textColor = selected
        ? Colors.white
        : today || shouldLightDate
        ? activeColor
        : hasRecord
        ? _muted.withValues(alpha: inactiveRecordOpacity)
        : _muted.withValues(alpha: 0.30);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: hasRecord || today ? _labInset.withValues(alpha: 0.72) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.42)
                : shouldLightDate
                ? activeColor.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 27,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: today || shouldLightDate || selected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (shouldLightDate)
              SizedBox(
                height: cellScale > 0.75 ? 6 : 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: cellScale > 0.75
                      ? visibleDots
                            .map(
                              (color) => Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.2,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.92)
                                      : color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                            .toList()
                      : [
                          Container(
                            width: 16,
                            height: 2,
                            decoration: BoxDecoration(
                              color: (selected ? Colors.white : activeColor)
                                  .withValues(alpha: 0.70),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                ),
              )
            else
              Container(
                width: today ? 16 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: today ? 0.70 : 0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PastDayDetailCard extends StatelessWidget {
  const PastDayDetailCard({
    super.key,
    required this.record,
    required this.store,
    required this.selectedProjectId,
    required this.showDataCard,
  });

  final PastDayRecord? record;
  final LabStore store;
  final String? selectedProjectId;
  final ValueChanged<LabRun> showDataCard;

  @override
  Widget build(BuildContext context) {
    final day = record;
    final project = selectedProjectId == null
        ? null
        : store.projects
              .where((item) => item.id == selectedProjectId)
              .firstOrNull;
    final rawRuns = day?.runs ?? const <LabRun>[];
    final runs = selectedProjectId == null
        ? rawRuns
        : rawRuns
              .where(
                (run) =>
                    _runMatchesProject(run, selectedProjectId!, store.projects),
              )
              .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day == null
                            ? '过去'
                            : project == null
                            ? day.dateLabel
                            : '${day.dateLabel} · ${project.name}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        day == null
                            ? '还没有归档实验'
                            : project == null
                            ? day.summary
                            : '${project.name} · ${runs.length} 个实验',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  day?.weekday ?? '',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (runs.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _labInset,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedProjectId == null ? '这一天还没有实验记录' : '这一天没有该项目实验',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (selectedProjectId != null) ...const [
                      SizedBox(height: 5),
                      Text(
                        '切换到「全部」可查看当天其他项目。',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              ...runs.map(
                (run) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: PastRunSummaryTile(
                    run: run,
                    project: store.projectFor(run.projectId),
                    openDetail: () => _showPastRunDetail(
                      context,
                      run,
                      store.projectFor(run.projectId),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPastRunDetail(
    BuildContext context,
    LabRun run,
    LabProject? project,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PastRunDetailSheet(
        run: run,
        project: project,
        showDataCard: () => showDataCard(run),
      ),
    );
  }
}

class PastRunSummaryTile extends StatelessWidget {
  const PastRunSummaryTile({
    super.key,
    required this.run,
    required this.project,
    required this.openDetail,
  });

  final LabRun run;
  final LabProject? project;
  final VoidCallback openDetail;

  @override
  Widget build(BuildContext context) {
    final accent = _runAccentColor(run, project);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: openDetail,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  run.timeLabel,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${run.area} · ${run.completedCount}/${run.steps.length} 步',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Center(
                child: IosGlyphIcon(
                  IosGlyph.chevronRight,
                  color: _muted.withValues(alpha: 0.50),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PastRunDetailSheet extends StatelessWidget {
  const PastRunDetailSheet({
    super.key,
    required this.run,
    required this.project,
    required this.showDataCard,
  });

  final LabRun run;
  final LabProject? project;
  final VoidCallback showDataCard;

  @override
  Widget build(BuildContext context) {
    final accent = _runAccentColor(run, project);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 14, 18, bottom + 18),
        child: Column(
          children: [
            Row(
              children: [
                _CircleIconButton(
                  icon: Icons.close,
                  tooltip: '关闭',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Text(
                  '实验记录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                _CircleIconButton(
                  icon: Icons.ios_share,
                  tooltip: '生成 Data Card',
                  onTap: showDataCard,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 5,
                          height: 58,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                run.title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      height: 1.08,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${run.area} · ${run.timeLabel}',
                                style: const TextStyle(color: _muted),
                              ),
                              if (project != null)
                                Text(
                                  project!.name,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                run.scaledVolumeLabel,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _labPanel,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '实验步骤',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        for (var i = 0; i < run.steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PastRunStepRow(
                              index: i,
                              step: run.steps[i],
                              accent: accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastRunStepRow extends StatelessWidget {
  const _PastRunStepRow({
    required this.index,
    required this.step,
    required this.accent,
  });

  final int index;
  final LabStep step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  step.detail,
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
                if (step.durationMinutes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${step.durationMinutes} min',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PastDayRecord {
  const PastDayRecord({
    required this.key,
    required this.date,
    required this.runs,
  });

  final String key;
  final DateTime date;
  final List<LabRun> runs;

  String get dateLabel => '${date.month}月${date.day}日';

  String get weekday =>
      const ['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1];

  String get summary =>
      '${runs.length} 个实验 · ${runs.fold<int>(0, (sum, run) => sum + run.steps.length)} 步';

  static PastDayRecord fromRuns(String key, List<LabRun> runs) {
    return PastDayRecord(key: key, date: _dateFromDayKey(key), runs: runs);
  }
}

class _LabTimelineViewState extends State<LabTimelineView> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final sortedRuns = [...widget.runs]
      ..sort((a, b) => a.timeLabel.compareTo(b.timeLabel));
    final groups = _timelineGroups(sortedRuns);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '添加实验',
                    onPressed: widget.addRun,
                    icon: const Icon(Icons.add_circle, color: _teal, size: 25),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => focused = !focused),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            focused
                                ? Icons.fullscreen_exit
                                : Icons.open_in_full,
                            color: _teal,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            focused ? '全天览' : '聚焦当前',
                            style: const TextStyle(
                              color: _teal,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 82),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  if (group.runs.isEmpty) {
                    return CollapsedTimelineSegment(
                      startHour: group.startHour,
                      endHour: group.endHour,
                    );
                  }
                  return TimelineHourBlock(
                    hour: group.startHour,
                    runs: group.runs,
                    store: widget.store,
                    overview: !focused,
                    compactCards: widget.store.preferences.compactCards,
                    readonly: widget.mode == DayMode.past,
                    openBench: widget.openBench,
                    showDataCard: widget.showDataCard,
                    editSteps: _editRunDetail,
                    startStepTimer: _startNextStepTimer,
                    deleteRun: widget.deleteRun,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editRunDetail(LabRun run) async {
    if (widget.mode == DayMode.past) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RunDetailEditorSheet(
        store: widget.store,
        run: run,
        onDataCard: () => widget.showDataCard(run),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _startNextStepTimer(LabRun run) async {
    if (widget.mode == DayMode.past) return;
    final step =
        run.steps.where((item) => !item.done).firstOrNull ??
        run.steps.firstOrNull;
    if (step == null) return;
    final seconds = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomTimerStartSheet(step: step),
    );
    if (seconds == null) return;
    await widget.store.startTimer(run, step, customSeconds: seconds);
    if (mounted) setState(() {});
  }

  List<_TimelineGroup> _timelineGroups(List<LabRun> runs) {
    final byHour = <int, List<LabRun>>{};
    for (var hour = 0; hour <= 23; hour++) {
      final hourRuns = runs.where((run) => _runCoversHour(run, hour)).toList()
        ..sort(
          (a, b) => _minuteFromLabel(
            a.timeLabel,
          ).compareTo(_minuteFromLabel(b.timeLabel)),
        );
      if (hourRuns.isNotEmpty) {
        byHour[hour] = hourRuns;
      }
    }
    final activeHours = byHour.keys.toList()..sort();
    if (activeHours.isEmpty) return [];
    final groups = <_TimelineGroup>[];
    final first = activeHours.first;
    final last = activeHours.last;
    if (first > 0) groups.add(_TimelineGroup.empty(0, first - 1));
    for (var hour = first; hour <= last; hour++) {
      final hourRuns = byHour[hour] ?? [];
      if (hourRuns.isEmpty) {
        final start = hour;
        while (hour + 1 <= last && (byHour[hour + 1] ?? []).isEmpty) {
          hour++;
        }
        groups.add(_TimelineGroup.empty(start, hour));
      } else {
        groups.add(_TimelineGroup(hour, hour, hourRuns));
      }
    }
    if (last < 23) groups.add(_TimelineGroup.empty(last + 1, 23));
    return groups;
  }
}

class _TimelineGroup {
  const _TimelineGroup(this.startHour, this.endHour, this.runs);
  const _TimelineGroup.empty(this.startHour, this.endHour) : runs = const [];

  final int startHour;
  final int endHour;
  final List<LabRun> runs;
}

class TimelineHourBlock extends StatelessWidget {
  const TimelineHourBlock({
    super.key,
    required this.hour,
    required this.runs,
    required this.store,
    required this.overview,
    required this.compactCards,
    required this.readonly,
    required this.openBench,
    required this.showDataCard,
    required this.editSteps,
    required this.startStepTimer,
    required this.deleteRun,
  });

  final int hour;
  final List<LabRun> runs;
  final LabStore store;
  final bool overview;
  final bool compactCards;
  final bool readonly;
  final ValueChanged<LabRun> openBench;
  final ValueChanged<LabRun> showDataCard;
  final ValueChanged<LabRun> editSteps;
  final ValueChanged<LabRun> startStepTimer;
  final ValueChanged<LabRun>? deleteRun;

  @override
  Widget build(BuildContext context) {
    const currentHour = 11;
    final isCurrent = hour == currentHour;
    final sortedRuns = [...runs]
      ..sort(
        (a, b) => _minuteFromLabel(
          a.timeLabel,
        ).compareTo(_minuteFromLabel(b.timeLabel)),
      );
    final eventAreaHeight = _hourEventAreaHeight(
      hour,
      sortedRuns,
      overview,
      compactCards,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TimelineTimeRule(
          label: '${hour.toString().padLeft(2, '0')}:00',
          active: isCurrent,
        ),
        if (sortedRuns.isEmpty)
          SizedBox(height: overview ? 18 : 32)
        else
          Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 8, right: 8),
            child: SizedBox(
              height: eventAreaHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: sortedRuns.map((run) {
                  final layout = _eventLayoutForHour(
                    hour,
                    run,
                    overview,
                    compactCards,
                  );
                  return Positioned(
                    left: 0,
                    right: 0,
                    top: layout.y,
                    height: layout.height,
                    child: TimelineRunEvent(
                      run: run,
                      project: store.projectFor(run.projectId),
                      activeTimer: store.timers
                          .where((timer) => timer.runId == run.id)
                          .firstOrNull,
                      overview: overview,
                      compactCards: compactCards,
                      readonly: readonly,
                      openBench: () => openBench(run),
                      showDataCard: () => showDataCard(run),
                      editSteps: () => editSteps(run),
                      startStepTimer: () => startStepTimer(run),
                      deleteRun: deleteRun == null
                          ? null
                          : () => deleteRun!(run),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        if (isCurrent) const CurrentTimeIndicatorInHour(label: ':31'),
      ],
    );
  }
}

class TimelineRunEvent extends StatelessWidget {
  const TimelineRunEvent({
    super.key,
    required this.run,
    required this.project,
    required this.activeTimer,
    required this.overview,
    required this.compactCards,
    required this.readonly,
    required this.openBench,
    required this.showDataCard,
    required this.editSteps,
    required this.startStepTimer,
    required this.deleteRun,
  });

  final LabRun run;
  final LabProject? project;
  final LabTimer? activeTimer;
  final bool overview;
  final bool compactCards;
  final bool readonly;
  final VoidCallback openBench;
  final VoidCallback showDataCard;
  final VoidCallback editSteps;
  final VoidCallback startStepTimer;
  final VoidCallback? deleteRun;

  @override
  Widget build(BuildContext context) {
    final accent = _runAccentColor(run, project);
    if (overview) {
      final card = InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: openBench,
        onLongPress: showDataCard,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_runTimeRangeLabel(run)} · ${run.completedCount}/${run.steps.length}步',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      run.area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (project != null) ...[
                    const SizedBox(height: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 76),
                      child: Text(
                        project!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: _projectTextColor(run, project!),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  if (activeTimer != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      activeTimer!.remainingLabel,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (!readonly && activeTimer == null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: editSteps,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.edit_note, color: _teal, size: 14),
                                SizedBox(width: 2),
                                Text(
                                  '步骤',
                                  style: TextStyle(
                                    color: _teal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: startStepTimer,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.timer_outlined,
                                  color: Colors.orange,
                                  size: 14,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Timer',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(left: 62, right: 8),
        child: deleteRun == null
            ? card
            : IosSwipeDelete(
                key: ValueKey('run-${run.id}'),
                confirmTitle: '删除实验？',
                confirmMessage: '删除「${run.title}」后，这条实验记录会从当前列表中移除。',
                onDelete: () async => deleteRun!(),
                child: card,
              ),
      );
    }

    final detailCard = Container(
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(compactCards ? 8 : 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              run.timeLabel,
                              style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              run.title,
                              maxLines: compactCards ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: compactCards ? 15 : 17,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${run.area} · ${run.protocolName}',
                              maxLines: compactCards ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!compactCards) ...[
                    const SizedBox(height: 7),
                    Text(
                      run.scaledVolumeLabel,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ...run.steps
                        .take(3)
                        .map(
                          (step) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: TimelineStepRow(step: step),
                          ),
                        ),
                  ],
                  SizedBox(height: compactCards ? 5 : 8),
                  Row(
                    children: [
                      Text(
                        '${run.completedCount}/${run.steps.length} 步',
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (activeTimer != null) ...[
                        const SizedBox(width: 8),
                        ChipLabel(
                          text: activeTimer!.isPaused
                              ? '暂停 ${activeTimer!.remainingLabel}'
                              : activeTimer!.remainingLabel,
                          color: Colors.orange,
                        ),
                      ],
                      const Spacer(),
                      if (!readonly) ...[
                        SizedBox(
                          height: compactCards ? 32 : 38,
                          child: OutlinedButton.icon(
                            onPressed: editSteps,
                            icon: const Icon(Icons.edit_note, size: 17),
                            label: const Text('步骤'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: compactCards ? 5 : 7),
                        SizedBox(
                          height: compactCards ? 32 : 38,
                          child: OutlinedButton.icon(
                            onPressed: startStepTimer,
                            icon: const Icon(Icons.timer_outlined, size: 17),
                            label: const Text('Timer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: compactCards ? 6 : 8),
                      ],
                      SizedBox(
                        width: compactCards ? 34 : 44,
                        height: compactCards ? 32 : 40,
                        child: IconButton.filledTonal(
                          tooltip: 'Data Card',
                          onPressed: showDataCard,
                          iconSize: compactCards ? 18 : 22,
                          icon: const Icon(Icons.ios_share),
                        ),
                      ),
                      SizedBox(width: compactCards ? 6 : 8),
                      if (compactCards)
                        SizedBox(
                          width: 42,
                          height: 32,
                          child: IconButton.filled(
                            tooltip: readonly ? '查看' : '实验台',
                            onPressed: openBench,
                            iconSize: 18,
                            icon: const Icon(Icons.science),
                          ),
                        )
                      else
                        SizedBox(
                          height: 40,
                          child: FilledButton.icon(
                            onPressed: openBench,
                            icon: const Icon(Icons.science),
                            label: Text(readonly ? '查看' : '实验台'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(left: 54, right: 14, bottom: 8),
      child: deleteRun == null
          ? detailCard
          : IosSwipeDelete(
              key: ValueKey('run-${run.id}'),
              confirmTitle: '删除实验？',
              confirmMessage: '删除「${run.title}」后，这条实验记录会从当前列表中移除。',
              onDelete: () async => deleteRun!(),
              child: detailCard,
            ),
    );
  }
}

class TimelineStepRow extends StatelessWidget {
  const TimelineStepRow({super.key, required this.step});

  final LabStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            step.done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: step.done ? _teal : _muted,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: step.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (step.durationMinutes != null)
            Text(
              '${step.durationMinutes}m',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class TimelineTimeRule extends StatelessWidget {
  const TimelineTimeRule({
    super.key,
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tint = active ? _teal : _muted;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: tint.withValues(alpha: active ? 1 : 0.68),
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: active ? 6 : 4,
            height: active ? 6 : 4,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: active ? 0.70 : 0.28),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 1,
              color: tint.withValues(alpha: active ? 0.35 : 0.12),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class CurrentTimeIndicatorInHour extends StatelessWidget {
  const CurrentTimeIndicatorInHour({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFFF3B30),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              color: const Color(0xFFFF3B30).withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class CollapsedTimelineSegment extends StatelessWidget {
  const CollapsedTimelineSegment({
    super.key,
    required this.startHour,
    required this.endHour,
  });

  final int startHour;
  final int endHour;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              '${startHour.toString().padLeft(2, '0')}:00',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _muted.withValues(alpha: 0.45),
                fontSize: 10,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: _muted.withValues(alpha: 0.08),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '· · ·',
                    style: TextStyle(color: _muted.withValues(alpha: 0.30)),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: _muted.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${endHour.toString().padLeft(2, '0')}:00',
            style: TextStyle(
              color: _muted.withValues(alpha: 0.45),
              fontSize: 10,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

int _minuteFromLabel(String label) {
  final parts = label.split(':');
  if (parts.length != 2) return 0;
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = int.tryParse(parts.last) ?? 0;
  return (hour.clamp(0, 23) * 60 + minute.clamp(0, 59)).clamp(0, 1439);
}

int _scheduledMinutes(LabRun run) {
  if (run.id == 'cell-passage' ||
      run.id == 'lipo3000-transfection' ||
      run.id == 'mini-prep') {
    return 15;
  }
  final minutes = run.steps.fold<int>(
    0,
    (sum, step) => sum + (step.durationMinutes ?? 0),
  );
  if (minutes > 0) return math.max(minutes, 15);
  return run.steps.any((step) => step.carryOver) ? 120 : 30;
}

int _endMinuteOfDay(LabRun run) {
  return math.min(
    _minuteFromLabel(run.timeLabel) + _scheduledMinutes(run),
    24 * 60,
  );
}

bool _runCoversHour(LabRun run, int hour) {
  final hourStart = hour * 60;
  final hourEnd = math.min((hour + 1) * 60, 24 * 60);
  return _minuteFromLabel(run.timeLabel) < hourEnd &&
      _endMinuteOfDay(run) > hourStart;
}

DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

DateTime _dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _defaultTomorrowKey() =>
    _dayKey(DateTime.now().add(const Duration(days: 1)));

String _futureDateLabel(DateTime? date) {
  final target = date ?? DateTime.now().add(const Duration(days: 1));
  if (_dayKey(target) == _defaultTomorrowKey()) return '明天';
  return '${target.month}月${target.day}日';
}

DateTime _dateFromDayKey(String key) {
  final parts = key.split('-').map(int.tryParse).toList();
  if (parts.length == 3 && parts.every((part) => part != null)) {
    return DateTime(parts[0]!, parts[1]!, parts[2]!);
  }
  return DateTime.now();
}

String _pastRunDayKey(LabRun run, int fallbackIndex) {
  final match = RegExp(r'past-(\d{4}-\d{2}-\d{2})').firstMatch(run.id);
  if (match != null) return match.group(1)!;
  final fallback = DateTime.now().subtract(Duration(days: fallbackIndex + 1));
  return _dayKey(fallback);
}

List<DateTime?> _calendarGridDays(DateTime displayMonth) {
  final first = _monthStart(displayMonth);
  final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
  final leading = first.weekday - 1;
  final cells = <DateTime?>[
    for (var i = 0; i < leading; i++) null,
    for (var day = 1; day <= daysInMonth; day++)
      DateTime(first.year, first.month, day),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<Color> _projectColors(List<LabRun> runs, List<LabProject> projects) {
  final colors = <Color>[];
  final seen = <String>{};
  for (final run in runs) {
    final project = projects
        .where((item) => item.id == run.projectId || item.name == run.projectId)
        .firstOrNull;
    if (project == null || seen.contains(project.id)) continue;
    seen.add(project.id);
    colors.add(project.color);
  }
  return colors;
}

bool _runMatchesProject(
  LabRun run,
  String projectId,
  List<LabProject> projects,
) {
  if (run.projectId == projectId) return true;
  final project = projects.where((item) => item.id == projectId).firstOrNull;
  return project != null && run.projectId == project.name;
}

Color _runAccentColor(LabRun run, LabProject? project) {
  if (run.id == 'lipo3000-transfection') return const Color(0xFF5856D6);
  return _areaAccentColor(run.area, fallback: project?.color ?? _teal);
}

Color _areaAccentColor(String areaName, {Color fallback = _teal}) {
  final area = areaName.toLowerCase();
  if (area.contains('细胞')) return const Color(0xFFFF9500);
  if (area.contains('核酸') || area.contains('分子')) {
    return const Color(0xFF34C759);
  }
  if (area.contains('蛋白')) return const Color(0xFFFF2D55);
  if (area.contains('wb') || area.contains('跑胶')) {
    return const Color(0xFFFF9500);
  }
  if (area.contains('动物')) return const Color(0xFFAF52DE);
  return fallback;
}

Color _areaBadgeColor(String areaName, {Color fallback = _teal}) {
  final area = areaName.toLowerCase();
  if (area.contains('细胞')) return _teal;
  if (area.contains('蛋白') || area.contains('wb') || area.contains('跑胶')) {
    return const Color(0xFFFF2D55);
  }
  if (area.contains('核酸') || area.contains('分子')) {
    return const Color(0xFF34C759);
  }
  if (area.contains('动物')) return const Color(0xFFAF52DE);
  return fallback;
}

Color _projectTextColor(LabRun run, LabProject project) {
  if (run.id == 'lipo3000-transfection') return _teal;
  final area = run.area.toLowerCase();
  if (area.contains('细胞')) return _teal;
  if (area.contains('核酸') || area.contains('分子')) {
    return const Color(0xFF5856D6);
  }
  if (area.contains('wb') || area.contains('蛋白') || area.contains('跑胶')) {
    return const Color(0xFFFF9500);
  }
  return project.color;
}

String _runTimeRangeLabel(LabRun run) {
  final start = _minuteFromLabel(run.timeLabel);
  final end = math.min(start + _scheduledMinutes(run), 24 * 60 - 1);
  return '${run.timeLabel}-${(end ~/ 60).toString().padLeft(2, '0')}:${(end % 60).toString().padLeft(2, '0')}';
}

({double y, double height, double bottom}) _eventLayoutForHour(
  int hour,
  LabRun run,
  bool overview,
  bool compactCards,
) {
  final minuteHeight = overview ? 0.58 : 2.8;
  final startOffset = _minuteFromLabel(run.timeLabel) - hour * 60;
  final y = math.max(0, startOffset) * minuteHeight;
  final durationHeight = _scheduledMinutes(run) * minuteHeight;
  final overviewMinimum = compactCards ? 72.0 : 78.0;
  final focusedMinimum = math.max(210.0, run.steps.length * 42 + 112);
  final minimum = overview ? overviewMinimum : focusedMinimum;
  final height = math.max(durationHeight.toDouble(), minimum.toDouble());
  final startRuleHeight = startOffset == 0 ? 0.0 : 14.0;
  const endRuleHeight = 22.0;
  return (
    y: y.toDouble(),
    height: height.toDouble(),
    bottom: y + startRuleHeight + height + endRuleHeight,
  );
}

double _hourEventAreaHeight(
  int hour,
  List<LabRun> runs,
  bool overview,
  bool compactCards,
) {
  if (runs.isEmpty) return overview ? 24 : 32;
  final fallback = overview ? 82.0 : 160.0;
  return math.max(
    fallback,
    runs
        .map(
          (run) =>
              _eventLayoutForHour(hour, run, overview, compactCards).bottom,
        )
        .fold<double>(0, math.max),
  );
}

class ActiveTimerStrip extends StatelessWidget {
  const ActiveTimerStrip({super.key, required this.store});

  final LabStore store;

  @override
  Widget build(BuildContext context) {
    if (store.timers.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 74,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: store.timers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final timer = store.timers[index];
          return Card(
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: _teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timer.stepTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          timer.isPaused
                              ? '已暂停 · ${timer.remainingLabel}'
                              : timer.remainingLabel,
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: timer.isPaused ? '继续' : '暂停',
                    onPressed: () => timer.isPaused
                        ? store.resumeTimer(timer.id)
                        : store.pauseTimer(timer.id),
                    icon: Icon(timer.isPaused ? Icons.play_arrow : Icons.pause),
                  ),
                  IconButton(
                    tooltip: '停止',
                    onPressed: () => store.stopTimer(timer.id),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class LabRunCard extends StatelessWidget {
  const LabRunCard({
    super.key,
    required this.run,
    required this.project,
    required this.compact,
    required this.onBench,
    required this.onShare,
    required this.readonly,
    this.onDelete,
  });

  final LabRun run;
  final LabProject? project;
  final bool compact;
  final bool readonly;
  final VoidCallback onBench;
  final VoidCallback onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TimePill(label: run.timeLabel),
                SizedBox(width: compact ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        run.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: compact ? 15 : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChipLabel(text: run.area),
                          ChipLabel(text: run.status),
                          if (project != null)
                            ChipLabel(
                              text: project!.name,
                              color: project!.color,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: '删除',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(run.protocolName, style: const TextStyle(color: _muted)),
            if (!compact) ...[
              const SizedBox(height: 2),
              Text(run.scaledVolumeLabel),
            ],
            SizedBox(height: compact ? 8 : 12),
            IosProgressBar(
              value: run.steps.isEmpty
                  ? 0
                  : run.completedCount / run.steps.length,
              color: _teal,
              height: 6,
            ),
            SizedBox(height: compact ? 6 : 10),
            Row(
              children: [
                Text(
                  '${run.completedCount}/${run.steps.length} 步完成',
                  style: const TextStyle(color: _muted),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'Data Card',
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onBench,
                  icon: const Icon(Icons.science),
                  label: Text(readonly ? '查看' : '实验台'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BenchModeScreen extends StatefulWidget {
  const BenchModeScreen({
    super.key,
    required this.store,
    required this.run,
    required this.readonly,
  });

  final LabStore store;
  final LabRun run;
  final bool readonly;

  @override
  State<BenchModeScreen> createState() => _BenchModeScreenState();
}

class _BenchModeScreenState extends State<BenchModeScreen> {
  late LabRun run;
  bool fullMode = false;
  int stepIndex = 0;

  @override
  void initState() {
    super.initState();
    run = widget.store.runById(widget.run.id) ?? widget.run;
    final firstIncomplete = run.steps.indexWhere((step) => !step.done);
    stepIndex = firstIncomplete == -1
        ? math.max(0, run.steps.length - 1)
        : firstIncomplete;
  }

  Future<void> _completeCurrentStep() async {
    if (widget.readonly || run.steps.isEmpty) return;
    final step = run.steps[stepIndex.clamp(0, run.steps.length - 1).toInt()];
    if (!step.done) {
      await widget.store.toggleStep(run.id, step.id);
      run = widget.store.runById(run.id) ?? run;
    }
    final next = run.steps.indexWhere((item) => !item.done);
    setState(() {
      stepIndex = next == -1 ? math.max(0, run.steps.length - 1) : next;
    });
    if (next == -1 && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('实验完成'),
          content: const Text('所有步骤已完成，是否生成结果卡片？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后处理'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDataCard();
              },
              child: const Text('生成结果卡片'),
            ),
          ],
        ),
      );
    }
  }

  void _showDataCard() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DataCardSheet(run: run, store: widget.store),
    );
  }

  Future<void> _editRunSteps() async {
    if (widget.readonly) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RunStepEditorSheet(store: widget.store, run: run),
    );
    if (!mounted) return;
    setState(() {
      run = widget.store.runById(run.id) ?? run;
      stepIndex = stepIndex.clamp(0, math.max(0, run.steps.length - 1)).toInt();
    });
  }

  Future<void> _editRunStep(LabStep step) async {
    if (widget.readonly) return;
    final updated = await showModalBottomSheet<LabStep>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StepEditorSheet(step: step),
    );
    if (updated == null) return;
    await widget.store.updateRunStep(run.id, updated);
    if (!mounted) return;
    setState(() {
      run = widget.store.runById(run.id) ?? run;
      stepIndex = stepIndex.clamp(0, math.max(0, run.steps.length - 1)).toInt();
    });
  }

  Future<void> _deleteRunStep(LabStep step) async {
    if (widget.readonly) return;
    await widget.store.deleteRunStep(run.id, step.id);
    if (!mounted) return;
    setState(() {
      run = widget.store.runById(run.id) ?? run;
      stepIndex = stepIndex.clamp(0, math.max(0, run.steps.length - 1)).toInt();
    });
  }

  Future<void> _startCustomTimer(LabStep step) async {
    if (widget.readonly) return;
    final seconds = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomTimerStartSheet(step: step),
    );
    if (seconds == null) return;
    await widget.store.startTimer(run, step, customSeconds: seconds);
    if (mounted) setState(() => run = widget.store.runById(run.id) ?? run);
  }

  void _goToPreviousStep() {
    if (stepIndex == 0) return;
    setState(() => stepIndex -= 1);
  }

  void _goToNextStep() {
    if (stepIndex >= run.steps.length - 1) return;
    setState(() => stepIndex += 1);
  }

  void _handleStepSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -280) {
      _goToNextStep();
    } else if (velocity > 280) {
      _goToPreviousStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final largeBenchMode = widget.store.preferences.largeBenchMode;
    final showStepDuration = widget.store.preferences.showStepDuration;
    final activeIndex = stepIndex
        .clamp(0, math.max(0, run.steps.length - 1))
        .toInt();
    final progress = run.steps.isEmpty
        ? 0.0
        : run.completedCount / run.steps.length;
    if (run.steps.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.science,
            title: '没有实验步骤',
            body: '请先在 Protocol 中添加步骤。',
          ),
        ),
      );
    }
    final currentStep =
        run.steps[stepIndex.clamp(0, run.steps.length - 1).toInt()];
    final currentTimer = widget.store.timers
        .where((timer) => timer.id == '${run.id}-${currentStep.id}')
        .firstOrNull;
    if (fullMode) {
      return _BenchFullMode(
        run: run,
        stepIndex: stepIndex,
        currentStep: currentStep,
        timer: currentTimer,
        progress: progress,
        readonly: widget.readonly,
        onExitFull: () => setState(() => fullMode = false),
        onClose: () => Navigator.of(context).pop(),
        onDataCard: _showDataCard,
        onPrevious: stepIndex == 0 ? null : _goToPreviousStep,
        onNext: stepIndex >= run.steps.length - 1 ? null : _goToNextStep,
        onStepSelected: (index) => setState(() => stepIndex = index),
        onCompleteStep: _completeCurrentStep,
        onStartTimer: widget.readonly
            ? null
            : () => _startCustomTimer(currentStep),
        onPauseTimer: currentTimer == null || widget.readonly
            ? null
            : () {
                if (currentTimer.isPaused) {
                  widget.store.resumeTimer(currentTimer.id);
                } else {
                  widget.store.pauseTimer(currentTimer.id);
                }
              },
        onStopTimer: currentTimer == null || widget.readonly
            ? null
            : () {
                widget.store.stopTimer(currentTimer.id);
              },
      );
    }
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _handleStepSwipe,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          run.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${run.area} · ${run.timeLabel}',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  _BenchHeaderButton(
                    icon: Icons.fullscreen,
                    onTap: () => setState(() => fullMode = true),
                  ),
                  const SizedBox(width: 10),
                  _BenchHeaderButton(
                    icon: Icons.ios_share,
                    onTap: _showDataCard,
                  ),
                  const SizedBox(width: 10),
                  if (!widget.readonly) ...[
                    _BenchHeaderButton(
                      icon: Icons.tune,
                      tooltip: '编辑全部步骤',
                      onTap: _editRunSteps,
                    ),
                    const SizedBox(width: 10),
                  ],
                  _BenchHeaderButton(
                    icon: Icons.close,
                    filled: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              IosProgressBar(value: progress, trackColor: _line),
              const SizedBox(height: 22),
              Card(
                child: Column(
                  children: run.steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    final isActive = index == activeIndex;
                    final isDone = step.done;
                    final timer = widget.store.timers
                        .where((timer) => timer.id == '${run.id}-${step.id}')
                        .firstOrNull;
                    final row = Container(
                      decoration: BoxDecoration(
                        color: isActive ? _teal.withValues(alpha: 0.08) : null,
                        border: Border(
                          bottom: BorderSide(
                            color: index == run.steps.length - 1
                                ? Colors.transparent
                                : _line,
                          ),
                          left: BorderSide(
                            color: isActive ? _teal : Colors.transparent,
                            width: 4,
                          ),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        isActive ? 10 : 14,
                        16,
                        14,
                        16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 42,
                                child: _StepNumberBadge(
                                  index: index + 1,
                                  active: isActive,
                                  done: isDone,
                                  onTap: () =>
                                      setState(() => stepIndex = index),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.readonly
                                      ? () => setState(() => stepIndex = index)
                                      : () => _editRunStep(step),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: isDone
                                                  ? _muted.withValues(
                                                      alpha: 0.55,
                                                    )
                                                  : _ink,
                                              fontSize: largeBenchMode
                                                  ? 21
                                                  : null,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        step.detail,
                                        maxLines: isActive ? 5 : 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isActive
                                              ? _muted
                                              : _muted.withValues(alpha: 0.55),
                                          fontSize: largeBenchMode ? 17 : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (showStepDuration)
                                TextButton.icon(
                                  onPressed: widget.readonly
                                      ? null
                                      : () => _startCustomTimer(step),
                                  icon: const Icon(Icons.timer_outlined),
                                  label: Text(
                                    step.durationMinutes == null
                                        ? '计时'
                                        : '${step.durationMinutes}m',
                                  ),
                                ),
                              if (!widget.readonly)
                                IconButton(
                                  tooltip: '编辑此步骤',
                                  onPressed: () => _editRunStep(step),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                            ],
                          ),
                          if (step.reagents.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: step.reagents
                                  .map(
                                    (r) => ChipLabel(
                                      text: '${r.name} ${r.amount} ${r.unit}',
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (timer != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _labInset,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    timer.isPaused
                                        ? Icons.pause_circle
                                        : Icons.timer,
                                    color: _teal,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      timer.isPaused
                                          ? '已暂停 · ${timer.remainingLabel}'
                                          : '剩余 ${timer.remainingLabel}',
                                      style: const TextStyle(
                                        color: _teal,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: timer.isPaused ? '继续' : '暂停',
                                    onPressed: widget.readonly
                                        ? null
                                        : () => timer.isPaused
                                              ? widget.store.resumeTimer(
                                                  timer.id,
                                                )
                                              : widget.store.pauseTimer(
                                                  timer.id,
                                                ),
                                    icon: Icon(
                                      timer.isPaused
                                          ? Icons.play_arrow
                                          : Icons.pause,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '停止',
                                    onPressed: widget.readonly
                                        ? null
                                        : () =>
                                              widget.store.stopTimer(timer.id),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                    if (widget.readonly) return row;
                    return IosSwipeDelete(
                      key: ValueKey('bench-step-${step.id}'),
                      confirmTitle: '删除步骤？',
                      confirmMessage: '删除后，这个实验的步骤列表会立即更新。',
                      onDelete: () async => _deleteRunStep(step),
                      child: row,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: stepIndex == 0 ? null : _goToPreviousStep,
                      child: Transform.rotate(
                        angle: math.pi,
                        child: const IosGlyphIcon(
                          IosGlyph.chevronRight,
                          color: _teal,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.readonly ? null : _completeCurrentStep,
                      icon: const Icon(Icons.check_circle),
                      label: Text(
                        run.completedCount == run.steps.length
                            ? '完成实验'
                            : '完成此步骤',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: stepIndex >= run.steps.length - 1
                          ? null
                          : _goToNextStep,
                      child: const IosGlyphIcon(
                        IosGlyph.chevronRight,
                        color: _teal,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenchFullMode extends StatelessWidget {
  const _BenchFullMode({
    required this.run,
    required this.stepIndex,
    required this.currentStep,
    required this.timer,
    required this.progress,
    required this.readonly,
    required this.onExitFull,
    required this.onClose,
    required this.onDataCard,
    required this.onPrevious,
    required this.onNext,
    required this.onStepSelected,
    required this.onCompleteStep,
    required this.onStartTimer,
    required this.onPauseTimer,
    required this.onStopTimer,
  });

  final LabRun run;
  final int stepIndex;
  final LabStep currentStep;
  final LabTimer? timer;
  final double progress;
  final bool readonly;
  final VoidCallback onExitFull;
  final VoidCallback onClose;
  final VoidCallback onDataCard;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onStepSelected;
  final VoidCallback onCompleteStep;
  final VoidCallback? onStartTimer;
  final VoidCallback? onPauseTimer;
  final VoidCallback? onStopTimer;

  void _handleStepSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -280) {
      onNext?.call();
    } else if (velocity > 280) {
      onPrevious?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: _handleStepSwipe,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            run.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${run.area} · ${run.timeLabel}',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _BenchHeaderButton(
                      icon: Icons.view_sidebar_outlined,
                      onTap: onExitFull,
                    ),
                    const SizedBox(width: 10),
                    _BenchHeaderButton(
                      icon: Icons.ios_share,
                      onTap: onDataCard,
                    ),
                    const SizedBox(width: 10),
                    _BenchHeaderButton(
                      icon: Icons.close,
                      filled: false,
                      onTap: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                IosProgressBar(value: progress, trackColor: _line),
                const Spacer(),
                Text(
                  '步骤 ${stepIndex + 1}',
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  currentStep.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  currentStep.detail,
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 17,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                _BenchFullTimerPanel(
                  step: currentStep,
                  timer: timer,
                  onStartTimer: onStartTimer,
                  onPauseTimer: onPauseTimer,
                  onStopTimer: onStopTimer,
                ),
                const Spacer(),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: run.steps.asMap().entries.map((entry) {
                      final active = entry.key == stepIndex;
                      final done = entry.value.done;
                      return GestureDetector(
                        onTap: () => onStepSelected(entry.key),
                        child: Container(
                          width: active ? 34 : 28,
                          height: active ? 34 : 28,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active
                                ? _teal
                                : done
                                ? _teal.withValues(alpha: 0.35)
                                : _muted.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: done
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : active
                              ? Text(
                                  '${entry.key + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: onPrevious,
                        child: Transform.rotate(
                          angle: math.pi,
                          child: const IosGlyphIcon(
                            IosGlyph.chevronRight,
                            color: _teal,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: readonly ? null : onCompleteStep,
                        icon: Icon(
                          run.completedCount == run.steps.length
                              ? Icons.verified
                              : Icons.check_circle,
                        ),
                        label: Text(
                          run.completedCount == run.steps.length
                              ? '完成实验'
                              : '完成此步骤',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: onNext,
                        child: const IosGlyphIcon(
                          IosGlyph.chevronRight,
                          color: _teal,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenchFullTimerPanel extends StatelessWidget {
  const _BenchFullTimerPanel({
    required this.step,
    required this.timer,
    required this.onStartTimer,
    required this.onPauseTimer,
    required this.onStopTimer,
  });

  final LabStep step;
  final LabTimer? timer;
  final VoidCallback? onStartTimer;
  final VoidCallback? onPauseTimer;
  final VoidCallback? onStopTimer;

  @override
  Widget build(BuildContext context) {
    final currentTimer = timer;
    if (currentTimer != null) {
      final totalSeconds = math.max(1, (step.durationMinutes ?? 1) * 60);
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        decoration: BoxDecoration(
          color: _labPanel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _teal.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            _CircularTimerRing(
              remainingSeconds: currentTimer.remainingSeconds,
              totalSeconds: totalSeconds,
              isPaused: currentTimer.isPaused,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onPauseTimer,
                  icon: Icon(
                    currentTimer.isPaused ? Icons.play_arrow : Icons.pause,
                  ),
                  label: Text(currentTimer.isPaused ? '继续' : '暂停'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onStopTimer,
                  icon: const Icon(Icons.stop),
                  label: const Text('取消'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (step.durationMinutes == null) return const SizedBox.shrink();
    return FilledButton.icon(
      onPressed: onStartTimer,
      icon: const Icon(Icons.play_arrow),
      label: Text('启动计时 ${step.durationMinutes} min'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

class _CircularTimerRing extends StatelessWidget {
  const _CircularTimerRing({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.isPaused,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final bool isPaused;

  String get _label {
    if (remainingSeconds <= 0) return '完成';
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = remainingSeconds <= 0;
    final accent = isFinished || isPaused ? Colors.orange : _teal;
    final progress = totalSeconds <= 0
        ? 0.0
        : (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 144,
      height: 144,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(144),
            painter: _CircularTimerRingPainter(
              progress: progress,
              color: accent,
            ),
          ),
          Text(
            isPaused ? '暂停' : _label,
            style: TextStyle(
              color: accent,
              fontSize: isPaused ? 30 : 34,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularTimerRingPainter extends CustomPainter {
  const _CircularTimerRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(6),
      -math.pi / 2,
      math.pi * 2,
      false,
      stroke..color = _muted.withValues(alpha: 0.12),
    );
    canvas.drawArc(
      rect.deflate(6),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      stroke..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularTimerRingPainter oldDelegate) {
    return progress != oldDelegate.progress || color != oldDelegate.color;
  }
}

class StepEditorSheet extends StatefulWidget {
  const StepEditorSheet({super.key, required this.step});

  final LabStep step;

  @override
  State<StepEditorSheet> createState() => _StepEditorSheetState();
}

class _StepEditorSheetState extends State<StepEditorSheet> {
  late final TextEditingController titleController;
  late final TextEditingController detailController;
  late final TextEditingController minutesController;
  late bool hasDuration;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.step.title);
    detailController = TextEditingController(text: widget.step.detail);
    minutesController = TextEditingController(
      text: (widget.step.durationMinutes ?? 5).toString(),
    );
    hasDuration = widget.step.durationMinutes != null;
  }

  @override
  void dispose() {
    titleController.dispose();
    detailController.dispose();
    minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '编辑步骤',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  SectionCard(
                    title: '步骤信息',
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: '步骤名称'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: detailController,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(labelText: '详细说明'),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _appendSubstep,
                          icon: const Icon(Icons.format_list_numbered),
                          label: const Text('添加分步骤'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: '计时',
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: hasDuration,
                        onChanged: (value) =>
                            setState(() => hasDuration = value),
                        title: const Text('需要计时'),
                        subtitle: const Text('详情页仍可使用自定义计时'),
                      ),
                      if (hasDuration) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: minutesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '默认时长',
                            suffixText: 'min',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('保存步骤'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _appendSubstep() {
    final existing = detailController.text
        .split('\n')
        .where((line) => RegExp(r'^\s*\d+\.').hasMatch(line.trim()))
        .length;
    final prefix = detailController.text.trim().isEmpty ? '' : '\n';
    detailController.text =
        '${detailController.text}$prefix${existing + 1}. 新分步骤';
    detailController.selection = TextSelection.collapsed(
      offset: detailController.text.length,
    );
  }

  void _save() {
    final title = titleController.text.trim();
    final minutes = int.tryParse(minutesController.text.trim());
    Navigator.pop(
      context,
      widget.step.copyWith(
        title: title.isEmpty ? widget.step.title : title,
        detail: detailController.text.trim(),
        durationMinutes: hasDuration ? math.max(1, minutes ?? 5) : null,
        clearDurationMinutes: !hasDuration,
      ),
    );
  }
}

class RunStepEditorSheet extends StatefulWidget {
  const RunStepEditorSheet({super.key, required this.store, required this.run});

  final LabStore store;
  final LabRun run;

  @override
  State<RunStepEditorSheet> createState() => _RunStepEditorSheetState();
}

class _RunStepEditorSheetState extends State<RunStepEditorSheet> {
  late List<_ProtocolStepDraft> stepDrafts;

  @override
  void initState() {
    super.initState();
    stepDrafts = widget.run.steps.map(_ProtocolStepDraft.fromStep).toList();
  }

  @override
  void dispose() {
    for (final draft in stepDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '编辑详细步骤',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IosPlusCircleButton(onPressed: _addStep),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.run.title,
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < stepDrafts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: IosSwipeDelete(
                        key: ValueKey(stepDrafts[i].id),
                        confirmTitle: '删除步骤？',
                        confirmMessage: '删除后，这个实验的步骤列表会立即更新。',
                        onDelete: () async => _removeStep(i),
                        child: _RunStepDraftRow(
                          index: i,
                          draft: stepDrafts[i],
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('保存步骤'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addStep() async {
    final newStep = LabStep(
      id: 'step-${DateTime.now().microsecondsSinceEpoch}',
      title: '新步骤',
      detail: '',
      durationMinutes: null,
      carryOver: false,
      reagents: const [],
    );
    final updated = await showModalBottomSheet<LabStep>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StepEditorSheet(step: newStep),
    );
    if (updated == null || !mounted) return;
    setState(() {
      stepDrafts.add(_ProtocolStepDraft.fromStep(updated));
    });
  }

  void _removeStep(int index) {
    setState(() {
      final draft = stepDrafts.removeAt(index);
      draft.dispose();
    });
  }

  Future<void> _save() async {
    final steps = stepDrafts
        .map((draft) => draft.toStep())
        .where((step) => step.title.trim().isNotEmpty)
        .toList();
    await widget.store.updateRunSteps(
      widget.run.id,
      steps.isEmpty ? manualSteps : steps,
    );
    if (mounted) Navigator.pop(context);
  }
}

class RunDetailEditorSheet extends StatefulWidget {
  const RunDetailEditorSheet({
    super.key,
    required this.store,
    required this.run,
    this.onDataCard,
  });

  final LabStore store;
  final LabRun run;
  final VoidCallback? onDataCard;

  @override
  State<RunDetailEditorSheet> createState() => _RunDetailEditorSheetState();
}

class _RunDetailEditorSheetState extends State<RunDetailEditorSheet> {
  late final TextEditingController titleController;
  late List<_ProtocolStepDraft> stepDrafts;
  String? projectId;
  late int selectedHour;
  late int selectedMinute;

  LabTimer? get activeTimer => widget.store.timers
      .where((timer) => timer.runId == widget.run.id)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.run.title);
    final parsedTime = _timePartsFromLabel(widget.run.timeLabel);
    selectedHour = parsedTime.hour;
    selectedMinute = parsedTime.minute;
    projectId =
        widget.store.projects.any(
          (project) => project.id == widget.run.projectId,
        )
        ? widget.run.projectId
        : null;
    stepDrafts = widget.run.steps.map(_ProtocolStepDraft.fromStep).toList();
    widget.store.addListener(_handleStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_handleStoreChanged);
    titleController.dispose();
    for (final draft in stepDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _handleStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '编辑实验详情',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('run-detail-save-button'),
                  onPressed: _save,
                  child: const Text('保存'),
                ),
                if (widget.onDataCard != null)
                  IconButton(
                    tooltip: 'Data Card',
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDataCard?.call();
                    },
                    icon: const Icon(Icons.ios_share),
                  ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  SectionCard(
                    title: '实验信息',
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: '实验名称'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _showTimePickerSheet,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _labInset,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _line),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                color: _teal,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  '时间',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                _selectedTimeLabel,
                                style: const TextStyle(
                                  color: _teal,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.store.projects.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          initialValue: projectId,
                          decoration: const InputDecoration(labelText: '项目'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('无项目'),
                            ),
                            ...widget.store.projects.map(
                              (project) => DropdownMenuItem<String?>(
                                value: project.id,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: project.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(project.name),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => projectId = value),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: '详细步骤',
                    trailing: IosPlusCircleButton(
                      key: const Key('run-detail-add-step-button'),
                      onPressed: _addStep,
                      semanticLabel: '添加步骤',
                    ),
                    children: [
                      for (var i = 0; i < stepDrafts.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: IosSwipeDelete(
                            key: ValueKey('detail-${stepDrafts[i].id}'),
                            confirmTitle: '删除步骤？',
                            confirmMessage: '删除后，这个实验的步骤列表会立即更新。',
                            onDelete: () async => _removeStep(i),
                            child: _RunStepDraftRow(
                              index: i,
                              draft: stepDrafts[i],
                              onEdit: () => _editStep(i),
                              onTimer: () => _startStepTimer(i),
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (activeTimer != null) ...[
                    const SizedBox(height: 12),
                    SectionCard(
                      title: '运行中的计时器',
                      children: [
                        _RunDetailTimerPanel(
                          timer: activeTimer!,
                          onPauseResume: () async {
                            final timer = activeTimer;
                            if (timer == null) return;
                            if (timer.isPaused) {
                              await widget.store.resumeTimer(timer.id);
                            } else {
                              await widget.store.pauseTimer(timer.id);
                            }
                            if (mounted) setState(() {});
                          },
                          onStop: () async {
                            final timer = activeTimer;
                            if (timer == null) return;
                            await widget.store.stopTimer(timer.id);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addStep() async {
    final newStep = LabStep(
      id: 'step-${DateTime.now().microsecondsSinceEpoch}',
      title: '新步骤',
      detail: '',
      durationMinutes: null,
      carryOver: false,
      reagents: const [],
    );
    final updated = await showModalBottomSheet<LabStep>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StepEditorSheet(step: newStep),
    );
    if (updated == null || !mounted) return;
    setState(() {
      stepDrafts.add(_ProtocolStepDraft.fromStep(updated));
    });
  }

  void _removeStep(int index) {
    setState(() {
      final draft = stepDrafts.removeAt(index);
      draft.dispose();
    });
  }

  Future<void> _editStep(int index) async {
    if (index < 0 || index >= stepDrafts.length) return;
    final updated = await showModalBottomSheet<LabStep>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StepEditorSheet(step: stepDrafts[index].toStep()),
    );
    if (updated == null || !mounted) return;
    setState(() {
      final oldDraft = stepDrafts[index];
      stepDrafts[index] = _ProtocolStepDraft.fromStep(updated);
      oldDraft.dispose();
    });
  }

  Future<void> _startStepTimer(int index) async {
    if (index < 0 || index >= stepDrafts.length) return;
    await _persistDrafts();
    if (!mounted) return;
    final step = stepDrafts[index].toStep();
    final seconds = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomTimerStartSheet(step: step),
    );
    if (seconds == null) return;
    await widget.store.startTimer(widget.run, step, customSeconds: seconds);
    if (mounted) setState(() {});
  }

  Future<void> _persistDrafts() async {
    final title = titleController.text.trim();
    final steps = stepDrafts
        .map((draft) => draft.toStep())
        .where((step) => step.title.trim().isNotEmpty)
        .toList();
    await widget.store.updateRun(
      widget.run.copyWith(
        title: title.isEmpty ? widget.run.title : title,
        timeLabel: _selectedTimeLabel,
        projectId: projectId,
        clearProjectId: projectId == null,
        steps: steps.isEmpty ? manualSteps : steps,
      ),
    );
  }

  Future<void> _save() async {
    await _persistDrafts();
    if (mounted) Navigator.pop(context);
  }

  String get _selectedTimeLabel =>
      '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';

  Future<void> _showTimePickerSheet() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RunTimePickerSheet(
        initialHour: selectedHour,
        initialMinute: selectedMinute,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedHour = picked.hour;
      selectedMinute = picked.minute;
    });
  }
}

({int hour, int minute}) _timePartsFromLabel(String label) {
  final parts = label.split(':');
  if (parts.length != 2) return (hour: 9, minute: 0);
  final hour = int.tryParse(parts.first.trim()) ?? 9;
  final minute = int.tryParse(parts.last.trim()) ?? 0;
  return (hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}

class _RunTimePickerSheet extends StatefulWidget {
  const _RunTimePickerSheet({
    required this.initialHour,
    required this.initialMinute,
  });

  final int initialHour;
  final int initialMinute;

  @override
  State<_RunTimePickerSheet> createState() => _RunTimePickerSheetState();
}

class _RunTimePickerSheetState extends State<_RunTimePickerSheet> {
  late int hour;
  late int minute;
  static const minuteOptions = [0, 15, 30, 45];

  @override
  void initState() {
    super.initState();
    hour = widget.initialHour.clamp(0, 23);
    final initialMinute = widget.initialMinute.clamp(0, 59);
    minute = minuteOptions.reduce(
      (best, candidate) =>
          (candidate - initialMinute).abs() < (best - initialMinute).abs()
          ? candidate
          : best,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('run-time-cancel-button'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                Expanded(
                  child: Text(
                    '选择实验时间',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 52),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimerWheelColumn(
                  key: const Key('run-time-hour-wheel'),
                  label: '时',
                  value: hour,
                  max: 23,
                  onChanged: (value) => setState(() => hour = value),
                ),
                _TimerWheelColumn(
                  key: const Key('run-time-minute-wheel'),
                  label: '分',
                  value: minuteOptions
                      .indexOf(minute)
                      .clamp(0, minuteOptions.length - 1),
                  max: minuteOptions.length - 1,
                  values: minuteOptions,
                  onChanged: (value) => setState(
                    () => minute =
                        minuteOptions[value.clamp(0, minuteOptions.length - 1)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, TimeOfDay(hour: hour, minute: minute)),
              icon: const Icon(Icons.check),
              label: const Text('应用时间'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunDetailTimerPanel extends StatelessWidget {
  const _RunDetailTimerPanel({
    required this.timer,
    required this.onPauseResume,
    required this.onStop,
  });

  final LabTimer timer;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final alerting = timer.remainingSeconds <= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alerting
            ? const Color(0xFFFF9500).withValues(alpha: 0.12)
            : timer.isPaused
            ? const Color(0xFFFF9500).withValues(alpha: 0.08)
            : _labInset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: alerting || timer.isPaused
              ? const Color(0xFFFF9500).withValues(alpha: 0.18)
              : _line,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                alerting
                    ? Icons.notifications_active
                    : timer.isPaused
                    ? Icons.pause_circle
                    : Icons.timer,
                color: alerting || timer.isPaused
                    ? const Color(0xFFFF9500)
                    : _teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  timer.stepTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (timer.isPaused)
                const Text(
                  '已暂停',
                  style: TextStyle(
                    color: Color(0xFFFF9500),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                alerting ? '到点' : timer.remainingLabel,
                style: TextStyle(
                  color: alerting || timer.isPaused
                      ? const Color(0xFFFF9500)
                      : _teal,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!alerting)
                Expanded(
                  child: timer.isPaused
                      ? FilledButton.icon(
                          onPressed: onPauseResume,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('继续'),
                        )
                      : OutlinedButton.icon(
                          onPressed: onPauseResume,
                          icon: const Icon(Icons.pause),
                          label: const Text('暂停'),
                        ),
                ),
              if (!alerting) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
                  label: const Text('取消'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunStepDraftRow extends StatelessWidget {
  const _RunStepDraftRow({
    required this.index,
    required this.draft,
    required this.onChanged,
    this.onEdit,
    this.onTimer,
  });

  final int index;
  final _ProtocolStepDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onTimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: _teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.titleController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(hintText: '步骤名称'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: draft.minutesController,
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'min'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: draft.detailController,
            onChanged: (_) => onChanged(),
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '操作描述'),
          ),
          if (onTimer != null || onEdit != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onTimer != null)
                    Tooltip(
                      message: '计时此步骤',
                      child: OutlinedButton.icon(
                        key: ValueKey('run-detail-step-timer-$index'),
                        onPressed: onTimer,
                        icon: const Icon(Icons.timer_outlined, size: 17),
                        label: const Text('Timer'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  if (onEdit != null)
                    Tooltip(
                      message: '编辑此步骤',
                      child: OutlinedButton.icon(
                        key: ValueKey('run-detail-step-edit-$index'),
                        onPressed: onEdit,
                        icon: const Icon(Icons.tune, size: 17),
                        label: const Text('步骤'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (var i = 0; i < draft.reagents.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: IosSwipeDelete(
                key: ValueKey(draft.reagents[i].id),
                confirmTitle: '删除试剂？',
                confirmMessage: '删除这个步骤试剂后，保存步骤时不会再包含它。',
                onDelete: () async {
                  final reagent = draft.reagents.removeAt(i);
                  reagent.dispose();
                  onChanged();
                },
                child: _SimpleStepReagentDraftRow(
                  reagent: draft.reagents[i],
                  onChanged: onChanged,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.reagents.add(
                  _ProtocolStepReagentDraft(
                    name: '新试剂',
                    amountExpression: '1',
                    unit: 'ml',
                    isFormula: false,
                  ),
                );
                onChanged();
              },
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('增加试剂'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleStepReagentDraftRow extends StatelessWidget {
  const _SimpleStepReagentDraftRow({
    required this.reagent,
    required this.onChanged,
  });

  final _ProtocolStepReagentDraft reagent;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: reagent.nameController,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(hintText: '试剂名称'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              controller: reagent.amountController,
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(hintText: '用量'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: TextField(
              controller: reagent.unitController,
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(hintText: '单位'),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomTimerStartSheet extends StatefulWidget {
  const CustomTimerStartSheet({super.key, required this.step});

  final LabStep step;

  @override
  State<CustomTimerStartSheet> createState() => _CustomTimerStartSheetState();
}

class _CustomTimerStartSheetState extends State<CustomTimerStartSheet> {
  late int hours;
  late int minutes;
  late int seconds;

  @override
  void initState() {
    super.initState();
    final totalSeconds = (widget.step.durationMinutes ?? 5) * 60;
    hours = (totalSeconds ~/ 3600).clamp(0, 23);
    minutes = ((totalSeconds % 3600) ~/ 60).clamp(0, 59);
    seconds = (totalSeconds % 60).clamp(0, 59);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('custom-timer-cancel-button'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                Expanded(
                  child: Text(
                    '自定义计时时长',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 52),
              ],
            ),
            const SizedBox(height: 6),
            Text(widget.step.title, style: const TextStyle(color: _muted)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimerWheelColumn(
                  key: const Key('timer-hours-wheel'),
                  label: '时',
                  value: hours,
                  max: 23,
                  onChanged: (value) => setState(() => hours = value),
                ),
                _TimerWheelColumn(
                  key: const Key('timer-minutes-wheel'),
                  label: '分',
                  value: minutes,
                  max: 59,
                  onChanged: (value) => setState(() => minutes = value),
                ),
                _TimerWheelColumn(
                  key: const Key('timer-seconds-wheel'),
                  label: '秒',
                  value: seconds,
                  max: 59,
                  onChanged: (value) => setState(() => seconds = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final totalSeconds = math.max(
                  1,
                  (hours * 3600) + (minutes * 60) + seconds,
                );
                Navigator.pop(context, totalSeconds);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始计时'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerWheelColumn extends StatelessWidget {
  const _TimerWheelColumn({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.values,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final List<int>? values;

  @override
  Widget build(BuildContext context) {
    final displayValues = values ?? [for (var i = 0; i <= max; i++) i];
    return SizedBox(
      width: 96,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 160,
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: value),
              itemExtent: 34,
              magnification: 1.08,
              squeeze: 1.1,
              useMagnifier: true,
              selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                background: Color(0x1A00C7BE),
              ),
              onSelectedItemChanged: onChanged,
              children: [
                for (final item in displayValues)
                  Center(
                    child: Text(
                      item.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class ProtocolScreen extends StatefulWidget {
  const ProtocolScreen({super.key, required this.store});

  final LabStore store;

  @override
  State<ProtocolScreen> createState() => _ProtocolScreenState();
}

class _ProtocolScreenState extends State<ProtocolScreen> {
  final searchController = TextEditingController();
  String? selectedArea;
  bool reorderMode = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const areas = ['细胞实验', '动物实验', '核酸实验', '蛋白实验'];
    final query = searchController.text.trim().toLowerCase();
    final canReorder = selectedArea == null && query.isEmpty;
    if (!canReorder && reorderMode) {
      reorderMode = false;
    }
    final protocols =
        widget.store.protocols.where((protocol) {
          final matchesArea =
              selectedArea == null || protocol.area == selectedArea;
          final matchesQuery =
              query.isEmpty ||
              protocol.name.toLowerCase().contains(query) ||
              protocol.area.toLowerCase().contains(query) ||
              protocol.sourceTitle.toLowerCase().contains(query);
          return matchesArea && matchesQuery;
        }).toList()..sort((left, right) {
          final leftFavorite = widget.store.isFavoriteProtocol(left.id);
          final rightFavorite = widget.store.isFavoriteProtocol(right.id);
          if (leftFavorite != rightFavorite) {
            return leftFavorite ? -1 : 1;
          }
          final leftIndex = widget.store.protocols.indexWhere(
            (protocol) => protocol.id == left.id,
          );
          final rightIndex = widget.store.protocols.indexWhere(
            (protocol) => protocol.id == right.id,
          );
          return leftIndex.compareTo(rightIndex);
        });
    return Scaffold(
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, _iosTopOffset, 18, 100),
          itemCount: protocols.length + 2,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  IosSearchField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    hintText: '搜索 Protocol 名称或来源',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterPill(
                          label: '全部',
                          selected: selectedArea == null,
                          color: _teal,
                          onTap: () => setState(() => selectedArea = null),
                        ),
                        const SizedBox(width: 8),
                        ...areas.expand(
                          (area) => [
                            _FilterPill(
                              label: area,
                              selected: selectedArea == area,
                              color: _teal,
                              onTap: () => setState(() {
                                selectedArea = selectedArea == area
                                    ? null
                                    : area;
                              }),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canReorder) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => reorderMode = !reorderMode),
                        icon: Icon(
                          reorderMode ? Icons.check : Icons.swap_vert,
                          size: 18,
                        ),
                        label: Text(reorderMode ? '完成' : '排序'),
                      ),
                    ),
                  ],
                  if (protocols.isEmpty) ...[
                    const SizedBox(height: 92),
                    EmptyState(
                      icon: Icons.assignment_outlined,
                      title: query.isEmpty ? '还没有 Protocol' : '没有匹配的 Protocol',
                      body: '往下翻到底部可新建或提取',
                    ),
                    const SizedBox(height: 92),
                  ],
                ],
              );
            }
            if (index == protocols.length + 1) {
              return _ProtocolBottomActions(
                onCreate: () => _showProtocolEditor(context),
                onExtract: () => _showProtocolExtraction(context),
              );
            }
            final protocol = protocols[index - 1];
            final favorite = widget.store.isFavoriteProtocol(protocol.id);
            return IosSwipeDelete(
              key: ValueKey('protocol-${protocol.id}'),
              confirmTitle: '删除 Protocol？',
              confirmMessage: '删除「${protocol.name}」后，不会影响已经创建的实验记录。',
              onDelete: () async {
                await widget.store.deleteProtocol(protocol.id);
                if (mounted) setState(() {});
              },
              child: ProtocolLibraryTile(
                protocol: protocol,
                favorite: favorite,
                onFavorite: () async {
                  await widget.store.toggleProtocolFavorite(protocol.id);
                  if (mounted) setState(() {});
                },
                onOpen: () async {
                  await widget.store.markProtocolRecent(protocol.id);
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProtocolDetailScreen(
                        store: widget.store,
                        protocol: protocol,
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                onEdit: () => _showProtocolEditor(context, existing: protocol),
                onDelete: () async {
                  final ok = await _confirmDelete(
                    context,
                    title: '删除 Protocol？',
                    message: '删除「${protocol.name}」后，不会影响已经创建的实验记录。',
                  );
                  if (!ok) return;
                  await widget.store.deleteProtocol(protocol.id);
                  if (mounted) setState(() {});
                },
                onCreateRun: () async {
                  await widget.store.markProtocolRecent(protocol.id);
                  if (!context.mounted) return;
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => RunEditorSheet(
                      store: widget.store,
                      target: DayMode.today,
                      presetProtocol: protocol,
                    ),
                  );
                },
                reorderControls: reorderMode
                    ? _ProtocolReorderControls(
                        canMoveUp:
                            widget.store.protocols.indexWhere(
                              (item) => item.id == protocol.id,
                            ) >
                            0,
                        canMoveDown:
                            widget.store.protocols.indexWhere(
                              (item) => item.id == protocol.id,
                            ) <
                            widget.store.protocols.length - 1,
                        onMoveUp: () async {
                          await widget.store.moveProtocol(protocol.id, -1);
                          if (mounted) setState(() {});
                        },
                        onMoveDown: () async {
                          await widget.store.moveProtocol(protocol.id, 1);
                          if (mounted) setState(() {});
                        },
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showProtocolEditor(
    BuildContext context, {
    LabProtocol? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          ProtocolEditorSheet(store: widget.store, existing: existing),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showProtocolExtraction(BuildContext context) async {
    final extracted = await showModalBottomSheet<LabProtocol>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProtocolExtractionSheet(store: widget.store),
    );
    if (!context.mounted) return;
    if (extracted != null) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            ProtocolEditorSheet(store: widget.store, existing: extracted),
      );
    }
    if (mounted) setState(() {});
  }
}

class IosSearchField extends StatelessWidget {
  const IosSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line, width: 0.55),
      ),
      child: Row(
        children: [
          IosGlyphIcon(
            IosGlyph.search,
            color: _muted.withValues(alpha: 0.78),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: _muted.withValues(alpha: 0.44),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IosPlusCircleButton extends StatelessWidget {
  const IosPlusCircleButton({
    super.key,
    required this.onPressed,
    this.semanticLabel = '添加',
  });

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: const SizedBox.square(
            dimension: 44,
            child: Center(
              child: IosGlyphIcon(
                IosGlyph.plusCircleFill,
                color: _teal,
                size: 25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProtocolBottomActions extends StatelessWidget {
  const _ProtocolBottomActions({
    required this.onCreate,
    required this.onExtract,
  });

  final VoidCallback onCreate;
  final VoidCallback onExtract;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const IosGlyphIcon(
                IosGlyph.plusCircle,
                color: Colors.white,
                size: 21,
              ),
              label: const Text('新建'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onExtract,
              icon: const IosGlyphIcon(
                IosGlyph.docText,
                color: _teal,
                size: 22,
              ),
              label: const Text('提取'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProtocolLibraryTile extends StatelessWidget {
  const ProtocolLibraryTile({
    super.key,
    required this.protocol,
    required this.favorite,
    required this.onFavorite,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onCreateRun,
    this.reorderControls,
  });

  final LabProtocol protocol;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final VoidCallback onCreateRun;
  final Widget? reorderControls;

  @override
  Widget build(BuildContext context) {
    final accent = _areaBadgeColor(protocol.area);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      protocol.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (reorderControls != null)
                    reorderControls!
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 34,
                          child: IconButton(
                            tooltip: '编辑 Protocol',
                            onPressed: onEdit,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.tune,
                              color: _teal,
                              size: 23,
                            ),
                          ),
                        ),
                        SizedBox.square(
                          dimension: 34,
                          child: IconButton(
                            tooltip: '删除 Protocol',
                            onPressed: onDelete,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFFF3B30),
                              size: 22,
                            ),
                          ),
                        ),
                        SizedBox.square(
                          dimension: 34,
                          child: IconButton(
                            tooltip: favorite ? '取消收藏' : '收藏',
                            onPressed: onFavorite,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: IosGlyphIcon(
                              IosGlyph.star,
                              color: favorite
                                  ? const Color(0xFFFFC107)
                                  : _muted.withValues(alpha: 0.48),
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  ChipLabel(text: protocol.area, color: accent),
                  Text(
                    '基准 ${protocol.baseVolumeLabel}',
                    style: const TextStyle(color: _muted, fontSize: 14.5),
                  ),
                  Text(
                    '· ${protocol.expectedDuration}',
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
              if (protocol.sourceTitle.isNotEmpty) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    IosGlyphIcon(
                      IosGlyph.docText,
                      color: accent.withValues(alpha: 0.70),
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _protocolSourceLabel(protocol),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '配方',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ...protocol.ingredients
                        .take(3)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: accent.withValues(alpha: 0.45),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                ),
                                Text(
                                  '${_formatNumber(item.amount)} ${item.unit}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (protocol.ingredients.length > 3)
                      Text(
                        '还有 ${protocol.ingredients.length - 3} 项成分',
                        style: const TextStyle(color: _muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolReorderControls extends StatelessWidget {
  const _ProtocolReorderControls({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '上移 Protocol',
          onPressed: canMoveUp ? onMoveUp : null,
          icon: const Icon(Icons.arrow_upward),
          visualDensity: VisualDensity.compact,
          color: _teal,
        ),
        IconButton(
          tooltip: '下移 Protocol',
          onPressed: canMoveDown ? onMoveDown : null,
          icon: const Icon(Icons.arrow_downward),
          visualDensity: VisualDensity.compact,
          color: _teal,
        ),
      ],
    );
  }
}

class ProtocolSummaryCard extends StatelessWidget {
  const ProtocolSummaryCard({super.key, required this.store});

  final LabStore store;

  @override
  Widget build(BuildContext context) {
    final favorites = store.favoriteProtocols;
    final recents = store.recentProtocols;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本地 Protocol 库',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${store.protocols.length} 个模板 · ${favorites.length} 个收藏 · ${recents.length} 个最近使用',
              style: const TextStyle(color: _muted),
            ),
            if (favorites.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('收藏', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: favorites
                    .map((protocol) => ChipLabel(text: protocol.name))
                    .toList(),
              ),
            ],
            if (recents.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('最近使用', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: recents
                    .map(
                      (protocol) => ChipLabel(
                        text: protocol.name,
                        color: Colors.blueGrey,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProtocolExtractionSheet extends StatefulWidget {
  const ProtocolExtractionSheet({super.key, required this.store});

  final LabStore store;

  @override
  State<ProtocolExtractionSheet> createState() =>
      _ProtocolExtractionSheetState();
}

class _ProtocolExtractionSheetState extends State<ProtocolExtractionSheet> {
  final sourceTitleController = TextEditingController(text: '粘贴文本');
  final extractedNameController = TextEditingController();
  final baseVolumeController = TextEditingController(text: '50');
  final rawTextController = TextEditingController(
    text:
        '293T cell passage\n1. Observe cell confluency\n2. Wash with 2 ml PBS\n3. Add 2 ml trypsin for 3 min\n4. Neutralize with complete medium\nDMEM 180 ml\nFBS 20 ml',
  );
  String sourceType = 'SOP';
  String area = '细胞实验';

  LabProtocol get previewDraft {
    final extracted = ProtocolTextExtractor.extract(
      text: rawTextController.text,
      sourceTitle: sourceTitleController.text,
      sourceType: sourceType,
      area: area,
    );
    final explicitName = extractedNameController.text.trim();
    final baseValue =
        double.tryParse(baseVolumeController.text.trim()) ??
        extracted.baseScaleValue;
    return LabProtocol(
      id: extracted.id,
      name: explicitName.isEmpty ? extracted.name : explicitName,
      area: extracted.area,
      baseVolumeLabel: '${_formatNumber(baseValue)} ${extracted.scaleUnit}',
      baseScaleValue: baseValue,
      scaleUnit: extracted.scaleUnit,
      expectedDuration: extracted.expectedDuration,
      ingredients: extracted.ingredients,
      variables: extracted.variables,
      steps: extracted.steps,
      sourceType: extracted.sourceType,
      sourceTitle: extracted.sourceTitle,
      confidence: extracted.confidence,
    );
  }

  bool get canAccept => rawTextController.text.trim().isNotEmpty;

  @override
  void dispose() {
    sourceTitleController.dispose();
    extractedNameController.dispose();
    baseVolumeController.dispose();
    rawTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              '提取 Protocol 草稿',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '选择 SOP、Kit Manual、文献方法或 OCR 文本后生成可编辑草稿，保存前会进入正式编辑页核对。',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 12),
            _ExtractionSourceActionCard(
              sourceType: sourceType,
              onPickPdf: () => _importDocument(context, title: '导入 PDF/文本'),
              onPickText: () => _importDocument(context, title: '导入文本文件'),
              onPickImage: () => _showOcrTextHint(context),
              onPasteOcr: () => _focusRawText(context),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sourceTitleController,
              decoration: const InputDecoration(
                labelText: '来源标题 / 文件名 / DOI / SOP 编号',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: sourceType,
              decoration: const InputDecoration(labelText: '来源类型'),
              items: const [
                DropdownMenuItem(value: 'SOP', child: Text('SOP')),
                DropdownMenuItem(
                  value: 'Kit Manual',
                  child: Text('Kit Manual'),
                ),
                DropdownMenuItem(
                  value: 'Literature',
                  child: Text('Literature'),
                ),
                DropdownMenuItem(value: 'Image', child: Text('Image / Photo')),
                DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                DropdownMenuItem(value: 'OCR Text', child: Text('OCR Text')),
              ],
              onChanged: (value) {
                setState(() {
                  sourceType = value ?? sourceType;
                  if (sourceTitleController.text == '粘贴文本') {
                    sourceTitleController.text = sourceType;
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: area,
              decoration: const InputDecoration(labelText: '实验类型'),
              items: widget.store.areaOptions
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => area = value ?? area),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: extractedNameController,
                    decoration: const InputDecoration(
                      labelText: 'Protocol 名称，可留空自动推断',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 104,
                  child: TextField(
                    controller: baseVolumeController,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '基准体积'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rawTextController,
              decoration: InputDecoration(
                labelText: sourceType == 'Image'
                    ? 'OCR 后文本 / 图片识别文本'
                    : '提取原文 / 方法文本',
                suffixIcon: rawTextController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        onPressed: () => setState(rawTextController.clear),
                        icon: const Icon(Icons.cancel),
                      ),
              ),
              minLines: 8,
              maxLines: 14,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _ProtocolDraftPreviewCard(draft: previewDraft),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canAccept
                  ? () => Navigator.pop(context, previewDraft)
                  : null,
              icon: const Icon(Icons.check_circle),
              label: const Text('生成草稿并继续编辑'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importDocument(
    BuildContext context, {
    required String title,
  }) async {
    try {
      final text = await _dataCardChannel.invokeMethod<String>(
        'pickTextDocument',
      );
      if (text == null || text.trim().isEmpty) return;
      setState(() {
        rawTextController.text = text;
        if (sourceTitleController.text == '粘贴文本') {
          sourceTitleController.text = title;
        }
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('文本已导入')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }

  Future<void> _showOcrTextHint(BuildContext context) async {
    setState(() {
      sourceType = 'Image';
      if (sourceTitleController.text == '粘贴文本') {
        sourceTitleController.text = '图片 OCR 文本';
      }
    });
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('图片识别'),
        content: const Text(
          '当前 APK 保留与 iOS 一致的图片/OCR 来源入口。请先用系统相册、相机或 OCR 工具复制识别文本，然后粘贴到“提取原文”。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _focusRawText(BuildContext context) {
    setState(() {
      sourceType = 'OCR Text';
      if (sourceTitleController.text == '粘贴文本') {
        sourceTitleController.text = 'OCR 文本';
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请粘贴 OCR 后的 Protocol 文本')));
  }
}

class _ExtractionSourceActionCard extends StatelessWidget {
  const _ExtractionSourceActionCard({
    required this.sourceType,
    required this.onPickPdf,
    required this.onPickText,
    required this.onPickImage,
    required this.onPasteOcr,
  });

  final String sourceType;
  final VoidCallback onPickPdf;
  final VoidCallback onPickText;
  final VoidCallback onPickImage;
  final VoidCallback onPasteOcr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IosGlyphIcon(IosGlyph.docText, color: _teal, size: 22),
              const SizedBox(width: 8),
              Text(
                sourceType,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              ChipLabel(text: '本地解析'),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '导入或粘贴原文后，下方会实时生成草稿预览。',
            style: TextStyle(color: _muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onPickPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('选择 PDF/文本'),
              ),
              OutlinedButton.icon(
                onPressed: onPickText,
                icon: const Icon(Icons.upload_file),
                label: const Text('导入文本'),
              ),
              OutlinedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('图片/OCR'),
              ),
              OutlinedButton.icon(
                onPressed: onPasteOcr,
                icon: const Icon(Icons.content_paste),
                label: const Text('粘贴 OCR'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProtocolDraftPreviewCard extends StatelessWidget {
  const _ProtocolDraftPreviewCard({required this.draft});

  final LabProtocol draft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('草稿预览', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  draft.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ChipLabel(text: draft.area, color: _areaBadgeColor(draft.area)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChipLabel(text: '${draft.ingredients.length} 个试剂'),
              ChipLabel(text: '${draft.steps.length} 个步骤'),
              ChipLabel(text: draft.expectedDuration),
            ],
          ),
          if (draft.ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '试剂',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            ...draft.ingredients
                .take(4)
                .map(
                  (item) => Text(
                    '• ${item.name}: ${_formatNumber(item.amount)} ${item.unit}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
          ],
          if (draft.steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '步骤',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            ...draft.steps
                .take(4)
                .map(
                  (step) => Text(
                    '• ${step.title}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _BenchHeaderButton extends StatelessWidget {
  const _BenchHeaderButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.filled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: filled
              ? _teal.withValues(alpha: 0.12)
              : _muted.withValues(alpha: 0.65),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: filled ? _teal : Colors.white, size: 24),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _StepNumberBadge extends StatelessWidget {
  const _StepNumberBadge({
    required this.index,
    required this.active,
    required this.done,
    required this.onTap,
  });

  final int index;
  final bool active;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? _teal.withValues(alpha: 0.55)
        : active
        ? _teal
        : _muted.withValues(alpha: 0.10);
    final textColor = active || done
        ? Colors.white
        : _muted.withValues(alpha: 0.45);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: done
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '$index',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
              ),
      ),
    );
  }
}

class ProtocolDetailScreen extends StatefulWidget {
  const ProtocolDetailScreen({
    super.key,
    required this.store,
    required this.protocol,
  });

  final LabStore store;
  final LabProtocol protocol;

  @override
  State<ProtocolDetailScreen> createState() => _ProtocolDetailScreenState();
}

class _ProtocolDetailScreenState extends State<ProtocolDetailScreen> {
  late final TextEditingController targetController;
  late final Map<String, TextEditingController> variableControllers;
  int? selectedStepIndex;

  LabProtocol get protocol =>
      widget.store.protocols
          .where((item) => item.id == widget.protocol.id)
          .firstOrNull ??
      widget.protocol;

  double get targetScale {
    final parsed = double.tryParse(targetController.text.trim());
    if (parsed == null || parsed <= 0) return protocol.baseScaleValue;
    return parsed;
  }

  double get scaleFactor =>
      protocol.baseScaleValue <= 0 ? 1 : targetScale / protocol.baseScaleValue;

  double _variableValue(ProtocolVariable variable) {
    final controller = variableControllers[variable.id];
    final raw = double.tryParse(controller?.text.trim() ?? '');
    return raw ?? variable.baseValue;
  }

  Map<String, double> get variableValues {
    final values = _protocolVariableMap(protocol.variables);
    for (final variable in protocol.variables) {
      final rawValue = _variableValue(variable);
      final computed = variable.unit.trim() == '%' ? rawValue / 100 : rawValue;
      values[variable.symbol] = computed;
      values[_safeFormulaName(variable.name)] = computed;
    }
    return values;
  }

  double get ingredientScaleFactor {
    final primary = protocol.variables
        .where((item) => item.isScalable)
        .firstOrNull;
    if (primary == null || primary.baseValue <= 0) return scaleFactor;
    return _variableValue(primary) / primary.baseValue;
  }

  @override
  void initState() {
    super.initState();
    targetController = TextEditingController(
      text: _formatNumber(widget.protocol.baseScaleValue),
    );
    variableControllers = {
      for (final variable in widget.protocol.variables)
        variable.id: TextEditingController(
          text: _formatNumber(variable.baseValue),
        ),
    };
  }

  @override
  void dispose() {
    targetController.dispose();
    for (final controller in variableControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 112),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              protocol.name,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: '分享 Protocol',
                            onPressed: () => _shareProtocol(context),
                            icon: const Icon(Icons.ios_share),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: '编辑 Protocol',
                            onPressed: () => _editProtocol(context),
                            icon: const Icon(Icons.tune),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChipLabel(
                            text: protocol.area,
                            color: _areaBadgeColor(protocol.area),
                          ),
                          Text(
                            '基准 ${protocol.baseVolumeLabel}',
                            style: const TextStyle(color: _muted),
                          ),
                          Text(
                            '· ${protocol.expectedDuration}',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                      if (protocol.sourceTitle.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: _muted,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _protocolSourceLabel(protocol),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (protocol.variables.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: protocol.variables
                              .map(
                                (variable) => ChipLabel(
                                  text:
                                      '${variable.name} ${_formatNumber(_variableValue(variable))} ${variable.unit}',
                                  color: Colors.indigo,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: targetController,
                        decoration: InputDecoration(
                          labelText: '目标规模',
                          suffixText: protocol.scaleUnit,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => _syncPrimaryVariableFromTarget(),
                        onSubmitted: (_) => _syncPrimaryVariableFromTarget(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '缩放倍率 x${scaleFactor.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              targetController.text = _formatNumber(
                                protocol.baseScaleValue,
                              );
                              _resetVariableControllers();
                              setState(() {});
                            },
                            child: const Text('重置'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (protocol.variables.isNotEmpty) ...[
                const SizedBox(height: 14),
                ProtocolVariableAdjustCard(
                  variables: protocol.variables,
                  controllers: variableControllers,
                  onChanged: () => setState(() {}),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '配方',
                      style: TextStyle(
                        color: _teal,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...protocol.ingredients.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if ((ingredientScaleFactor - 1).abs() > 0.001) ...[
                              Text(
                                '${_formatNumber(item.amount)} ${item.unit}',
                                style: const TextStyle(
                                  color: _muted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              '${_formatNumber(item.amount * ingredientScaleFactor)} ${item.unit}',
                              style: const TextStyle(
                                color: _teal,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '实验步骤',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (selectedStepIndex != null &&
                  selectedStepIndex! >= 0 &&
                  selectedStepIndex! < protocol.steps.length) ...[
                _ProtocolFocusedStepCard(
                  index: selectedStepIndex!,
                  step: protocol.steps[selectedStepIndex!],
                  stepCount: protocol.steps.length,
                  scaleFactor: scaleFactor,
                  variableValues: variableValues,
                  onClose: () => setState(() => selectedStepIndex = null),
                  onPrevious: selectedStepIndex == 0
                      ? null
                      : () => setState(
                          () => selectedStepIndex = selectedStepIndex! - 1,
                        ),
                  onNext: selectedStepIndex == protocol.steps.length - 1
                      ? null
                      : () => setState(
                          () => selectedStepIndex = selectedStepIndex! + 1,
                        ),
                ),
                const SizedBox(height: 10),
              ],
              ...protocol.steps.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => selectedStepIndex = entry.key),
                    child: ProtocolDetailStepCard(
                      index: entry.key,
                      step: entry.value,
                      selected: selectedStepIndex == entry.key,
                      scaleFactor: scaleFactor,
                      variableValues: variableValues,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => RunEditorSheet(
                      store: widget.store,
                      target: DayMode.today,
                      presetProtocol: protocol,
                    ),
                  );
                },
                icon: const Icon(Icons.playlist_add),
                label: const Text('用此 Protocol 创建今天的实验'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProtocol(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          ProtocolEditorSheet(store: widget.store, existing: protocol),
    );
    if (mounted) setState(() {});
  }

  Map<String, Object?> _protocolSharePayload() {
    final lines = <String>[
      '类型: ${protocol.area}',
      if (protocol.sourceTitle.isNotEmpty)
        '来源: ${_protocolSourceLabel(protocol)}',
      '基准: ${protocol.baseVolumeLabel}',
      '预计: ${protocol.expectedDuration}',
      if (protocol.ingredients.isNotEmpty) '配方:',
      ...protocol.ingredients
          .take(8)
          .map(
            (item) => '${item.name} ${_formatNumber(item.amount)} ${item.unit}',
          ),
      if (protocol.steps.isNotEmpty) '步骤:',
      ...protocol.steps
          .take(8)
          .map((step) => '${protocol.steps.indexOf(step) + 1}. ${step.title}'),
    ];
    return {
      'kind': 'protocol',
      'title': protocol.name,
      'subtitle': protocol.area,
      'lines': lines,
      'watermark': true,
    };
  }

  Future<void> _shareProtocol(BuildContext context) async {
    try {
      await _dataCardChannel.invokeMethod(
        'shareDataCard',
        _protocolSharePayload(),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享失败：$error')));
    }
  }

  void _syncPrimaryVariableFromTarget() {
    final primary = protocol.variables
        .where((item) => item.isScalable)
        .firstOrNull;
    if (primary == null) {
      setState(() {});
      return;
    }
    variableControllers[primary.id]?.text = _formatNumber(targetScale);
    setState(() {});
  }

  void _resetVariableControllers() {
    for (final variable in protocol.variables) {
      variableControllers[variable.id]?.text = _formatNumber(
        variable.baseValue,
      );
    }
  }
}

class ProtocolVariableAdjustCard extends StatelessWidget {
  const ProtocolVariableAdjustCard({
    super.key,
    required this.variables,
    required this.controllers,
    required this.onChanged,
  });

  final List<ProtocolVariable> variables;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              IosGlyphIcon(IosGlyph.function, color: _teal, size: 22),
              SizedBox(width: 8),
              Text('公式变量', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          ...variables.map(
            (variable) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _labInset,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            variable.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            variable.symbol,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 92,
                      child: TextField(
                        controller: controllers[variable.id],
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(hintText: '数值'),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        variable.unit,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolFocusedStepCard extends StatelessWidget {
  const _ProtocolFocusedStepCard({
    required this.index,
    required this.step,
    required this.stepCount,
    required this.scaleFactor,
    required this.variableValues,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
  });

  final int index;
  final LabStep step;
  final int stepCount;
  final double scaleFactor;
  final Map<String, double> variableValues;
  final VoidCallback onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _teal.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '第 ${index + 1} 步 / 共 $stepCount 步',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '关闭聚焦步骤',
                onPressed: onClose,
                icon: const Icon(Icons.cancel, color: _muted),
              ),
            ],
          ),
          ProtocolDetailStepCard(
            index: index,
            step: step,
            selected: true,
            scaleFactor: scaleFactor,
            variableValues: variableValues,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('上一步'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('下一步'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProtocolDetailStepCard extends StatelessWidget {
  const ProtocolDetailStepCard({
    super.key,
    required this.index,
    required this.step,
    required this.selected,
    required this.scaleFactor,
    required this.variableValues,
  });

  final int index;
  final LabStep step;
  final bool selected;
  final double scaleFactor;
  final Map<String, double> variableValues;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? _teal : _line,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: selected ? 1 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: selected ? Colors.white : _teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (step.durationMinutes != null)
                ChipLabel(text: '${step.durationMinutes} min'),
            ],
          ),
          const SizedBox(height: 8),
          Text(step.detail, style: const TextStyle(color: _muted)),
          if (step.reagents.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('本步试剂', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: step.reagents
                  .map(
                    (reagent) => ChipLabel(
                      text:
                          '${reagent.name} ${_stepReagentAmountLabel(reagent, scaleFactor, variableValues)} ${reagent.unit}',
                      color: Colors.indigo,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class ProtocolEditorSheet extends StatefulWidget {
  const ProtocolEditorSheet({super.key, required this.store, this.existing});

  final LabStore store;
  final LabProtocol? existing;

  @override
  State<ProtocolEditorSheet> createState() => _ProtocolEditorSheetState();
}

class _ProtocolEditorSheetState extends State<ProtocolEditorSheet> {
  late final TextEditingController nameController;
  late final TextEditingController durationValueController;
  late final TextEditingController baseValueController;
  late final TextEditingController sourceTitleController;
  late final TextEditingController confidenceController;
  late List<_ProtocolIngredientDraft> ingredientDrafts;
  late List<_ProtocolVariableDraft> variableDrafts;
  late List<_ProtocolStepDraft> stepDrafts;
  String area = '细胞实验';
  String sourceType = _defaultProtocolSourceType;
  String durationUnit = 'min';
  String baseUnit = 'reaction';

  static const List<String> _durationUnits = ['s', 'min', 'h', 'day'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    nameController = TextEditingController(
      text: existing?.name ?? '新 Protocol',
    );
    final parsedDuration = _parseValueAndUnit(
      existing?.expectedDuration ?? '15 min',
      fallbackValue: 15,
      fallbackUnit: 'min',
    );
    durationValueController = TextEditingController(
      text: _formatNumber(parsedDuration.value),
    );
    durationUnit = _durationUnits.contains(parsedDuration.unit)
        ? parsedDuration.unit
        : 'min';
    final parsedScale = _parseValueAndUnit(
      existing?.baseVolumeLabel ?? '50 ml',
      fallbackValue: existing?.baseScaleValue ?? 50,
      fallbackUnit: existing?.scaleUnit ?? 'ml',
    );
    baseValueController = TextEditingController(
      text: _formatNumber(existing?.baseScaleValue ?? parsedScale.value),
    );
    baseUnit = existing?.scaleUnit ?? parsedScale.unit;
    sourceTitleController = TextEditingController(
      text: existing?.sourceTitle ?? '',
    );
    sourceType = _normalizeProtocolSourceType(existing?.sourceType);
    confidenceController = TextEditingController(
      text: _formatNumber(existing?.confidence ?? 1.0),
    );
    ingredientDrafts =
        existing?.ingredients
            .map(_ProtocolIngredientDraft.fromIngredient)
            .toList() ??
        [_ProtocolIngredientDraft(name: '成分 A', amount: '50', unit: 'ml')];
    variableDrafts =
        existing?.variables.map(_ProtocolVariableDraft.fromVariable).toList() ??
        [];
    stepDrafts =
        existing?.steps.map(_ProtocolStepDraft.fromStep).toList() ??
        [_ProtocolStepDraft(title: '第一步', detail: '填写操作条件')];
    area = existing?.area ?? '细胞实验';
  }

  @override
  void dispose() {
    nameController.dispose();
    durationValueController.dispose();
    baseValueController.dispose();
    sourceTitleController.dispose();
    confidenceController.dispose();
    for (final draft in ingredientDrafts) {
      draft.dispose();
    }
    for (final draft in variableDrafts) {
      draft.dispose();
    }
    for (final draft in stepDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final consistencyIssues = _protocolConsistencyIssuesFromDrafts(
      variables: variableDrafts,
      steps: stepDrafts,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('protocol-editor-cancel-button'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                Expanded(
                  child: Text(
                    widget.existing == null ? '新增 Protocol' : '编辑 Protocol',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('protocol-editor-save-button'),
                  onPressed: _saveProtocol,
                  child: const Text('保存'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Protocol 名称'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: area,
                    decoration: const InputDecoration(labelText: '实验类型'),
                    items: widget.store.areaOptions
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => area = value ?? area),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: baseValueController,
                          decoration: const InputDecoration(labelText: '基准体积'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 112,
                        child: _InlineUnitDropdown(
                          label: '单位',
                          value: baseUnit,
                          options: _protocolUnitOptions(
                            widget.store.unitOptions,
                          ),
                          onChanged: (value) =>
                              setState(() => baseUnit = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationValueController,
                          decoration: const InputDecoration(labelText: '预计时长'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 112,
                        child: _InlineUnitDropdown(
                          label: '单位',
                          value: durationUnit,
                          options: _durationUnits,
                          onChanged: (value) =>
                              setState(() => durationUnit = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ProtocolEditorSection(
                    title: '单位定义',
                    glyph: IosGlyph.sliders,
                    children: [
                      _ProtocolUnitDefinitionPanel(
                        store: widget.store,
                        activeUnit: _baseUnit,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProtocolEditorSection(
                    title: '配方成分',
                    glyph: IosGlyph.beaker,
                    onAdd: _addIngredient,
                    children: [
                      for (var i = 0; i < ingredientDrafts.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IosSwipeDelete(
                            key: ValueKey(ingredientDrafts[i].id),
                            confirmTitle: '删除成分？',
                            confirmMessage: '删除这个配方成分后，保存 Protocol 时不会再包含它。',
                            onDelete: () async => _removeIngredient(i),
                            child: _ProtocolIngredientDraftRow(
                              draft: ingredientDrafts[i],
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProtocolEditorSection(
                    title: '公式变量',
                    glyph: IosGlyph.function,
                    onAdd: _addVariable,
                    addButtonKey: const Key('protocol-add-variable-button'),
                    addSemanticLabel: '添加变量',
                    children: [
                      for (var i = 0; i < variableDrafts.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IosSwipeDelete(
                            key: ValueKey(variableDrafts[i].id),
                            confirmTitle: '删除变量？',
                            confirmMessage: '删除这个变量后，步骤试剂里的公式可能无法继续计算。',
                            onDelete: () async => _removeVariable(i),
                            child: _ProtocolVariableDraftRow(
                              draft: variableDrafts[i],
                              unitOptions: widget.store.unitOptions,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (consistencyIssues.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ProtocolConsistencyIssuePanel(issues: consistencyIssues),
                  ],
                  const SizedBox(height: 12),
                  _ProtocolEditorSection(
                    title: '实验步骤',
                    glyph: IosGlyph.clipboard,
                    onAdd: _addStep,
                    children: [
                      for (var i = 0; i < stepDrafts.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IosSwipeDelete(
                            key: ValueKey(stepDrafts[i].id),
                            confirmTitle: '删除步骤？',
                            confirmMessage:
                                '删除步骤 ${i + 1} 后，保存 Protocol 时会从流程中移除。',
                            onDelete: () async => _removeStep(i),
                            child: _ProtocolStepDraftRow(
                              index: i,
                              draft: stepDrafts[i],
                              variables: variableDrafts,
                              defaultUnit: _baseUnit,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProtocolEditorSection(
                    title: '来源',
                    glyph: IosGlyph.docText,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: sourceType,
                        decoration: const InputDecoration(labelText: '来源类型'),
                        items: _protocolSourceTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => sourceType = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _baseValue =>
      double.tryParse(baseValueController.text.trim()) ?? 1;

  String get _baseUnit =>
      baseUnit.trim().isEmpty ? 'reaction' : baseUnit.trim();

  String get _baseScaleLabel => '${_formatNumber(_baseValue)} $_baseUnit';

  String get _durationLabel {
    final value = double.tryParse(durationValueController.text.trim()) ?? 20;
    final unit = durationUnit.trim().isEmpty ? 'min' : durationUnit.trim();
    return '${_formatNumber(value)} $unit';
  }

  Future<void> _saveProtocol() async {
    await widget.store.upsertProtocol(
      existingId: widget.existing?.id,
      name: nameController.text.trim().isEmpty
          ? '新 Protocol'
          : nameController.text.trim(),
      area: area,
      duration: _durationLabel,
      scale: _baseScaleLabel,
      baseScaleValue: _baseValue,
      scaleUnit: _baseUnit,
      ingredients: _ingredientsFromDrafts(),
      variables: _variablesFromDrafts(),
      steps: _stepsFromDrafts(),
      sourceType: sourceType,
      sourceTitle: sourceTitleController.text.trim().isEmpty
          ? _defaultProtocolSourceTitle(sourceType)
          : sourceTitleController.text.trim(),
      confidence: (double.tryParse(confidenceController.text.trim()) ?? 1)
          .clamp(0, 1)
          .toDouble(),
    );
    if (mounted) Navigator.pop(context);
  }

  void _addIngredient() {
    setState(() {
      ingredientDrafts.add(
        _ProtocolIngredientDraft(name: '新成分', amount: '1', unit: _baseUnit),
      );
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      final draft = ingredientDrafts.removeAt(index);
      draft.dispose();
    });
  }

  void _addVariable() {
    setState(() {
      final next = variableDrafts.length + 1;
      variableDrafts.add(
        _ProtocolVariableDraft(
          symbol: 'v$next',
          name: '新变量',
          value: '1',
          unit: _baseUnit,
          scalable: true,
        ),
      );
    });
  }

  void _removeVariable(int index) {
    setState(() {
      final draft = variableDrafts.removeAt(index);
      draft.dispose();
    });
  }

  void _addStep() {
    setState(() {
      stepDrafts.add(_ProtocolStepDraft(title: '新步骤', detail: ''));
    });
  }

  void _removeStep(int index) {
    setState(() {
      final draft = stepDrafts.removeAt(index);
      draft.dispose();
    });
  }

  List<ProtocolIngredient> _ingredientsFromDrafts() {
    return ingredientDrafts
        .map((draft) => draft.toIngredient())
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
  }

  List<ProtocolVariable> _variablesFromDrafts() {
    return variableDrafts
        .map((draft) => draft.toVariable())
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
  }

  List<LabStep> _stepsFromDrafts() {
    final steps = stepDrafts
        .map((draft) => draft.toStep())
        .where((step) => step.title.trim().isNotEmpty)
        .toList();
    return steps.isEmpty ? manualSteps : steps;
  }
}

class _ParsedValueAndUnit {
  const _ParsedValueAndUnit(this.value, this.unit);

  final double value;
  final String unit;
}

_ParsedValueAndUnit _parseValueAndUnit(
  String raw, {
  required double fallbackValue,
  required String fallbackUnit,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return _ParsedValueAndUnit(fallbackValue, fallbackUnit);
  final match = RegExp(
    r'^\s*([0-9]+(?:\.[0-9]+)?)\s*(.*)$',
  ).firstMatch(trimmed);
  final value = match == null
      ? fallbackValue
      : double.tryParse(match.group(1) ?? '') ?? fallbackValue;
  final unit = match == null ? trimmed : (match.group(2) ?? '').trim();
  return _ParsedValueAndUnit(value, unit.isEmpty ? fallbackUnit : unit);
}

List<String> _protocolUnitOptions(List<String> storeUnits) {
  return {
    'ml',
    'L',
    'μl',
    'reaction',
    'well',
    'tube',
    'prep',
    ...storeUnits,
  }.toList();
}

const _defaultProtocolSourceType = '手动创建';
const _protocolSourceTypes = ['手动创建', '图片识别', 'SOP', '试剂盒手册', '文献'];

String _normalizeProtocolSourceType(String? value) {
  final normalized = switch ((value ?? '').trim()) {
    '' ||
    'Manual' ||
    '手动' ||
    '手动创建' ||
    'Android local entry' => _defaultProtocolSourceType,
    '拍照识别' || '相册导入' || 'Image' || 'OCR Text' || '图片/OCR' => '图片识别',
    'Kit Manual' || '试剂盒' || '试剂盒手册' => '试剂盒手册',
    'Literature' || 'Paper' || '文献方法' || '文献' => '文献',
    'SOP' => 'SOP',
    _ => _defaultProtocolSourceType,
  };
  return _protocolSourceTypes.contains(normalized)
      ? normalized
      : _defaultProtocolSourceType;
}

String _defaultProtocolSourceTitle(String sourceType) {
  return _normalizeProtocolSourceType(sourceType) == _defaultProtocolSourceType
      ? '手动创建'
      : sourceType;
}

String _sourceTypeFromLegacyTitle(String title) {
  final prefix = title.split(':').first.trim();
  return _normalizeProtocolSourceType(prefix);
}

String _sourceTitleWithoutLegacyPrefix(String title) {
  final trimmed = title.trim();
  final separator = trimmed.indexOf(':');
  if (separator <= 0) return trimmed;
  final prefix = trimmed.substring(0, separator).trim();
  if (_normalizeProtocolSourceType(prefix) == _defaultProtocolSourceType &&
      prefix != _defaultProtocolSourceType) {
    return trimmed;
  }
  final suffix = trimmed.substring(separator + 1).trim();
  return suffix.isEmpty ? trimmed : suffix;
}

String _protocolSourceLabel(LabProtocol protocol) {
  return '${_normalizeProtocolSourceType(protocol.sourceType)} · ${protocol.sourceTitle}';
}

List<String> _formulaEditorUnitOptions(List<String> storeUnits) {
  return {
    'μl',
    'ml',
    'L',
    'ng',
    'μg',
    'mg',
    'g',
    'M',
    'mM',
    'μM',
    'nM',
    'ng/μl',
    'μg/μl',
    'μg/ml',
    'mg/ml',
    'g/mol',
    'Da',
    'kDa',
    '%',
    ...storeUnits,
  }.toList();
}

class _InlineUnitDropdown extends StatelessWidget {
  const _InlineUnitDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedOptions = {value, ...options}.where((item) {
      return item.trim().isNotEmpty;
    }).toList();
    return DropdownButtonFormField<String>(
      initialValue: normalizedOptions.contains(value)
          ? value
          : normalizedOptions.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: normalizedOptions
          .map(
            (unit) => DropdownMenuItem(
              value: unit,
              child: Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (unit) {
        if (unit != null) onChanged(unit);
      },
    );
  }
}

class _FormulaUnitDropdown extends StatelessWidget {
  const _FormulaUnitDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value.trim();
    final normalizedOptions = {
      '',
      normalizedValue,
      ...options,
    }.map((item) => item.trim()).toList();
    final seen = <String>{};
    final uniqueOptions = <String>[
      for (final option in normalizedOptions)
        if (seen.add(option)) option,
    ];
    return DropdownButtonFormField<String>(
      initialValue: uniqueOptions.contains(normalizedValue)
          ? normalizedValue
          : '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: uniqueOptions
          .map(
            (unit) => DropdownMenuItem(
              value: unit,
              child: Text(
                unit.isEmpty ? '无单位' : unit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (unit) {
        if (unit != null) onChanged(unit);
      },
    );
  }
}

class _ProtocolIngredientDraft {
  _ProtocolIngredientDraft({
    String? id,
    required String name,
    required String amount,
    required String unit,
  }) : id =
           id ??
           'ingredient-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(9999)}',
       nameController = TextEditingController(text: name),
       amountController = TextEditingController(text: amount),
       unitController = TextEditingController(text: unit);

  factory _ProtocolIngredientDraft.fromIngredient(ProtocolIngredient item) {
    return _ProtocolIngredientDraft(
      name: item.name,
      amount: _formatNumber(item.amount),
      unit: item.unit,
    );
  }

  final String id;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController unitController;

  ProtocolIngredient toIngredient() {
    return ProtocolIngredient(
      name: nameController.text.trim().isEmpty
          ? '试剂'
          : nameController.text.trim(),
      amount: double.tryParse(amountController.text.trim()) ?? 0,
      unit: unitController.text.trim(),
    );
  }

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    unitController.dispose();
  }
}

class _ProtocolVariableDraft {
  _ProtocolVariableDraft({
    String? id,
    required String symbol,
    required String name,
    required String value,
    required String unit,
    required bool scalable,
    String minValue = '',
    String maxValue = '',
  }) : id = id ?? _draftId('variable'),
       symbolController = TextEditingController(text: symbol),
       nameController = TextEditingController(text: name),
       valueController = TextEditingController(text: value),
       unitController = TextEditingController(text: unit),
       minController = TextEditingController(text: minValue),
       maxController = TextEditingController(text: maxValue),
       scalable = ValueNotifier<bool>(scalable);

  factory _ProtocolVariableDraft.fromVariable(ProtocolVariable variable) {
    return _ProtocolVariableDraft(
      id: variable.id,
      symbol: variable.symbol,
      name: variable.name,
      value: _formatNumber(variable.baseValue),
      unit: variable.unit,
      scalable: variable.isScalable,
      minValue: variable.minValue == null
          ? ''
          : _formatNumber(variable.minValue!),
      maxValue: variable.maxValue == null
          ? ''
          : _formatNumber(variable.maxValue!),
    );
  }

  final String id;
  final TextEditingController symbolController;
  final TextEditingController nameController;
  final TextEditingController valueController;
  final TextEditingController unitController;
  final TextEditingController minController;
  final TextEditingController maxController;
  final ValueNotifier<bool> scalable;

  ProtocolVariable toVariable() {
    final symbol = symbolController.text.trim();
    final fallbackSymbol = nameController.text.trim().isEmpty
        ? 'v'
        : _safeFormulaName(nameController.text.trim());
    return ProtocolVariable(
      id: id,
      symbol: symbol.isEmpty ? fallbackSymbol : _safeFormulaName(symbol),
      name: nameController.text.trim().isEmpty
          ? '变量'
          : nameController.text.trim(),
      baseValue: double.tryParse(valueController.text.trim()) ?? 0,
      unit: unitController.text.trim(),
      isScalable: scalable.value,
      minValue: double.tryParse(minController.text.trim()),
      maxValue: double.tryParse(maxController.text.trim()),
    );
  }

  void dispose() {
    symbolController.dispose();
    nameController.dispose();
    valueController.dispose();
    unitController.dispose();
    minController.dispose();
    maxController.dispose();
    scalable.dispose();
  }
}

class _ProtocolStepDraft {
  _ProtocolStepDraft({
    String? id,
    required String title,
    required String detail,
    String minutes = '',
    List<_ProtocolStepReagentDraft>? reagents,
  }) : id = id ?? _draftId('step'),
       titleController = TextEditingController(text: title),
       detailController = TextEditingController(text: detail),
       minutesController = TextEditingController(text: minutes),
       reagents = reagents ?? [];

  factory _ProtocolStepDraft.fromStep(LabStep step) {
    return _ProtocolStepDraft(
      id: step.id,
      title: step.title,
      detail: step.detail,
      minutes: step.durationMinutes?.toString() ?? '',
      reagents: step.reagents
          .map(_ProtocolStepReagentDraft.fromReagent)
          .toList(),
    );
  }

  final String id;
  final TextEditingController titleController;
  final TextEditingController detailController;
  final TextEditingController minutesController;
  final List<_ProtocolStepReagentDraft> reagents;

  LabStep toStep() {
    final minutes = int.tryParse(minutesController.text.trim());
    return LabStep(
      id: id,
      title: titleController.text.trim().isEmpty
          ? '步骤'
          : titleController.text.trim(),
      detail: detailController.text.trim(),
      durationMinutes: minutes == null || minutes <= 0 ? null : minutes,
      carryOver: false,
      reagents: reagents
          .map((draft) => draft.toReagent())
          .where((reagent) => reagent.name.trim().isNotEmpty)
          .toList(),
    );
  }

  void dispose() {
    titleController.dispose();
    detailController.dispose();
    minutesController.dispose();
    for (final reagent in reagents) {
      reagent.dispose();
    }
  }
}

class _ProtocolStepReagentDraft {
  _ProtocolStepReagentDraft({
    String? id,
    required String name,
    required String amountExpression,
    required String unit,
    required bool isFormula,
  }) : id = id ?? _draftId('reagent'),
       nameController = TextEditingController(text: name),
       amountController = TextEditingController(text: amountExpression),
       unitController = TextEditingController(text: unit),
       formulaMode = ValueNotifier<bool>(isFormula);

  factory _ProtocolStepReagentDraft.fromReagent(StepReagent reagent) {
    return _ProtocolStepReagentDraft(
      id: reagent.id,
      name: reagent.name,
      amountExpression: reagent.amountExpression,
      unit: reagent.unit,
      isFormula: reagent.isFormula,
    );
  }

  final String id;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController unitController;
  final ValueNotifier<bool> formulaMode;

  StepReagent toReagent() {
    return StepReagent(
      id: id,
      name: nameController.text.trim().isEmpty
          ? '试剂'
          : nameController.text.trim(),
      amountExpression: amountController.text.trim(),
      unit: unitController.text.trim(),
      isFormula: formulaMode.value,
    );
  }

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    unitController.dispose();
    formulaMode.dispose();
  }
}

class _ProtocolEditorSection extends StatelessWidget {
  const _ProtocolEditorSection({
    required this.title,
    required this.glyph,
    required this.children,
    this.onAdd,
    this.addButtonKey,
    this.addSemanticLabel = '添加',
  });

  final String title;
  final IosGlyph glyph;
  final List<Widget> children;
  final VoidCallback? onAdd;
  final Key? addButtonKey;
  final String addSemanticLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IosGlyphIcon(glyph, color: _teal, size: 21),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (onAdd != null)
                IosPlusCircleButton(
                  key: addButtonKey,
                  onPressed: onAdd!,
                  semanticLabel: addSemanticLabel,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            const Text('暂无条目', style: TextStyle(color: _muted))
          else
            ...children,
        ],
      ),
    );
  }
}

class _ProtocolConsistencyIssuePanel extends StatelessWidget {
  const _ProtocolConsistencyIssuePanel({required this.issues});

  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('protocol-consistency-issues-panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.orange, size: 19),
              SizedBox(width: 8),
              Text(
                '一致性检查',
                style: TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                issue,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProtocolIngredientDraftRow extends StatelessWidget {
  const _ProtocolIngredientDraftRow({
    required this.draft,
    required this.onChanged,
  });

  final _ProtocolIngredientDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextField(
              controller: draft.nameController,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(hintText: '成分名称'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: draft.amountController,
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: '用量'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: TextField(
              controller: draft.unitController,
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.right,
              decoration: const InputDecoration(hintText: '单位'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolUnitDefinitionPanel extends StatelessWidget {
  const _ProtocolUnitDefinitionPanel({
    required this.store,
    required this.activeUnit,
  });

  final LabStore store;
  final String activeUnit;

  @override
  Widget build(BuildContext context) {
    final units = _protocolUnitOptions(store.unitOptions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: units.take(12).map((unit) {
            return ChipLabel(
              text: unit,
              color: unit == activeUnit ? _teal : Colors.blueGrey,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                '这些单位会用于基准规模、配方、变量和步骤试剂。',
                style: TextStyle(color: _muted, fontSize: 12.5),
              ),
            ),
            TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => UnitManagementSheet(store: store),
              ),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('管理单位'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProtocolVariableDraftRow extends StatelessWidget {
  const _ProtocolVariableDraftRow({
    required this.draft,
    required this.unitOptions,
    required this.onChanged,
  });

  final _ProtocolVariableDraft draft;
  final List<String> unitOptions;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 86,
                child: TextField(
                  controller: draft.symbolController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: '公式符号',
                    hintText: 'cells',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.nameController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: '变量名称',
                    hintText: '目标细胞数',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: draft.scalable,
                builder: (context, scalable, _) {
                  return Semantics(
                    label: '随规模缩放',
                    toggled: scalable,
                    child: Switch.adaptive(
                      value: scalable,
                      activeThumbColor: _teal,
                      onChanged: (value) {
                        draft.scalable.value = value;
                        onChanged();
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.valueController,
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '基准值'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 104,
                child: _InlineUnitDropdown(
                  label: '单位',
                  value: draft.unitController.text.trim().isEmpty
                      ? (unitOptions.contains('ml') ? 'ml' : unitOptions.first)
                      : draft.unitController.text.trim(),
                  options: _protocolUnitOptions(unitOptions),
                  onChanged: (value) {
                    draft.unitController.text = value;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.minController,
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '最小值'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.maxController,
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '最大值'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '公式中使用：${_protocolVariableFormulaToken(draft)}',
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolStepDraftRow extends StatelessWidget {
  const _ProtocolStepDraftRow({
    required this.index,
    required this.draft,
    required this.variables,
    required this.defaultUnit,
    required this.onChanged,
  });

  final int index;
  final _ProtocolStepDraft draft;
  final List<_ProtocolVariableDraft> variables;
  final String defaultUnit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.titleController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(hintText: '步骤名称'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 62,
                child: TextField(
                  controller: draft.minutesController,
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'min'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: draft.detailController,
            onChanged: (_) => onChanged(),
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '操作描述'),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < draft.reagents.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ProtocolStepReagentDraftRow(
                key: ValueKey(draft.reagents[i].id),
                reagent: draft.reagents[i],
                variables: variables,
                onDelete: () {
                  final reagent = draft.reagents.removeAt(i);
                  reagent.dispose();
                  onChanged();
                },
                onChanged: onChanged,
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.reagents.add(
                  _ProtocolStepReagentDraft(
                    name: '新试剂',
                    amountExpression: '1',
                    unit: defaultUnit,
                    isFormula: false,
                  ),
                );
                onChanged();
              },
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('增加试剂'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtocolStepReagentDraftRow extends StatefulWidget {
  const _ProtocolStepReagentDraftRow({
    super.key,
    required this.reagent,
    required this.variables,
    required this.onDelete,
    required this.onChanged,
  });

  final _ProtocolStepReagentDraft reagent;
  final List<_ProtocolVariableDraft> variables;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  State<_ProtocolStepReagentDraftRow> createState() =>
      _ProtocolStepReagentDraftRowState();
}

class _ProtocolStepReagentDraftRowState
    extends State<_ProtocolStepReagentDraftRow> {
  Future<void> _openFormulaPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProtocolFormulaPickerSheet(
        variables: widget.variables,
        expressionController: widget.reagent.amountController,
        unitController: widget.reagent.unitController,
        onChanged: widget.onChanged,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('protocol-reagent-inline-delete-button'),
                tooltip: '删除试剂',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDelete,
                icon: Icon(
                  Icons.remove_circle,
                  color: Colors.red.withValues(alpha: 0.70),
                  size: 20,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: TextField(
                  controller: widget.reagent.nameController,
                  onChanged: (_) => widget.onChanged(),
                  decoration: const InputDecoration(hintText: '试剂名称'),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: widget.reagent.formulaMode,
                builder: (context, isFormula, _) {
                  return Tooltip(
                    message: isFormula ? '公式用量' : '固定用量',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        widget.reagent.formulaMode.value = !isFormula;
                        if (isFormula &&
                            double.tryParse(
                                  widget.reagent.amountController.text.trim(),
                                ) ==
                                null) {
                          widget.reagent.amountController.clear();
                        }
                        widget.onChanged();
                        setState(() {});
                      },
                      icon: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isFormula
                              ? _teal
                              : _muted.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: widget.reagent.formulaMode,
                  builder: (context, isFormula, _) {
                    if (!isFormula) {
                      return TextField(
                        controller: widget.reagent.amountController,
                        onChanged: (_) => widget.onChanged(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(hintText: '用量'),
                      );
                    }
                    final preview = _formulaPreview(
                      widget.reagent.amountController.text,
                      widget.variables,
                      widget.reagent.unitController.text,
                    );
                    final isEmpty = widget.reagent.amountController.text
                        .trim()
                        .isEmpty;
                    final label = isEmpty ? '输入公式' : preview;
                    return TextButton(
                      onPressed: _openFormulaPicker,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isEmpty
                              ? _teal.withValues(alpha: 0.55)
                              : preview == '无法计算'
                              ? Colors.orange
                              : _teal,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: widget.reagent.formulaMode,
                builder: (context, isFormula, _) {
                  if (isFormula) {
                    return SizedBox(
                      width: 68,
                      child: TextButton(
                        onPressed: _openFormulaPicker,
                        style: TextButton.styleFrom(
                          foregroundColor: _muted,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(widget.reagent.unitController.text.trim()),
                      ),
                    );
                  }
                  return SizedBox(
                    width: 68,
                    child: TextField(
                      controller: widget.reagent.unitController,
                      onChanged: (_) => widget.onChanged(),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(hintText: '单位'),
                    ),
                  );
                },
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.reagent.formulaMode,
            builder: (context, isFormula, _) {
              if (!isFormula || widget.variables.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.variables.take(4).map((variable) {
                    final token = _protocolVariableFormulaToken(variable);
                    final label = _protocolVariableDisplayName(variable);
                    return ActionChip(
                      label: Text(label),
                      onPressed: () {
                        widget.reagent.amountController.text +=
                            widget.reagent.amountController.text.trim().isEmpty
                            ? token
                            : ' * $token';
                        widget.onChanged();
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProtocolFormulaPickerSheet extends StatefulWidget {
  const _ProtocolFormulaPickerSheet({
    required this.variables,
    required this.expressionController,
    required this.unitController,
    required this.onChanged,
  });

  final List<_ProtocolVariableDraft> variables;
  final TextEditingController expressionController;
  final TextEditingController unitController;
  final VoidCallback onChanged;

  @override
  State<_ProtocolFormulaPickerSheet> createState() =>
      _ProtocolFormulaPickerSheetState();
}

class _ProtocolFormulaPickerSheetState
    extends State<_ProtocolFormulaPickerSheet> {
  late final TextEditingController draftController;

  @override
  void initState() {
    super.initState();
    draftController = TextEditingController(
      text: widget.expressionController.text,
    );
  }

  @override
  void dispose() {
    draftController.dispose();
    super.dispose();
  }

  String get _preview => _formulaPreview(
    draftController.text,
    widget.variables,
    widget.unitController.text,
  );

  void _append(String token) {
    draftController.text += token;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final preview = draftController.text.trim().isEmpty ? '—' : _preview;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '插入公式',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    widget.expressionController.text = draftController.text;
                    widget.onChanged();
                    Navigator.pop(context);
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _labPanel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          style: TextStyle(
                            color: preview == '无法计算' ? Colors.orange : _teal,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const Text('单位', style: TextStyle(color: _muted)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: TextField(
                          controller: widget.unitController,
                          onChanged: (_) => setState(widget.onChanged),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(hintText: '单位'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: draftController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '输入公式，如：总体积 * 0.9',
                      suffixIcon: draftController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空公式',
                              onPressed: () {
                                draftController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.cancel),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ProtocolEditorSection(
              title: '点击插入变量',
              glyph: IosGlyph.function,
              children: widget.variables.map((variable) {
                final token = _protocolVariableFormulaToken(variable);
                final label = _protocolVariableDisplayName(variable);
                final value =
                    double.tryParse(variable.valueController.text.trim()) ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      draftController.text +=
                          draftController.text.trim().isEmpty
                          ? token
                          : ' * $token';
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '基准值：${_formatNumber(value)} ${variable.unitController.text.trim()}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.add_circle_outline, color: _teal),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _ProtocolEditorSection(
              title: '运算符',
              glyph: IosGlyph.function,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['×', '÷', '+', '−', '(', ')'].map((label) {
                    final op = switch (label) {
                      '×' => ' * ',
                      '÷' => ' / ',
                      '+' => ' + ',
                      '−' => ' - ',
                      _ => label,
                    };
                    return ActionChip(
                      label: Text(label),
                      onPressed: () => _append(op),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key, required this.store});

  final LabStore store;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class ToolEntryTile extends StatelessWidget {
  const ToolEntryTile({
    super.key,
    required this.glyph,
    required this.title,
    required this.subtitle,
    this.tint = _teal,
    this.lastResult,
    this.onTap,
  });

  final IosGlyph glyph;
  final String title;
  final String subtitle;
  final Color tint;
  final String? lastResult;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: IosGlyphIcon(glyph, color: tint, size: 24),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (lastResult != null && lastResult!.trim().isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lastResult!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: tint,
                            fontSize: 11.5,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          '最近',
                          style: TextStyle(
                            color: _muted.withValues(alpha: 0.64),
                            fontSize: 10.5,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                IosGlyphIcon(
                  IosGlyph.chevronRight,
                  color: _muted.withValues(alpha: 0.42),
                  size: 25,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BufferTemplateLibraryTile extends StatelessWidget {
  const BufferTemplateLibraryTile({
    super.key,
    required this.template,
    required this.onTap,
  });

  final BufferTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _areaBadgeColor(template.area);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _iosBufferTitle(template.name),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 15,
                              height: 1.08,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              template.area,
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '基准 ${_iosBaseVolume(template)}',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IosGlyphIcon(
                  IosGlyph.chevronRight,
                  color: _muted.withValues(alpha: 0.45),
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _iosBufferTitle(String name) {
  if (name == 'Complete DMEM') return 'DMEM 完全培养基';
  if (name == 'WB Transfer Buffer') return 'WB 转膜液';
  if (name == '5% Skim Milk TBST') return '5% 脱脂奶粉 TBST';
  if (name == 'RIPA Lysis Buffer') return 'RIPA 裂解液 工作液';
  return name;
}

String _iosBaseVolume(BufferTemplate template) {
  final value = template.baseVolume >= 1000
      ? template.baseVolume
            .toStringAsFixed(0)
            .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')
      : _formatNumber(template.baseVolume);
  return '$value ${template.volumeUnit}';
}

class _ToolsScreenState extends State<ToolsScreen> {
  final massController = TextEditingController(text: '1');
  final concentrationController = TextEditingController(text: '2');
  final volumeController = TextEditingController(text: '50');
  final stockController = TextEditingController(text: '1000');
  final targetController = TextEditingController(text: '100');
  final finalVolumeController = TextEditingController(text: '10');
  final percentController = TextEditingController(text: '10');
  final percentVolumeController = TextEditingController(text: '200');
  final transfectionDnaController = TextEditingController(text: '2');
  final peiRatioController = TextEditingController(text: '3');
  String selectedTransfectionPreset = '6-well';
  late final List<_TransfectionDoseDraft> transfectionDoses = [
    _TransfectionDoseDraft(
      vessel: '96 孔板',
      area: '0.3',
      dna: '0.1',
      reagent: '0.1',
      diluent: '10',
      medium: '100 μl',
    ),
    _TransfectionDoseDraft(
      vessel: '48 孔板',
      area: '0.7',
      dna: '0.2',
      reagent: '0.3',
      diluent: '20',
      medium: '200 μl',
    ),
    _TransfectionDoseDraft(
      vessel: '24 孔板',
      area: '1.9',
      dna: '0.5',
      reagent: '1',
      diluent: '50',
      medium: '500 μl',
    ),
    _TransfectionDoseDraft(
      vessel: '12 孔板',
      area: '3.8',
      dna: '1',
      reagent: '2',
      diluent: '50',
      medium: '1 ml',
    ),
    _TransfectionDoseDraft(
      vessel: '6-well',
      area: '10',
      dna: '2',
      reagent: '4',
      diluent: '100',
      medium: '2 ml',
    ),
    _TransfectionDoseDraft(
      vessel: '25 cm² 瓶',
      area: '21',
      dna: '4',
      reagent: '8',
      diluent: '200',
      medium: '4 ml',
    ),
    _TransfectionDoseDraft(
      vessel: '10 cm dish',
      area: '58',
      dna: '10',
      reagent: '20',
      diluent: '500',
      medium: '10 ml',
    ),
  ];
  late final List<_TransfectionPlasmidGroupDraft> transfectionPlasmidGroups = [
    _TransfectionPlasmidGroupDraft(
      title: '目的质粒',
      plasmids: [
        _TransfectionPlasmidDraft(
          name: 'Transfer plasmid',
          ratio: '4',
          ratioGroup: 'target-only',
        ),
      ],
    ),
    _TransfectionPlasmidGroupDraft(
      title: '辅助质粒',
      plasmids: [
        _TransfectionPlasmidDraft(
          name: 'psPAX2',
          ratio: '3',
          ratioGroup: 'helper-packaging',
        ),
      ],
    ),
    _TransfectionPlasmidGroupDraft(
      title: '包膜质粒',
      plasmids: [
        _TransfectionPlasmidDraft(
          name: 'pCMV-VSVG',
          ratio: '1',
          ratioGroup: 'envelope',
        ),
      ],
    ),
  ];

  List<_TransfectionPlasmidDraft> get transfectionPlasmids =>
      transfectionPlasmidGroups.expand((group) => group.plasmids).toList();

  @override
  void dispose() {
    for (final controller in [
      massController,
      concentrationController,
      volumeController,
      stockController,
      targetController,
      finalVolumeController,
      percentController,
      percentVolumeController,
      transfectionDnaController,
      peiRatioController,
    ]) {
      controller.dispose();
    }
    for (final group in transfectionPlasmidGroups) {
      group.dispose();
    }
    for (final dose in transfectionDoses) {
      dose.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, _iosToolsTopOffset, 18, 108),
          children: [
            Text(
              '计算工具',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 10),
            ToolEntryTile(
              glyph: IosGlyph.beaker,
              title: '质量浓度',
              subtitle: 'MW × M × L → 称量质量',
              tint: _ToolCalcMode.mass.tint,
              lastResult: _lastResultFor(_ToolCalcMode.mass),
              onTap: () => _showBasicCalculator(context, _ToolCalcMode.mass),
            ),
            ToolEntryTile(
              glyph: IosGlyph.drop,
              title: '液体稀释',
              subtitle: 'C1V1 = C2V2 → 取母液量',
              tint: _ToolCalcMode.dilution.tint,
              lastResult: _lastResultFor(_ToolCalcMode.dilution),
              onTap: () =>
                  _showBasicCalculator(context, _ToolCalcMode.dilution),
            ),
            ToolEntryTile(
              glyph: IosGlyph.percent,
              title: '百分比浓度',
              subtitle: 'w/v 或 v/v → 溶质质量',
              tint: _ToolCalcMode.percent.tint,
              lastResult: _lastResultFor(_ToolCalcMode.percent),
              onTap: () => _showBasicCalculator(context, _ToolCalcMode.percent),
            ),
            ToolEntryTile(
              glyph: IosGlyph.waveform,
              title: 'PEI 转染配方',
              subtitle: 'DNA 比例 + 浓度 → 质粒/PEI 体积',
              tint: _ToolCalcMode.transfection.tint,
              lastResult: _lastResultFor(_ToolCalcMode.transfection),
              onTap: () =>
                  _showBasicCalculator(context, _ToolCalcMode.transfection),
            ),
            ToolEntryTile(
              glyph: IosGlyph.sqrt,
              title: '自定义公式',
              subtitle: '自由定义公式与变量 → 即时计算',
              tint: const Color(0xFF5856D6),
              onTap: () => _showFormulaEditor(context),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '常用缓冲液 · 培养基模板',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                IosPlusCircleButton(
                  onPressed: () => _showBufferEditor(context),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ...widget.store.bufferTemplates.map((template) {
              final tile = BufferTemplateLibraryTile(
                template: template,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BufferTemplateScreen(
                      store: widget.store,
                      template: template,
                    ),
                  ),
                ),
              );
              if (_isSampleBufferTemplateId(template.id)) return tile;
              return IosSwipeDelete(
                key: ValueKey('buffer-${template.id}'),
                confirmTitle: '删除模板？',
                confirmMessage:
                    '删除「${_iosBufferTitle(template.name)}」后，这个缓冲液模板会从工具页移除。',
                onDelete: () async {
                  await widget.store.deleteBufferTemplate(template.id);
                  if (mounted) setState(() {});
                },
                child: tile,
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '已保存的公式',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                IosPlusCircleButton(
                  onPressed: () => _showFormulaEditor(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.store.savedFormulas.isEmpty)
              const EmptyState(
                icon: Icons.functions,
                title: '暂无自定义公式',
                body: '把常用公式保存下来，下次直接输入变量即可计算。',
              )
            else
              ...widget.store.savedFormulas.map(
                (formula) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IosSwipeDelete(
                    key: ValueKey('formula-${formula.id}'),
                    confirmTitle: '删除公式？',
                    confirmMessage: '删除「${formula.label}」后，这个自定义公式会从工具页移除。',
                    onDelete: () async {
                      await widget.store.deleteSavedFormula(formula.id);
                      if (mounted) setState(() {});
                    },
                    child: SavedFormulaTile(
                      formula: formula,
                      onTap: () => _showFormulaEditor(context, formula),
                      onEdit: () => _showFormulaEditor(context, formula),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '历史',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (widget.store.calcHistory.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await widget.store.clearCalcHistory();
                      if (mounted) setState(() {});
                    },
                    child: const Text('清空'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.store.calcHistory.isEmpty)
              const EmptyState(
                icon: Icons.history,
                title: '暂无计算历史',
                body: '保存计算结果后会出现在这里。',
              )
            else
              ...widget.store.calcHistory
                  .take(8)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CalcHistoryTile(
                        item: item,
                        onTap: () => _restoreHistoryItem(context, item),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  double _double(String value) => double.tryParse(value) ?? 0;

  String? _lastResultFor(_ToolCalcMode mode) {
    return widget.store.calcHistory
        .where((item) => item.title == mode.historyTitle)
        .firstOrNull
        ?.result;
  }

  Future<void> _showBasicCalculator(
    BuildContext context,
    _ToolCalcMode mode,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final card = _calculatorCardForMode(mode, () => setSheetState(() {}));
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.close,
                        tooltip: '关闭',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        mode.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      const SizedBox(width: 38),
                    ],
                  ),
                  const SizedBox(height: 14),
                  card,
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _restoreHistoryItem(
    BuildContext context,
    CalcHistoryItem item,
  ) async {
    final modeName = item.mode;
    if (modeName == null || item.inputs.isEmpty) return;
    if (modeName == 'custom') {
      final formula = widget.store.savedFormulas
          .where((formula) => formula.label == item.title)
          .firstOrNull;
      if (formula == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FormulaRunnerScreen(
            store: widget.store,
            formula: formula,
            initialInputs: item.inputs,
          ),
        ),
      );
      if (mounted) setState(() {});
      return;
    }
    final mode = _ToolCalcMode.values
        .where((value) => value.name == modeName)
        .firstOrNull;
    if (mode == null) return;
    _applyHistoryInputs(mode, item.inputs);
    await _showBasicCalculator(context, mode);
  }

  void _applyHistoryInputs(_ToolCalcMode mode, Map<String, double> inputs) {
    void setValue(TextEditingController controller, String key) {
      final value = inputs[key];
      if (value != null) controller.text = _formatNumber(value);
    }

    switch (mode) {
      case _ToolCalcMode.mass:
        setValue(massController, 'amount');
        setValue(concentrationController, 'concentration');
      case _ToolCalcMode.dilution:
        setValue(stockController, 'stock');
        setValue(targetController, 'target');
        setValue(finalVolumeController, 'finalVolume');
      case _ToolCalcMode.percent:
        setValue(percentController, 'percent');
        setValue(percentVolumeController, 'volume');
      case _ToolCalcMode.transfection:
        setValue(transfectionDnaController, 'dnaTotal');
        setValue(peiRatioController, 'peiRatio');
    }
  }

  Widget _calculatorCardForMode(
    _ToolCalcMode mode,
    VoidCallback setSheetState,
  ) {
    final mass =
        _double(massController.text) * _double(concentrationController.text);
    final dilution = _double(stockController.text) == 0
        ? 0
        : _double(targetController.text) *
              _double(finalVolumeController.text) /
              _double(stockController.text);
    final percentMass =
        _double(percentController.text) *
        _double(percentVolumeController.text) /
        100;
    CalcField field(
      TextEditingController controller,
      String label,
      String suffix,
    ) {
      return CalcField(
        controller: controller,
        label: label,
        suffix: suffix,
        onChanged: (_) => setSheetState(),
      );
    }

    switch (mode) {
      case _ToolCalcMode.mass:
        return CalculatorCard(
          title: '质量计算',
          subtitle: 'mass = amount × concentration',
          tint: mode.tint,
          fields: [
            field(massController, 'Amount', 'ml'),
            field(concentrationController, 'Concentration', 'mg/ml'),
          ],
          result: '${mass.toStringAsFixed(2)} mg',
          onSave: () => widget.store.addCalcHistory(
            '质量计算',
            '${mass.toStringAsFixed(2)} mg',
            mode: mode.name,
            inputs: _historyInputsForMode(mode),
          ),
        );
      case _ToolCalcMode.dilution:
        return CalculatorCard(
          title: '稀释计算 C1V1=C2V2',
          subtitle: '根据库存浓度计算加入体积',
          tint: mode.tint,
          fields: [
            field(stockController, 'C1 stock', 'mM'),
            field(targetController, 'C2 target', 'mM'),
            field(finalVolumeController, 'V2 final', 'ml'),
          ],
          result: '${dilution.toStringAsFixed(2)} ml stock',
          onSave: () => widget.store.addCalcHistory(
            '稀释计算',
            '${dilution.toStringAsFixed(2)} ml stock',
            mode: mode.name,
            inputs: _historyInputsForMode(mode),
          ),
        );
      case _ToolCalcMode.percent:
        return CalculatorCard(
          title: '百分比溶液',
          subtitle: 'w/v: g per 100 ml',
          tint: mode.tint,
          fields: [
            field(percentController, 'Percent', '%'),
            field(percentVolumeController, 'Volume', 'ml'),
          ],
          result: '${percentMass.toStringAsFixed(2)} g',
          onSave: () => widget.store.addCalcHistory(
            '百分比溶液',
            '${percentMass.toStringAsFixed(2)} g',
            mode: mode.name,
            inputs: _historyInputsForMode(mode),
          ),
        );
      case _ToolCalcMode.transfection:
        final transfectionResult = _transfectionResult();
        return CalculatorCard(
          title: 'PEI 转染配方',
          subtitle: '培养皿剂量 + 动态质粒比例 + PEI:DNA → 加样体积',
          tint: mode.tint,
          fields: [
            _TransfectionPresetPicker(
              selected: selectedTransfectionPreset,
              doses: transfectionDoses,
              onSelected: (dose) {
                selectedTransfectionPreset = dose.vessel;
                transfectionDnaController.text = _formatNumber(dose.dnaUg);
                setSheetState();
              },
            ),
            field(transfectionDnaController, 'DNA total', 'μg'),
            field(peiRatioController, 'PEI:DNA', 'μl/μg'),
            _TransfectionPlasmidEditor(
              groups: transfectionPlasmidGroups,
              onChanged: setSheetState,
              onAddGroup: () {
                transfectionPlasmidGroups.add(
                  _TransfectionPlasmidGroupDraft(
                    title: '质粒分组 ${transfectionPlasmidGroups.length + 1}',
                    plasmids: [
                      _TransfectionPlasmidDraft(
                        name: '新质粒',
                        ratio: '1',
                        concentration: '1000',
                      ),
                    ],
                  ),
                );
                setSheetState();
              },
              onDeleteGroup: (group) {
                if (transfectionPlasmidGroups.length <= 1) return;
                transfectionPlasmidGroups.remove(group);
                group.dispose();
                setSheetState();
              },
              onAddPlasmid: (group) {
                group.plasmids.add(
                  _TransfectionPlasmidDraft(
                    name: '质粒 ${group.plasmids.length + 1}',
                    ratio: '1',
                    concentration: '1000',
                  ),
                );
                setSheetState();
              },
              onDeletePlasmid: (group, draft) {
                if (transfectionPlasmids.length <= 1) return;
                group.plasmids.remove(draft);
                draft.dispose();
                setSheetState();
              },
            ),
            _TransfectionReferenceTable(
              doses: transfectionDoses,
              onAdd: () async {
                final draft = _TransfectionDoseDraft(
                  vessel: '新培养皿',
                  area: '',
                  dna: '1',
                  reagent: '',
                  diluent: '',
                  medium: '',
                );
                final saved = await _showTransfectionDoseEditor(
                  context,
                  draft,
                  canDelete: false,
                );
                if (saved == null) {
                  draft.dispose();
                  return;
                }
                transfectionDoses.add(saved);
                selectedTransfectionPreset = saved.vessel;
                transfectionDnaController.text = _formatNumber(saved.dnaUg);
                setSheetState();
              },
              onEdit: (dose) async {
                final saved = await _showTransfectionDoseEditor(
                  context,
                  dose,
                  canDelete: transfectionDoses.length > 1,
                  onDelete: () {
                    transfectionDoses.remove(dose);
                    if (selectedTransfectionPreset == dose.vessel &&
                        transfectionDoses.isNotEmpty) {
                      selectedTransfectionPreset =
                          transfectionDoses.last.vessel;
                      transfectionDnaController.text = _formatNumber(
                        transfectionDoses.last.dnaUg,
                      );
                    }
                    dose.dispose();
                  },
                );
                if (saved == null) {
                  setSheetState();
                  return;
                }
                selectedTransfectionPreset = saved.vessel;
                transfectionDnaController.text = _formatNumber(saved.dnaUg);
                setSheetState();
              },
            ),
          ],
          result: transfectionResult,
          onSave: () => widget.store.addCalcHistory(
            'PEI 转染配方',
            transfectionResult,
            mode: mode.name,
            inputs: _historyInputsForMode(mode),
          ),
        );
    }
  }

  Map<String, double> _historyInputsForMode(_ToolCalcMode mode) {
    return switch (mode) {
      _ToolCalcMode.mass => {
        'amount': _double(massController.text),
        'concentration': _double(concentrationController.text),
      },
      _ToolCalcMode.dilution => {
        'stock': _double(stockController.text),
        'target': _double(targetController.text),
        'finalVolume': _double(finalVolumeController.text),
      },
      _ToolCalcMode.percent => {
        'percent': _double(percentController.text),
        'volume': _double(percentVolumeController.text),
      },
      _ToolCalcMode.transfection => {
        'dnaTotal': _double(transfectionDnaController.text),
        'peiRatio': _double(peiRatioController.text),
      },
    };
  }

  String _transfectionResult() {
    final totalDna = _double(transfectionDnaController.text);
    final peiRatio = _double(peiRatioController.text);
    final ratioTotals = <String, double>{};
    for (final plasmid in transfectionPlasmids) {
      final group = plasmid.ratioGroup.value;
      ratioTotals[group] =
          (ratioTotals[group] ?? 0) + _double(plasmid.ratioController.text);
    }
    final lines = <String>[];
    for (final plasmid in transfectionPlasmids) {
      final ratio = _double(plasmid.ratioController.text);
      final totalRatio = ratioTotals[plasmid.ratioGroup.value] ?? 0;
      final concentrationNgUl = _double(plasmid.concentrationController.text);
      final dnaUg = totalRatio == 0 ? 0 : totalDna * ratio / totalRatio;
      final concentrationUgUl = concentrationNgUl / 1000;
      final volumeUl = concentrationUgUl == 0 ? 0 : dnaUg / concentrationUgUl;
      final name = plasmid.nameController.text.trim().isEmpty
          ? '质粒'
          : plasmid.nameController.text.trim();
      final groupLabel =
          _transfectionRatioGroups[plasmid.ratioGroup.value] ?? '总 DNA';
      lines.add('$name ${volumeUl.toStringAsFixed(2)} μl ($groupLabel)');
    }
    lines.add('PEI ${(totalDna * peiRatio).toStringAsFixed(2)} μl');
    lines.add('Preset $selectedTransfectionPreset');
    return lines.join(' · ');
  }

  Future<_TransfectionDoseDraft?> _showTransfectionDoseEditor(
    BuildContext context,
    _TransfectionDoseDraft dose, {
    required bool canDelete,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet<_TransfectionDoseDraft?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransfectionDoseEditorSheet(
        dose: dose,
        canDelete: canDelete,
        onDelete: onDelete ?? () {},
      ),
    );
  }

  Future<void> _showBufferEditor(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BufferTemplateEditorSheet(store: widget.store),
    );
  }

  Future<void> _showFormulaEditor(
    BuildContext context, [
    SavedFormula? formula,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          FormulaEditorSheet(store: widget.store, existing: formula),
    );
  }
}

enum _ToolCalcMode {
  mass('质量浓度'),
  dilution('液体稀释'),
  percent('百分比浓度'),
  transfection('PEI 转染配方');

  const _ToolCalcMode(this.title);
  final String title;

  String get historyTitle => switch (this) {
    _ToolCalcMode.mass => '质量计算',
    _ToolCalcMode.dilution => '稀释计算',
    _ToolCalcMode.percent => '百分比溶液',
    _ToolCalcMode.transfection => 'PEI 转染配方',
  };

  Color get tint => switch (this) {
    _ToolCalcMode.mass => _teal,
    _ToolCalcMode.dilution => const Color(0xFF007AFF),
    _ToolCalcMode.percent => const Color(0xFFFF9500),
    _ToolCalcMode.transfection => const Color(0xFF5856D6),
  };
}

class BufferTemplateScreen extends StatefulWidget {
  const BufferTemplateScreen({
    super.key,
    required this.store,
    required this.template,
  });

  final LabStore store;
  final BufferTemplate template;

  @override
  State<BufferTemplateScreen> createState() => _BufferTemplateScreenState();
}

class _BufferTemplateScreenState extends State<BufferTemplateScreen> {
  late final TextEditingController targetController;
  late final TextEditingController nameController;
  late String targetUnit;
  late List<_BufferIngredientDraft> ingredients;

  BufferTemplate get template =>
      widget.store.bufferTemplates
          .where((item) => item.id == widget.template.id)
          .firstOrNull ??
      widget.template;

  double get targetVolume {
    final parsed = double.tryParse(targetController.text.trim());
    if (parsed == null || parsed <= 0) return template.baseVolume;
    return parsed;
  }

  double get targetVolumeInBaseUnit {
    final converted = _convertFormulaUnitValue(
      targetVolume,
      targetUnit,
      template.volumeUnit,
    );
    return converted ?? targetVolume;
  }

  double get scaleFactor => template.baseVolume <= 0
      ? 1
      : targetVolumeInBaseUnit / template.baseVolume;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.template.name);
    targetController = TextEditingController(
      text: _formatNumber(widget.template.baseVolume),
    );
    targetUnit = widget.template.volumeUnit;
    ingredients = widget.template.ingredients
        .map(_BufferIngredientDraft.fromIngredient)
        .toList();
  }

  @override
  void dispose() {
    nameController.dispose();
    targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.close,
                    tooltip: '关闭',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    '配方缩放',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  _CircleIconButton(
                    icon: Icons.save_outlined,
                    tooltip: '保存模板',
                    onTap: _saveTemplateEdits,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _labPanel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              hintText: '模板名称',
                              border: InputBorder.none,
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChipLabel(
                                text: template.area,
                                color: _areaBadgeColor(template.area),
                              ),
                              ChipLabel(
                                text:
                                    '基准 ${_formatNumber(template.baseVolume)} ${template.volumeUnit}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _mint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'x${scaleFactor.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _labPanel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '目标体积',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: targetController,
                      decoration: InputDecoration(
                        labelText: '目标体积',
                        suffixIcon: PopupMenuButton<String>(
                          tooltip: '选择体积单位',
                          onSelected: (value) =>
                              setState(() => targetUnit = value),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'ml', child: Text('ml')),
                            PopupMenuItem(value: 'L', child: Text('L')),
                            PopupMenuItem(value: 'μl', child: Text('μl')),
                          ],
                          child: ChipLabel(text: targetUnit),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              targetController.text = _formatNumber(
                                template.baseVolume,
                              );
                              setState(() {});
                            },
                            child: const Text('重置'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _copyRecipe,
                            child: const Text('复制配方'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _labPanel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '配方',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        IosPlusCircleButton(onPressed: _addIngredient),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (ingredients.isEmpty)
                      TextButton.icon(
                        onPressed: _addIngredient,
                        icon: const Icon(Icons.add_circle),
                        label: const Text('添加配方成分'),
                      ),
                    ...ingredients.map(
                      (ingredient) => IosSwipeDelete(
                        key: ValueKey('scale-${ingredient.id}'),
                        confirmTitle: '删除配方成分？',
                        confirmMessage: '删除后，保存模板时不会再包含这个成分。',
                        onDelete: () async => _removeIngredient(ingredient.id),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _editIngredient(ingredient),
                          child: _RecipeScaleRow(
                            name: ingredient.name,
                            subtitle: ingredient.scalable ? '随目标体积缩放' : '固定用量',
                            amount:
                                '${_formatNumber(ingredient.scalable ? ingredient.amount * scaleFactor : ingredient.amount)} ${ingredient.unit}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addIngredient() async {
    final draft = await showModalBottomSheet<_BufferIngredientDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BufferIngredientEditorSheet(
        initial: _BufferIngredientDraft(
          name: '新成分',
          amount: 1,
          unit: template.volumeUnit,
          scalable: true,
        ),
      ),
    );
    if (draft == null) return;
    setState(() => ingredients.add(draft));
  }

  Future<void> _editIngredient(_BufferIngredientDraft ingredient) async {
    final updated = await showModalBottomSheet<_BufferIngredientDraft?>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _BufferIngredientEditorSheet(initial: ingredient, canDelete: true),
    );
    if (updated == null) return;
    setState(() {
      final index = ingredients.indexWhere((item) => item.id == ingredient.id);
      if (index >= 0) ingredients[index] = updated;
    });
  }

  void _removeIngredient(String id) {
    setState(() => ingredients.removeWhere((item) => item.id == id));
  }

  Future<void> _saveTemplateEdits() async {
    await widget.store.upsertBufferTemplate(
      template.copyWith(
        name: nameController.text.trim().isEmpty
            ? template.name
            : nameController.text.trim(),
        baseVolume: targetVolume,
        volumeUnit: targetUnit,
        ingredients: ingredients.map((item) => item.toIngredient()).toList(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('模板已保存')));
  }

  Future<void> _copyRecipe() async {
    final text = ingredients
        .map((ingredient) {
          final amount = ingredient.scalable
              ? ingredient.amount * scaleFactor
              : ingredient.amount;
          return '${ingredient.name}: ${_formatNumber(amount)} ${ingredient.unit}';
        })
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配方已复制')));
    }
  }
}

class BufferTemplateEditorSheet extends StatefulWidget {
  const BufferTemplateEditorSheet({
    super.key,
    required this.store,
    this.existing,
  });

  final LabStore store;
  final BufferTemplate? existing;

  @override
  State<BufferTemplateEditorSheet> createState() =>
      _BufferTemplateEditorSheetState();
}

class _BufferTemplateEditorSheetState extends State<BufferTemplateEditorSheet> {
  late final TextEditingController nameController;
  late final TextEditingController baseVolumeController;
  late final TextEditingController volumeUnitController;
  late List<_BufferIngredientDraft> ingredients;
  String area = '细胞实验';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    nameController = TextEditingController(text: existing?.name ?? '新缓冲液模板');
    baseVolumeController = TextEditingController(
      text: _formatNumber(existing?.baseVolume ?? 100),
    );
    volumeUnitController = TextEditingController(
      text: existing?.volumeUnit ?? 'ml',
    );
    ingredients =
        existing?.ingredients
            .map(_BufferIngredientDraft.fromIngredient)
            .toList() ??
        [
          _BufferIngredientDraft(
            name: '成分A',
            amount: 10,
            unit: 'ml',
            scalable: true,
          ),
        ];
    area = existing?.area ?? '细胞实验';
  }

  @override
  void dispose() {
    nameController.dispose();
    baseVolumeController.dispose();
    volumeUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.existing == null ? '新增模板' : '编辑模板',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '模板名称'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: area,
              decoration: const InputDecoration(labelText: '实验类型'),
              items: widget.store.areaOptions
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => area = value ?? area),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: baseVolumeController,
                    decoration: const InputDecoration(labelText: '基准体积'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: volumeUnitController,
                    decoration: const InputDecoration(labelText: '体积单位'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _FormulaEditorSection(
              title: '配方成分',
              glyph: IosGlyph.beaker,
              onAdd: _addIngredient,
              child: Column(
                children: [
                  if (ingredients.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('暂无成分', style: TextStyle(color: _muted)),
                    ),
                  for (var i = 0; i < ingredients.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: IosSwipeDelete(
                        key: ValueKey(ingredients[i].id),
                        confirmTitle: '删除配方成分？',
                        confirmMessage: '删除后，保存模板时不会再包含这个成分。',
                        onDelete: () async => _removeIngredient(i),
                        child: _BufferIngredientDraftRow(
                          draft: ingredients[i],
                          onTap: () => _editIngredient(ingredients[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                final template = BufferTemplate(
                  id:
                      widget.existing?.id ??
                      'buffer-${DateTime.now().microsecondsSinceEpoch}',
                  name: nameController.text.trim().isEmpty
                      ? '新缓冲液模板'
                      : nameController.text.trim(),
                  area: area,
                  baseVolume:
                      double.tryParse(baseVolumeController.text.trim()) ?? 100,
                  volumeUnit: volumeUnitController.text.trim().isEmpty
                      ? 'ml'
                      : volumeUnitController.text.trim(),
                  ingredients: ingredients
                      .map((draft) => draft.toIngredient())
                      .where((item) => item.name.trim().isNotEmpty)
                      .toList(),
                );
                await widget.store.upsertBufferTemplate(template);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.save),
              label: const Text('保存模板'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addIngredient() async {
    final draft = await showModalBottomSheet<_BufferIngredientDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BufferIngredientEditorSheet(
        initial: _BufferIngredientDraft(
          name: '新成分',
          amount: 1,
          unit: volumeUnitController.text.trim().isEmpty
              ? 'ml'
              : volumeUnitController.text.trim(),
          scalable: true,
        ),
      ),
    );
    if (draft == null) return;
    setState(() => ingredients.add(draft));
  }

  Future<void> _editIngredient(_BufferIngredientDraft ingredient) async {
    final updated = await showModalBottomSheet<_BufferIngredientDraft?>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _BufferIngredientEditorSheet(initial: ingredient, canDelete: true),
    );
    if (updated == null) return;
    setState(() {
      final index = ingredients.indexWhere((item) => item.id == ingredient.id);
      if (index >= 0) ingredients[index] = updated;
    });
  }

  void _removeIngredient(int index) {
    setState(() => ingredients.removeAt(index));
  }
}

class _BufferIngredientDraft {
  _BufferIngredientDraft({
    String? id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.scalable,
  }) : id = id ?? _draftId('buffer-ing');

  factory _BufferIngredientDraft.fromIngredient(BufferIngredient ingredient) {
    return _BufferIngredientDraft(
      id: ingredient.id,
      name: ingredient.name,
      amount: ingredient.amount,
      unit: ingredient.unit,
      scalable: ingredient.scalable,
    );
  }

  final String id;
  final String name;
  final double amount;
  final String unit;
  final bool scalable;

  BufferIngredient toIngredient() => BufferIngredient(
    id: id,
    name: name,
    amount: amount,
    unit: unit,
    scalable: scalable,
  );
}

class _BufferIngredientDraftRow extends StatelessWidget {
  const _BufferIngredientDraftRow({required this.draft, required this.onTap});

  final _BufferIngredientDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _labInset,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatNumber(draft.amount)} ${draft.unit} ${draft.scalable ? "(缩放)" : "(固定)"}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, color: _teal, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BufferIngredientEditorSheet extends StatefulWidget {
  const _BufferIngredientEditorSheet({
    required this.initial,
    this.canDelete = false,
  });

  final _BufferIngredientDraft initial;
  final bool canDelete;

  @override
  State<_BufferIngredientEditorSheet> createState() =>
      _BufferIngredientEditorSheetState();
}

class _BufferIngredientEditorSheetState
    extends State<_BufferIngredientEditorSheet> {
  late final TextEditingController nameController;
  late final TextEditingController amountController;
  late final TextEditingController unitController;
  late bool scalable;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initial.name);
    amountController = TextEditingController(
      text: _formatNumber(widget.initial.amount),
    );
    unitController = TextEditingController(text: widget.initial.unit);
    scalable = widget.initial.scalable;
  }

  @override
  void dispose() {
    nameController.dispose();
    amountController.dispose();
    unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              '编辑成分',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '用量'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: '单位'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _IosSwitchRow(
              title: const Text('随体积缩放'),
              value: scalable,
              onChanged: (value) => setState(() => scalable = value),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_draftFromFields()),
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存成分'),
            ),
          ],
        ),
      ),
    );
  }

  _BufferIngredientDraft _draftFromFields() {
    return _BufferIngredientDraft(
      id: widget.initial.id,
      name: nameController.text.trim().isEmpty
          ? '成分'
          : nameController.text.trim(),
      amount: double.tryParse(amountController.text.trim()) ?? 0,
      unit: unitController.text.trim(),
      scalable: scalable,
    );
  }
}

class FormulaRunnerScreen extends StatefulWidget {
  const FormulaRunnerScreen({
    super.key,
    required this.store,
    required this.formula,
    this.initialInputs = const {},
  });

  final LabStore store;
  final SavedFormula formula;
  final Map<String, double> initialInputs;

  @override
  State<FormulaRunnerScreen> createState() => _FormulaRunnerScreenState();
}

class _FormulaRunnerScreenState extends State<FormulaRunnerScreen> {
  late final List<TextEditingController> controllers;
  bool resultCopied = false;
  Timer? _copyResetTimer;

  @override
  void initState() {
    super.initState();
    controllers = widget.formula.variables
        .map(
          (variable) => TextEditingController(
            text: _formatNumber(
              widget.initialInputs[_safeFormulaName(variable.name)] ??
                  variable.value,
            ),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  _FormulaWorkflowOutput? get workflowOutput {
    final output = _evaluateCustomFormulaWorkflow(
      variables: widget.formula.variables,
      steps: widget.formula.workflowSteps,
      resultFields: widget.formula.workflowResultFields,
      variableValueOverrides: controllers.map((item) => item.text).toList(),
    );
    return output == null ? null : _FormulaWorkflowOutput(output.lines);
  }

  @override
  Widget build(BuildContext context) {
    final currentOutput = workflowOutput;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Row(
              children: [
                _CircleIconButton(
                  icon: Icons.close,
                  tooltip: '关闭',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Text(
                  '公式计算',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                _CircleIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: '编辑公式',
                  onTap: () => _editFormula(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _labPanel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.formula.label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _labInset,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.formula.workflowSteps
                          .map((step) => '${step.outputName} = ${step.formula}')
                          .join('\n'),
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _FormulaRunnerResultCard(output: currentOutput),
            const SizedBox(height: 12),
            _FormulaRunnerVariableCard(
              formula: widget.formula,
              controllers: controllers,
              onChanged: () => setState(() {}),
            ),
            if (widget.formula.referenceRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              _FormulaRunnerReferenceCard(rows: widget.formula.referenceRows),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: currentOutput == null
                        ? null
                        : () => _copyResult(currentOutput),
                    icon: Icon(resultCopied ? Icons.check_circle : Icons.copy),
                    label: Text(resultCopied ? '已复制' : '复制结果'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: currentOutput == null
                        ? null
                        : () => _saveResult(currentOutput),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('保存结果'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _resultText(_FormulaWorkflowOutput output) {
    return output.lines
        .map(
          (line) =>
              '${line.label}: ${_formatNumber(line.value)} ${line.unit}'.trim(),
        )
        .join('\n');
  }

  Future<void> _copyResult(_FormulaWorkflowOutput output) async {
    await Clipboard.setData(ClipboardData(text: _resultText(output)));
    if (!mounted) return;
    setState(() => resultCopied = true);
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => resultCopied = false);
    });
  }

  Future<void> _saveResult(_FormulaWorkflowOutput output) async {
    await widget.store.addCalcHistory(
      widget.formula.label,
      _resultText(output),
      mode: 'custom',
      inputs: _currentFormulaInputs(
        widget.formula.variables,
        controllers.map((item) => item.text).toList(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _editFormula(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          FormulaEditorSheet(store: widget.store, existing: widget.formula),
    );
    if (context.mounted) Navigator.pop(context);
  }
}

class _FormulaRunnerResultCard extends StatelessWidget {
  const _FormulaRunnerResultCard({required this.output});

  final _FormulaWorkflowOutput? output;

  @override
  Widget build(BuildContext context) {
    final currentOutput = output;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentOutput == null ? _labPanel : _mint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: currentOutput == null
              ? Colors.deepOrange.withValues(alpha: 0.25)
              : _teal.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: (currentOutput == null ? Colors.deepOrange : _teal)
                .withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IosGlyphIcon(IosGlyph.sqrt, color: _teal, size: 22),
              const SizedBox(width: 8),
              const Text('计算结果', style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              if (currentOutput != null)
                Text(
                  '${currentOutput.lines.length} 项',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (currentOutput == null)
            Text(
              '公式或变量无效',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            ...currentOutput.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        line.label,
                        style: const TextStyle(
                          color: _teal,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatNumber(line.value)} ${line.unit}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: _teal,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FormulaRunnerVariableCard extends StatelessWidget {
  const _FormulaRunnerVariableCard({
    required this.formula,
    required this.controllers,
    required this.onChanged,
  });

  final SavedFormula formula;
  final List<TextEditingController> controllers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IosGlyphIcon(IosGlyph.sliders, color: _teal, size: 21),
              const SizedBox(width: 8),
              Text(
                '输入变量',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...formula.variables.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _labInset,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.value.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: controllers[entry.key],
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(hintText: '数值'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        entry.value.unit.isEmpty ? '-' : entry.value.unit,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaRunnerReferenceCard extends StatelessWidget {
  const _FormulaRunnerReferenceCard({required this.rows});

  final List<CustomReferenceRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IosGlyphIcon(IosGlyph.clipboard, color: _teal, size: 21),
              const SizedBox(width: 8),
              Text(
                '参考表',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FormulaReferenceTableRow(
                    name: '名称',
                    condition: '条件',
                    value: '数值',
                    note: '备注',
                    isHeader: true,
                  ),
                  ...rows.map(
                    (row) => _FormulaReferenceTableRow(
                      name: row.name,
                      condition: row.condition,
                      value: row.value,
                      note: row.note,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaReferenceTableRow extends StatelessWidget {
  const _FormulaReferenceTableRow({
    required this.name,
    required this.condition,
    required this.value,
    required this.note,
    this.isHeader = false,
  });

  final String name;
  final String condition;
  final String value;
  final String note;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: isHeader ? _ink : _muted,
      fontSize: 12,
      fontWeight: isHeader ? FontWeight.w900 : FontWeight.w600,
    );
    return Container(
      color: isHeader ? _labInset : _labInset.withValues(alpha: 0.55),
      child: Row(
        children: [
          _cell(name, 92, style, Alignment.centerLeft),
          _cell(condition, 104, style, Alignment.centerLeft),
          _cell(value, 84, style, Alignment.center),
          _cell(note, 124, style, Alignment.centerLeft),
        ],
      ),
    );
  }

  Widget _cell(
    String text,
    double width,
    TextStyle style,
    Alignment alignment,
  ) {
    return Container(
      width: width,
      height: 32,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: _line.withValues(alpha: 0.75), width: 0.6),
          bottom: BorderSide(color: _line.withValues(alpha: 0.75), width: 0.6),
        ),
      ),
      child: Text(
        text.trim().isEmpty ? '-' : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class FormulaEditorSheet extends StatefulWidget {
  const FormulaEditorSheet({super.key, required this.store, this.existing});

  final LabStore store;
  final SavedFormula? existing;

  @override
  State<FormulaEditorSheet> createState() => _FormulaEditorSheetState();
}

class _FormulaEditorSheetState extends State<FormulaEditorSheet> {
  late final TextEditingController labelController;
  late List<_FormulaVariableDraft> variableDrafts;
  late List<_FormulaStepDraft> stepDrafts;
  late List<_FormulaResultDraft> resultDrafts;
  late List<_FormulaReferenceDraft> referenceDrafts;
  bool formulaResultCopied = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    labelController = TextEditingController(text: existing?.label ?? '自定义公式');
    variableDrafts =
        existing?.variables.map(_FormulaVariableDraft.fromVariable).toList() ??
        [_FormulaVariableDraft(name: '', value: '', unit: '')];
    stepDrafts =
        existing?.workflowSteps.map(_FormulaStepDraft.fromStep).toList() ??
        [_FormulaStepDraft(outputName: '结果', formula: '', outputUnit: '')];
    resultDrafts =
        existing?.workflowResultFields
            .map(_FormulaResultDraft.fromField)
            .toList() ??
        [_FormulaResultDraft(variableName: '结果', label: '结果', displayUnit: '')];
    referenceDrafts =
        existing?.referenceRows.map(_FormulaReferenceDraft.fromRow).toList() ??
        [];
  }

  @override
  void dispose() {
    labelController.dispose();
    for (final draft in variableDrafts) {
      draft.dispose();
    }
    for (final draft in stepDrafts) {
      draft.dispose();
    }
    for (final draft in resultDrafts) {
      draft.dispose();
    }
    for (final draft in referenceDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('formula-editor-close-button'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
                Expanded(
                  child: Text(
                    '自定义公式',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _FormulaPreviewChip(output: _workflowPreview()),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _FormulaEditorSection(
                    title: '计算名称',
                    glyph: IosGlyph.sqrt,
                    child: TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        hintText: '如：细胞接种密度、稀释倍数',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormulaEditorSection(
                    title: '输入变量',
                    glyph: IosGlyph.sliders,
                    onAdd: _addVariable,
                    addSemanticLabel: '添加公式变量',
                    child: Column(
                      children: [
                        for (var i = 0; i < variableDrafts.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FormulaVariableDraftRow(
                              key: ValueKey(variableDrafts[i].id),
                              draft: variableDrafts[i],
                              unitOptions: _formulaEditorUnitOptions(
                                widget.store.unitOptions,
                              ),
                              onDelete: variableDrafts.length > 1
                                  ? () => _removeVariable(i)
                                  : null,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        const Text(
                          '计算时会按变量名传入公式；后续步骤可以继续使用前面步骤的输出变量。',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormulaEditorSection(
                    title: '计算步骤',
                    glyph: IosGlyph.function,
                    onAdd: _addStep,
                    addSemanticLabel: '添加计算步骤',
                    child: Column(
                      children: [
                        for (var i = 0; i < stepDrafts.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FormulaStepDraftRow(
                              key: ValueKey(stepDrafts[i].id),
                              index: i,
                              draft: stepDrafts[i],
                              unitOptions: _formulaEditorUnitOptions(
                                widget.store.unitOptions,
                              ),
                              onDelete: stepDrafts.length > 1
                                  ? () => _removeStep(i)
                                  : null,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormulaEditorSection(
                    title: '展示结果',
                    glyph: IosGlyph.docText,
                    onAdd: _addResult,
                    addSemanticLabel: '添加展示结果',
                    child: Column(
                      children: [
                        for (var i = 0; i < resultDrafts.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FormulaResultDraftRow(
                              key: ValueKey(resultDrafts[i].id),
                              draft: resultDrafts[i],
                              unitOptions: _formulaEditorUnitOptions(
                                widget.store.unitOptions,
                              ),
                              onDelete: resultDrafts.length > 1
                                  ? () => _removeResult(i)
                                  : null,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormulaEditorSection(
                    title: '参考表',
                    glyph: IosGlyph.clipboard,
                    onAdd: _addReference,
                    addSemanticLabel: '添加参考项',
                    child: _FormulaReferenceTable(
                      drafts: referenceDrafts,
                      onEdit: _editReference,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormulaEditorSection(
                    title: '计算结果',
                    glyph: IosGlyph.sqrt,
                    child: _FormulaEditorResultActions(
                      output: _workflowPreview(),
                      copied: formulaResultCopied,
                      onCopy: _copyResult,
                      onSave: _saveResult,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _workflowPreview() == null ? null : _saveFormula,
                    icon: const Icon(Icons.save),
                    label: const Text('保存为工作流模板'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addVariable() => setState(
    () => variableDrafts.add(
      _FormulaVariableDraft(
        name: 'x${variableDrafts.length + 1}',
        value: '1',
        unit: '',
      ),
    ),
  );

  void _removeVariable(int index) {
    if (variableDrafts.length <= 1) return;
    setState(() => variableDrafts.removeAt(index).dispose());
  }

  void _addStep() => setState(
    () => stepDrafts.add(
      _FormulaStepDraft(
        outputName: 'step${stepDrafts.length + 1}',
        formula: '',
        outputUnit: '',
      ),
    ),
  );

  void _removeStep(int index) {
    if (stepDrafts.length <= 1) return;
    setState(() => stepDrafts.removeAt(index).dispose());
  }

  void _addResult() => setState(
    () => resultDrafts.add(
      _FormulaResultDraft(variableName: 'result', label: '结果', displayUnit: ''),
    ),
  );

  void _removeResult(int index) {
    if (resultDrafts.length <= 1) return;
    setState(() => resultDrafts.removeAt(index).dispose());
  }

  void _addReference() {
    final draft = _FormulaReferenceDraft(
      name: '参考项',
      condition: '',
      value: '',
      note: '',
    );
    _showReferenceEditor(draft);
  }

  void _editReference(_FormulaReferenceDraft draft) {
    _showReferenceEditor(
      _FormulaReferenceDraft.fromDraft(draft),
      original: draft,
    );
  }

  Future<void> _showReferenceEditor(
    _FormulaReferenceDraft draft, {
    _FormulaReferenceDraft? original,
  }) async {
    var deleted = false;
    final saved = await showModalBottomSheet<_FormulaReferenceDraft?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormulaReferenceEditorSheet(
        draft: draft,
        canDelete: original != null,
        onDelete: () => deleted = true,
      ),
    );
    if (!mounted) {
      draft.dispose();
      return;
    }
    if (deleted) {
      setState(() {
        referenceDrafts.remove(original);
        original?.dispose();
      });
      draft.dispose();
      return;
    }
    if (saved == null) {
      draft.dispose();
      return;
    }
    setState(() {
      final index = original == null ? -1 : referenceDrafts.indexOf(original);
      if (index == -1) {
        referenceDrafts.add(saved);
      } else {
        referenceDrafts[index] = saved;
        original?.dispose();
      }
    });
  }

  _FormulaWorkflowOutput? _workflowPreview() {
    final output = _evaluateCustomFormulaWorkflow(
      variables: variableDrafts.map((draft) => draft.toVariable()).toList(),
      steps: stepDrafts.map((draft) => draft.toStep()).toList(),
      resultFields: resultDrafts.map((draft) => draft.toField()).toList(),
      variableValueOverrides: variableDrafts
          .map((draft) => draft.valueController.text)
          .toList(),
    );
    return output == null ? null : _FormulaWorkflowOutput(output.lines);
  }

  String _resultText(_FormulaWorkflowOutput output) {
    return output.lines
        .map(
          (line) =>
              '${line.label}: ${_formatNumber(line.value)} ${line.unit}'.trim(),
        )
        .join('\n');
  }

  Future<void> _copyResult() async {
    final output = _workflowPreview();
    if (output == null) return;
    await Clipboard.setData(ClipboardData(text: _resultText(output)));
    if (!mounted) return;
    setState(() => formulaResultCopied = true);
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => formulaResultCopied = false);
    });
  }

  Future<void> _saveResult() async {
    final output = _workflowPreview();
    if (output == null) return;
    await widget.store.addCalcHistory(
      _formulaLabel,
      _resultText(output),
      mode: 'custom',
      inputs: _currentFormulaInputs(
        variableDrafts.map((draft) => draft.toVariable()).toList(),
        variableDrafts.map((draft) => draft.valueController.text).toList(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  String get _formulaLabel {
    final label = labelController.text.trim();
    return label.isEmpty ? '自定义公式' : label;
  }

  Future<void> _saveFormula() async {
    final variables = variableDrafts
        .map((draft) => draft.toVariable())
        .where((variable) => variable.name.trim().isNotEmpty)
        .toList();
    final steps = stepDrafts
        .map((draft) => draft.toStep())
        .where(
          (step) =>
              step.outputName.trim().isNotEmpty &&
              step.formula.trim().isNotEmpty,
        )
        .toList();
    final results = resultDrafts
        .map((draft) => draft.toField())
        .where((field) => field.variableName.trim().isNotEmpty)
        .toList();
    final references = referenceDrafts
        .map((draft) => draft.toRow())
        .where((row) => row.name.trim().isNotEmpty)
        .toList();
    if (_workflowPreview() == null || steps.isEmpty || results.isEmpty) return;
    final firstStep = steps.first;
    final formula = SavedFormula(
      id:
          widget.existing?.id ??
          'formula-${DateTime.now().microsecondsSinceEpoch}',
      label: _formulaLabel,
      formula: firstStep.formula,
      resultUnit: firstStep.outputUnit,
      variables: variables,
      steps: steps,
      resultFields: results,
      referenceRows: references,
    );
    await widget.store.upsertSavedFormula(formula);
    if (mounted) Navigator.pop(context);
  }
}

class _FormulaWorkflowOutput {
  const _FormulaWorkflowOutput(this.lines);

  final List<_FormulaResultLine> lines;
}

class _FormulaResultLine {
  const _FormulaResultLine({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double value;
  final String unit;
}

class _FormulaPreviewChip extends StatelessWidget {
  const _FormulaPreviewChip({required this.output});

  final _FormulaWorkflowOutput? output;

  @override
  Widget build(BuildContext context) {
    final first = output?.lines.firstOrNull;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: first == null ? _labInset : _mint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        first == null ? '无法计算' : '${_formatNumber(first.value)} ${first.unit}',
        style: TextStyle(
          color: first == null ? _muted : _teal,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _FormulaEditorResultActions extends StatelessWidget {
  const _FormulaEditorResultActions({
    required this.output,
    required this.copied,
    required this.onCopy,
    required this.onSave,
  });

  final _FormulaWorkflowOutput? output;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final currentOutput = output;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentOutput == null)
          const Text(
            '公式或变量无效',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
          )
        else
          ...currentOutput.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      line.label,
                      style: const TextStyle(
                        color: _teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _formatNumber(line.value),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _teal,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (line.unit.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Text(
                      line.unit,
                      style: const TextStyle(
                        color: _teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: currentOutput == null ? null : onCopy,
                icon: Icon(copied ? Icons.check_circle : Icons.copy),
                label: Text(copied ? '已复制' : '复制结果'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: currentOutput == null ? null : onSave,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('保存结果'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormulaEditorSection extends StatelessWidget {
  const _FormulaEditorSection({
    required this.title,
    required this.glyph,
    required this.child,
    this.onAdd,
    this.addSemanticLabel,
  });

  final String title;
  final IosGlyph glyph;
  final Widget child;
  final VoidCallback? onAdd;
  final String? addSemanticLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IosGlyphIcon(glyph, color: _teal, size: 21),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (onAdd != null)
                IosPlusCircleButton(
                  onPressed: onAdd!,
                  semanticLabel: addSemanticLabel ?? '添加',
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FormulaVariableDraft {
  _FormulaVariableDraft({
    String? id,
    required String name,
    required String value,
    required String unit,
  }) : id = id ?? _draftId('formula-var'),
       nameController = TextEditingController(text: name),
       valueController = TextEditingController(text: value),
       unitController = TextEditingController(text: unit);

  factory _FormulaVariableDraft.fromVariable(FormulaVariable variable) {
    return _FormulaVariableDraft(
      name: variable.name,
      value: _formatNumber(variable.value),
      unit: variable.unit,
    );
  }

  final String id;
  final TextEditingController nameController;
  final TextEditingController valueController;
  final TextEditingController unitController;

  FormulaVariable toVariable() => FormulaVariable(
    name: _safeFormulaName(nameController.text.trim()),
    value: double.tryParse(valueController.text.trim()) ?? 0,
    unit: unitController.text.trim(),
  );

  void dispose() {
    nameController.dispose();
    valueController.dispose();
    unitController.dispose();
  }
}

class _FormulaStepDraft {
  _FormulaStepDraft({
    String? id,
    required String outputName,
    required String formula,
    required String outputUnit,
  }) : id = id ?? _draftId('formula-step'),
       outputNameController = TextEditingController(text: outputName),
       formulaController = TextEditingController(text: formula),
       unitController = TextEditingController(text: outputUnit);

  factory _FormulaStepDraft.fromStep(CustomCalculationStep step) {
    return _FormulaStepDraft(
      outputName: step.outputName,
      formula: step.formula,
      outputUnit: step.outputUnit,
    );
  }

  final String id;
  final TextEditingController outputNameController;
  final TextEditingController formulaController;
  final TextEditingController unitController;

  CustomCalculationStep toStep() => CustomCalculationStep(
    outputName: _safeFormulaName(outputNameController.text.trim()),
    formula: formulaController.text.trim(),
    outputUnit: unitController.text.trim(),
  );

  void dispose() {
    outputNameController.dispose();
    formulaController.dispose();
    unitController.dispose();
  }
}

class _FormulaResultDraft {
  _FormulaResultDraft({
    String? id,
    required String variableName,
    required String label,
    required String displayUnit,
  }) : id = id ?? _draftId('formula-result'),
       variableNameController = TextEditingController(text: variableName),
       labelController = TextEditingController(text: label),
       unitController = TextEditingController(text: displayUnit);

  factory _FormulaResultDraft.fromField(CustomResultField field) {
    return _FormulaResultDraft(
      variableName: field.variableName,
      label: field.label,
      displayUnit: field.displayUnit,
    );
  }

  final String id;
  final TextEditingController variableNameController;
  final TextEditingController labelController;
  final TextEditingController unitController;

  CustomResultField toField() => CustomResultField(
    variableName: _safeFormulaName(variableNameController.text.trim()),
    label: labelController.text.trim(),
    displayUnit: unitController.text.trim(),
  );

  void dispose() {
    variableNameController.dispose();
    labelController.dispose();
    unitController.dispose();
  }
}

class _FormulaReferenceDraft {
  _FormulaReferenceDraft({
    String? id,
    required String name,
    required String condition,
    required String value,
    required String note,
  }) : id = id ?? _draftId('formula-reference'),
       nameController = TextEditingController(text: name),
       conditionController = TextEditingController(text: condition),
       valueController = TextEditingController(text: value),
       noteController = TextEditingController(text: note);

  factory _FormulaReferenceDraft.fromRow(CustomReferenceRow row) {
    return _FormulaReferenceDraft(
      name: row.name,
      condition: row.condition,
      value: row.value,
      note: row.note,
    );
  }

  factory _FormulaReferenceDraft.fromDraft(_FormulaReferenceDraft draft) {
    return _FormulaReferenceDraft(
      id: draft.id,
      name: draft.nameController.text,
      condition: draft.conditionController.text,
      value: draft.valueController.text,
      note: draft.noteController.text,
    );
  }

  final String id;
  final TextEditingController nameController;
  final TextEditingController conditionController;
  final TextEditingController valueController;
  final TextEditingController noteController;

  CustomReferenceRow toRow() => CustomReferenceRow(
    name: nameController.text.trim(),
    condition: conditionController.text.trim(),
    value: valueController.text.trim(),
    note: noteController.text.trim(),
  );

  void dispose() {
    nameController.dispose();
    conditionController.dispose();
    valueController.dispose();
    noteController.dispose();
  }
}

class _FormulaVariableDraftRow extends StatelessWidget {
  const _FormulaVariableDraftRow({
    super.key,
    required this.draft,
    required this.unitOptions,
    this.onDelete,
    required this.onChanged,
  });

  final _FormulaVariableDraft draft;
  final List<String> unitOptions;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _FormulaInsetRow(
      children: [
        Expanded(
          child: TextField(
            key: const Key('formula-variable-name-field'),
            controller: draft.nameController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(hintText: '变量名'),
          ),
        ),
        if (onDelete != null) ...[
          const SizedBox(width: 6),
          IconButton(
            key: const Key('formula-variable-inline-delete-button'),
            tooltip: '删除变量',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: Icon(
              Icons.remove_circle,
              color: Colors.red.withValues(alpha: 0.70),
              size: 20,
            ),
          ),
        ],
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
          child: TextField(
            key: const Key('formula-variable-value-field'),
            controller: draft.valueController,
            onChanged: (_) => onChanged(),
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '数值'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 104,
          child: _FormulaUnitDropdown(
            label: '单位',
            value: draft.unitController.text,
            options: unitOptions,
            onChanged: (value) {
              draft.unitController.text = value;
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _FormulaStepDraftRow extends StatelessWidget {
  const _FormulaStepDraftRow({
    super.key,
    required this.index,
    required this.draft,
    required this.unitOptions,
    this.onDelete,
    required this.onChanged,
  });

  final int index;
  final _FormulaStepDraft draft;
  final List<String> unitOptions;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '步骤 ${index + 1}',
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  key: const Key('formula-step-inline-delete-button'),
                  tooltip: '删除计算步骤',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.remove_circle,
                    color: Colors.red.withValues(alpha: 0.70),
                    size: 20,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('formula-step-output-field'),
                  controller: draft.outputNameController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(hintText: '输出变量'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 112,
                child: _FormulaUnitDropdown(
                  label: '公式输出单位',
                  value: draft.unitController.text,
                  options: unitOptions,
                  onChanged: (value) {
                    draft.unitController.text = value;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('formula-step-expression-field'),
            controller: draft.formulaController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              hintText: '公式，如 totalDNA * ratio / totalRatio',
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaResultDraftRow extends StatelessWidget {
  const _FormulaResultDraftRow({
    super.key,
    required this.draft,
    required this.unitOptions,
    this.onDelete,
    required this.onChanged,
  });

  final _FormulaResultDraft draft;
  final List<String> unitOptions;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _FormulaInsetRow(
      children: [
        Expanded(
          child: TextField(
            key: const Key('formula-result-label-field'),
            controller: draft.labelController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(hintText: '展示名称'),
          ),
        ),
        if (onDelete != null) ...[
          const SizedBox(width: 6),
          IconButton(
            key: const Key('formula-result-inline-delete-button'),
            tooltip: '删除展示结果',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: Icon(
              Icons.remove_circle,
              color: Colors.red.withValues(alpha: 0.70),
              size: 20,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: const Key('formula-result-variable-field'),
            controller: draft.variableNameController,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(hintText: '变量名'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 112,
          child: _FormulaUnitDropdown(
            label: '展示单位',
            value: draft.unitController.text,
            options: unitOptions,
            onChanged: (value) {
              draft.unitController.text = value;
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _FormulaReferenceTable extends StatelessWidget {
  const _FormulaReferenceTable({required this.drafts, required this.onEdit});

  final List<_FormulaReferenceDraft> drafts;
  final ValueChanged<_FormulaReferenceDraft> onEdit;

  @override
  Widget build(BuildContext context) {
    if (drafts.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '可添加培养体系、反应体系、推荐用量等参考数据；只用于展示和模板保存，不参与公式计算。',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormulaReferenceEditableRow(
              name: '名称',
              condition: '条件',
              value: '数值',
              note: '备注',
              header: true,
            ),
            for (final draft in drafts)
              _FormulaReferenceEditableRow(
                name: draft.nameController.text,
                condition: draft.conditionController.text,
                value: draft.valueController.text,
                note: draft.noteController.text,
                onTap: () => onEdit(draft),
              ),
          ],
        ),
      ),
    );
  }
}

class _FormulaReferenceEditableRow extends StatelessWidget {
  const _FormulaReferenceEditableRow({
    required this.name,
    required this.condition,
    required this.value,
    required this.note,
    this.header = false,
    this.onTap,
  });

  final String name;
  final String condition;
  final String value;
  final String note;
  final bool header;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: header ? _ink : _muted,
      fontSize: 12,
      fontWeight: header ? FontWeight.w900 : FontWeight.w600,
    );
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          _cell(name, 92, style, Alignment.centerLeft),
          _cell(condition, 104, style, Alignment.centerLeft),
          _cell(value, 84, style, Alignment.center),
          _cell(note, 124, style, Alignment.centerLeft),
        ],
      ),
    );
  }

  Widget _cell(
    String text,
    double width,
    TextStyle style,
    Alignment alignment,
  ) {
    return Container(
      width: width,
      height: 32,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: header ? _labInset : _labInset.withValues(alpha: 0.55),
        border: Border(
          right: BorderSide(color: _line.withValues(alpha: 0.75), width: 0.6),
          bottom: BorderSide(color: _line.withValues(alpha: 0.75), width: 0.6),
        ),
      ),
      child: Text(
        text.trim().isEmpty ? '-' : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _FormulaReferenceEditorSheet extends StatelessWidget {
  const _FormulaReferenceEditorSheet({
    required this.draft,
    required this.canDelete,
    required this.onDelete,
  });

  final _FormulaReferenceDraft draft;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('formula-reference-cancel-button'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                Expanded(
                  child: Text(
                    '编辑参考',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('formula-reference-save-button'),
                  onPressed: () => Navigator.pop(context, draft),
                  child: const Text('保存'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _referenceField('名称', draft.nameController),
                  _referenceField('条件', draft.conditionController),
                  _referenceField('数值', draft.valueController),
                  _referenceField('备注', draft.noteController),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: canDelete
                        ? () {
                            onDelete();
                            Navigator.pop(context);
                          }
                        : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除这条参考'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _referenceField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _FormulaInsetRow extends StatelessWidget {
  const _FormulaInsetRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: children),
    );
  }
}

class SavedFormulaTile extends StatelessWidget {
  const SavedFormulaTile({
    super.key,
    required this.formula,
    required this.onTap,
    required this.onEdit,
  });

  final SavedFormula formula;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF5856D6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: IosGlyphIcon(
                    IosGlyph.sqrt,
                    color: Color(0xFF5856D6),
                    size: 23,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formula.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formula.formula,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '编辑公式',
                onPressed: onEdit,
                color: _teal,
                icon: const Icon(Icons.edit_outlined),
              ),
              IosGlyphIcon(
                IosGlyph.chevronRight,
                color: _muted.withValues(alpha: 0.42),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalcHistoryTile extends StatelessWidget {
  const CalcHistoryTile({super.key, required this.item, this.onTap});

  final CalcHistoryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: item.mode == null || item.inputs.isEmpty ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.history, color: _teal, size: 19),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.result,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _teal,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (item.mode != null && item.inputs.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      const Text(
                        '可恢复输入',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.restore,
                color: item.mode == null || item.inputs.isEmpty
                    ? _muted.withValues(alpha: 0.28)
                    : _muted.withValues(alpha: 0.72),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalculatorCard extends StatelessWidget {
  const CalculatorCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.result,
    required this.onSave,
    this.tint = _teal,
  });

  final String title;
  final String subtitle;
  final List<Widget> fields;
  final String result;
  final VoidCallback onSave;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: _muted)),
            const SizedBox(height: 12),
            ...fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: field,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tint.withValues(alpha: 0.18)),
              ),
              child: Text(
                result,
                style: TextStyle(
                  color: tint,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_alt),
                label: const Text('保存结果'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _labPanel,
            shape: BoxShape.circle,
            border: Border.all(color: _line),
          ),
          child: Icon(icon, size: 20, color: _ink),
        ),
      ),
    );
  }
}

class _RecipeScaleRow extends StatelessWidget {
  const _RecipeScaleRow({
    required this.name,
    required this.subtitle,
    required this.amount,
  });

  final String name;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: const TextStyle(color: _teal, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class CalcField extends StatelessWidget {
  const CalcField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

class _TransfectionDoseDraft {
  _TransfectionDoseDraft({
    String? id,
    required String vessel,
    required String area,
    required String dna,
    required String reagent,
    required String diluent,
    required String medium,
  }) : id = id ?? _draftId('transfection-dose'),
       vesselController = TextEditingController(text: vessel),
       areaController = TextEditingController(text: area),
       dnaController = TextEditingController(text: dna),
       reagentController = TextEditingController(text: reagent),
       diluentController = TextEditingController(text: diluent),
       mediumController = TextEditingController(text: medium);

  final String id;
  final TextEditingController vesselController;
  final TextEditingController areaController;
  final TextEditingController dnaController;
  final TextEditingController reagentController;
  final TextEditingController diluentController;
  final TextEditingController mediumController;

  String get vessel => vesselController.text.trim().isEmpty
      ? '未命名培养皿'
      : vesselController.text.trim();
  double get dnaUg => double.tryParse(dnaController.text.trim()) ?? 0;
  String get note => areaController.text.trim().isEmpty
      ? '选择参考剂量'
      : '${areaController.text.trim()} cm² · ${mediumController.text.trim()}';

  void dispose() {
    vesselController.dispose();
    areaController.dispose();
    dnaController.dispose();
    reagentController.dispose();
    diluentController.dispose();
    mediumController.dispose();
  }
}

class _TransfectionPlasmidDraft {
  _TransfectionPlasmidDraft({
    required String name,
    required String ratio,
    String concentration = '1000',
    String ratioGroup = _defaultTransfectionRatioGroup,
  }) : nameController = TextEditingController(text: name),
       ratioController = TextEditingController(text: ratio),
       concentrationController = TextEditingController(text: concentration),
       ratioGroup = ValueNotifier<String>(ratioGroup);

  final TextEditingController nameController;
  final TextEditingController ratioController;
  final TextEditingController concentrationController;
  final ValueNotifier<String> ratioGroup;

  void dispose() {
    nameController.dispose();
    ratioController.dispose();
    concentrationController.dispose();
    ratioGroup.dispose();
  }
}

class _TransfectionPlasmidGroupDraft {
  _TransfectionPlasmidGroupDraft({
    String? id,
    required String title,
    required this.plasmids,
  }) : id = id ?? _draftId('transfection-group'),
       titleController = TextEditingController(text: title);

  final String id;
  final TextEditingController titleController;
  final List<_TransfectionPlasmidDraft> plasmids;

  void dispose() {
    titleController.dispose();
    for (final plasmid in plasmids) {
      plasmid.dispose();
    }
  }
}

const _defaultTransfectionRatioGroup = 'total-dna';

const _transfectionRatioGroups = <String, String>{
  _defaultTransfectionRatioGroup: '总 DNA',
  'target-only': '目的质粒组合',
  'helper-packaging': '包装/辅助质粒',
  'envelope': '包膜质粒',
};

class _TransfectionPresetPicker extends StatelessWidget {
  const _TransfectionPresetPicker({
    required this.selected,
    required this.doses,
    required this.onSelected,
  });

  final String selected;
  final List<_TransfectionDoseDraft> doses;
  final ValueChanged<_TransfectionDoseDraft> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const IosGlyphIcon(IosGlyph.waveform, color: _teal, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '培养皿剂量',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  doses
                          .where((dose) => dose.vessel == selected)
                          .firstOrNull
                          ?.note ??
                      '选择参考剂量',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<_TransfectionDoseDraft>(
            tooltip: '选择培养皿剂量',
            onSelected: onSelected,
            itemBuilder: (context) => doses
                .map(
                  (dose) => PopupMenuItem(
                    value: dose,
                    child: Text(
                      '${dose.vessel} · ${_formatNumber(dose.dnaUg)} μg',
                    ),
                  ),
                )
                .toList(),
            child: ChipLabel(text: selected, color: const Color(0xFF5856D6)),
          ),
        ],
      ),
    );
  }
}

class _TransfectionReferenceTable extends StatelessWidget {
  const _TransfectionReferenceTable({
    required this.doses,
    required this.onAdd,
    required this.onEdit,
  });

  final List<_TransfectionDoseDraft> doses;
  final VoidCallback onAdd;
  final ValueChanged<_TransfectionDoseDraft> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '不同培养容器转染用量',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '仅供参考，实际计算仍按上方输入值执行。',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TransfectionReferenceRow(
                  vessel: '培养皿',
                  area: 'cm²',
                  dna: 'DNA μg',
                  reagent: '试剂 μl',
                  diluent: '稀释液 μl',
                  medium: '培养基',
                  header: true,
                ),
                for (final dose in doses)
                  _TransfectionReferenceRow(
                    vessel: dose.vessel,
                    area: dose.areaController.text.trim(),
                    dna: dose.dnaController.text.trim(),
                    reagent: dose.reagentController.text.trim(),
                    diluent: dose.diluentController.text.trim(),
                    medium: dose.mediumController.text.trim(),
                    onTap: () => onEdit(dose),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransfectionReferenceRow extends StatelessWidget {
  const _TransfectionReferenceRow({
    required this.vessel,
    required this.area,
    required this.dna,
    required this.reagent,
    required this.diluent,
    required this.medium,
    this.header = false,
    this.onTap,
  });

  final String vessel;
  final String area;
  final String dna;
  final String reagent;
  final String diluent;
  final String medium;
  final bool header;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: header ? _ink : _muted,
      fontSize: 12,
      fontWeight: header ? FontWeight.w900 : FontWeight.w600,
    );
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          _tableCell(vessel, 86, style),
          _tableCell(area, 62, style),
          _tableCell(dna, 72, style),
          _tableCell(reagent, 72, style),
          _tableCell(diluent, 84, style),
          _tableCell(medium, 86, style),
        ],
      ),
    );
  }

  Widget _tableCell(String text, double width, TextStyle style) {
    return Container(
      width: width,
      height: 32,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: header ? _labPanel : _labPanel.withValues(alpha: 0.65),
        border: Border.all(color: _line.withValues(alpha: 0.75), width: 0.5),
      ),
      child: Text(
        text.isEmpty ? '-' : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _TransfectionDoseEditorSheet extends StatelessWidget {
  const _TransfectionDoseEditorSheet({
    required this.dose,
    required this.canDelete,
    required this.onDelete,
  });

  final _TransfectionDoseDraft dose;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              '编辑参考',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _doseField('培养皿', dose.vesselController),
            _doseField('表面积 cm²', dose.areaController),
            _doseField('DNA μg', dose.dnaController),
            _doseField('转染试剂 μl', dose.reagentController),
            _doseField('稀释液 μl', dose.diluentController),
            _doseField('培养基总量', dose.mediumController),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, dose),
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: canDelete
                  ? () {
                      onDelete();
                      Navigator.pop(context);
                    }
                  : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除这条参考'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doseField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _TransfectionPlasmidEditor extends StatelessWidget {
  const _TransfectionPlasmidEditor({
    required this.groups,
    required this.onChanged,
    required this.onAddGroup,
    required this.onDeleteGroup,
    required this.onAddPlasmid,
    required this.onDeletePlasmid,
  });

  final List<_TransfectionPlasmidGroupDraft> groups;
  final VoidCallback onChanged;
  final VoidCallback onAddGroup;
  final ValueChanged<_TransfectionPlasmidGroupDraft> onDeleteGroup;
  final ValueChanged<_TransfectionPlasmidGroupDraft> onAddPlasmid;
  final void Function(
    _TransfectionPlasmidGroupDraft group,
    _TransfectionPlasmidDraft plasmid,
  )
  onDeletePlasmid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('质粒分组', style: TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton.icon(
                onPressed: onAddGroup,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('新增分组'),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            '同一「比例计算对象」内按比例分配 DNA 总量；不同对象会分开计算。',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransfectionPlasmidGroupCard(
                group: group,
                canDeleteGroup: groups.length > 1,
                canDeletePlasmid:
                    groups.fold<int>(
                      0,
                      (sum, item) => sum + item.plasmids.length,
                    ) >
                    1,
                onChanged: onChanged,
                onAddPlasmid: () => onAddPlasmid(group),
                onDeleteGroup: () => onDeleteGroup(group),
                onDeletePlasmid: (plasmid) => onDeletePlasmid(group, plasmid),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransfectionPlasmidGroupCard extends StatelessWidget {
  const _TransfectionPlasmidGroupCard({
    required this.group,
    required this.canDeleteGroup,
    required this.canDeletePlasmid,
    required this.onChanged,
    required this.onAddPlasmid,
    required this.onDeleteGroup,
    required this.onDeletePlasmid,
  });

  final _TransfectionPlasmidGroupDraft group;
  final bool canDeleteGroup;
  final bool canDeletePlasmid;
  final VoidCallback onChanged;
  final VoidCallback onAddPlasmid;
  final VoidCallback onDeleteGroup;
  final ValueChanged<_TransfectionPlasmidDraft> onDeletePlasmid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: group.titleController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(hintText: '分组名称'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: '添加质粒',
                onPressed: onAddPlasmid,
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                tooltip: '删除分组',
                onPressed: canDeleteGroup ? onDeleteGroup : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final plasmid in group.plasmids)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: canDeletePlasmid
                  ? IosSwipeDelete(
                      confirmTitle: '删除质粒？',
                      confirmMessage:
                          '删除「${plasmid.nameController.text.trim().isEmpty ? '质粒' : plasmid.nameController.text.trim()}」后，这个转染配方分组会立即更新。',
                      onDelete: () async => onDeletePlasmid(plasmid),
                      child: _TransfectionPlasmidRow(
                        draft: plasmid,
                        onChanged: onChanged,
                      ),
                    )
                  : _TransfectionPlasmidRow(
                      draft: plasmid,
                      onChanged: onChanged,
                    ),
            ),
          if (group.plasmids.isEmpty)
            TextButton.icon(
              onPressed: onAddPlasmid,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('添加质粒'),
            ),
        ],
      ),
    );
  }
}

class _TransfectionPlasmidRow extends StatelessWidget {
  const _TransfectionPlasmidRow({required this.draft, required this.onChanged});

  final _TransfectionPlasmidDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _labPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.nameController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(hintText: '质粒名称'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.ratioController,
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '比例'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.concentrationController,
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '浓度',
                    suffixText: 'ng/μl',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<String>(
            valueListenable: draft.ratioGroup,
            builder: (context, group, _) {
              final normalizedGroup =
                  _transfectionRatioGroups.containsKey(group)
                  ? group
                  : _defaultTransfectionRatioGroup;
              return Row(
                children: [
                  const Text(
                    '比例计算对象',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: '选择比例计算对象',
                    onSelected: (value) {
                      draft.ratioGroup.value = value;
                      onChanged();
                    },
                    itemBuilder: (context) => _transfectionRatioGroups.entries
                        .map(
                          (entry) => PopupMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    child: ChipLabel(
                      text:
                          '比例计算对象：${_transfectionRatioGroups[normalizedGroup]}',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class MyScreen extends StatefulWidget {
  const MyScreen({super.key, required this.store});

  final LabStore store;

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  LabStore get store => widget.store;

  String get _identityName {
    final name = store.userName.trim();
    return name.isEmpty ? '未登录用户' : name;
  }

  String get _identityDetail {
    if (store.isAuthenticated && store.userEmail.trim().isNotEmpty) {
      return store.userEmail;
    }
    final lab = store.labName.trim();
    return lab.isEmpty ? '个人本地工作区' : lab;
  }

  String get _identityStatus =>
      store.isAuthenticated ? '已登录 · 本地数据仍存本机' : '未登录 · 本地个人工具';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, _iosTopOffset, 18, 104),
          children: [
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showPreferences(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 31,
                        backgroundColor: _teal,
                        backgroundImage: _profileAvatarImage(store.avatarPath),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _identityName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 19,
                                  ),
                            ),
                            Text(
                              _identityDetail,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _teal.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _identityStatus,
                                style: TextStyle(
                                  color: _teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (store.labName.isNotEmpty &&
                                store.labName != '个人本地工作区')
                              Text(
                                store.labName,
                                style: const TextStyle(color: _muted),
                              ),
                          ],
                        ),
                      ),
                      IosGlyphIcon(
                        IosGlyph.chevronRight,
                        color: _muted.withValues(alpha: 0.55),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _InventorySummary(
                  inventory: store.inventory,
                  onOpen: () => _openInventoryPage(context),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: '项目管理',
              trailing: IosPlusCircleButton(
                onPressed: () => _showProjectEditor(context),
              ),
              children: store.projects.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '暂无项目，点击 + 新建',
                          style: TextStyle(color: _muted),
                        ),
                      ),
                    ]
                  : store.projects
                        .map(
                          (project) => IosSwipeDelete(
                            key: ValueKey('project-${project.id}'),
                            confirmTitle: '删除项目？',
                            confirmMessage:
                                '删除「${project.name}」只会移除项目标签，不会删除已经创建的实验记录。',
                            onDelete: () async {
                              await store.deleteProject(project.id);
                              if (mounted) setState(() {});
                            },
                            child: _ProjectRow(
                              project: project,
                              onTap: () => _showProjectEditor(context, project),
                            ),
                          ),
                        )
                        .toList(),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: '本地数据管理',
              children: [
                SettingsRow(
                  glyph: IosGlyph.upload,
                  title: '导出备份',
                  subtitle: '将本机所有 Protocol、记录、库存导出为文件',
                  onTap: () => _exportBackup(context),
                  compact: true,
                ),
                SettingsRow(
                  glyph: IosGlyph.download,
                  title: '导入恢复',
                  subtitle: '从已导出的备份文件中恢复数据',
                  onTap: () => _importBackup(context),
                  compact: true,
                ),
                SettingsRow(
                  icon: Icons.delete_outline,
                  title: '清理缓存与演示数据',
                  subtitle: '清除本机缓存与初始化数据，项目需登录后由用户自行创建',
                  onTap: store.resetDemoData,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: '未来能力',
              children: [
                SettingsRow(
                  icon: Icons.cloud_outlined,
                  title: '云同步与协作',
                  subtitle: 'v1 保持关闭，数据仅存本机',
                  onTap: () {},
                  compact: true,
                  disabled: true,
                ),
                SettingsRow(
                  icon: Icons.credit_card,
                  title: 'Pro 订阅',
                  subtitle: '去除结果卡片水印、AI 助手、语音调度等 · 即将推出',
                  onTap: () {},
                  compact: true,
                  disabled: true,
                ),
              ],
            ),
            if (store.inventoryTransactions.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: '库存交易记录',
                children: store.inventoryTransactions
                    .take(5)
                    .map(
                      (tx) => SettingsRow(
                        icon: tx.delta < 0
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                        title: '${tx.itemName} ${tx.deltaLabel}',
                        subtitle: '${tx.note} · ${tx.dateLabel}',
                        onTap: () {},
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openInventoryPage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InventoryPageScreen(store: store),
      ),
    );
  }

  Future<void> _showProjectEditor(
    BuildContext context, [
    LabProject? project,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProjectEditorSheet(store: store, existing: project),
    );
  }

  Future<void> _showPreferences(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => PreferencesSheet(store: store),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      await store.exportBackup();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('备份文件已准备分享')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：$error')));
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入备份？'),
        content: const Text('导入会覆盖当前本机的实验、Protocol、库存、项目和偏好设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('选择备份文件'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final imported = await store.importBackup();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(imported ? '备份已导入' : '未选择备份文件')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.glyph,
    this.compact = false,
    this.disabled = false,
  }) : assert(icon != null || glyph != null);

  final IconData? icon;
  final IosGlyph? glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                : const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: compact ? 34 : 40,
                  height: compact ? 34 : 40,
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: disabled ? 0.06 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: glyph == null
                      ? Icon(
                          icon,
                          color: disabled ? _muted : _teal,
                          size: compact ? 20 : 22,
                        )
                      : Center(
                          child: IosGlyphIcon(
                            glyph!,
                            color: disabled ? _muted : _teal,
                            size: compact ? 22 : 24,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 14.5 : 15.5,
                              color: disabled ? _muted : null,
                            ),
                      ),
                      SizedBox(height: compact ? 1 : 3),
                      Text(
                        subtitle,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _muted,
                          fontSize: compact ? 12.5 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IosGlyphIcon(
                  IosGlyph.chevronRight,
                  color: _muted.withValues(alpha: disabled ? 0.22 : 0.5),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventorySummary extends StatelessWidget {
  const _InventorySummary({required this.inventory, required this.onOpen});

  final List<LabInventoryItem> inventory;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final lowItems = inventory.where((item) => item.lowStock).toList();
    final visible = inventory.take(3).toList();
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IosGlyphIcon(IosGlyph.tray, color: Colors.black, size: 25),
              const SizedBox(width: 9),
              Text(
                '个人库存',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              if (lowItems.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: Color(0xFFFF8A1C),
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${lowItems.length} 项低库存',
                      style: const TextStyle(
                        color: Color(0xFFFF8A1C),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              IosGlyphIcon(
                IosGlyph.chevronRight,
                color: _muted.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
          if (lowItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_rounded,
                    color: Color(0xFFFF8A1C),
                    size: 17,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lowItems.first.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatNumber(lowItems.first.quantity)} ${lowItems.first.unit} 剩余',
                    style: const TextStyle(
                      color: Color(0xFFFF8A1C),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            '常用试剂',
            style: TextStyle(
              color: _muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          ...visible.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 6.5,
                    color: item.lowStock ? Colors.orange : _teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${_formatNumber(item.quantity)} ${item.unit}',
                    style: const TextStyle(color: _muted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '查看全部 ${inventory.length} 项库存',
            style: const TextStyle(
              color: _teal,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryPageScreen extends StatefulWidget {
  const InventoryPageScreen({super.key, required this.store});

  final LabStore store;

  @override
  State<InventoryPageScreen> createState() => _InventoryPageScreenState();
}

class _InventoryPageScreenState extends State<InventoryPageScreen> {
  final searchController = TextEditingController();
  String? selectedCategory;

  LabStore get store => widget.store;

  List<String> get categories => store.inventoryCategoryOptions;

  List<LabInventoryItem> get filteredItems {
    final query = searchController.text.trim().toLowerCase();
    var items = store.inventory;
    if (selectedCategory != null) {
      items = items.where((item) => item.category == selectedCategory).toList();
    }
    if (query.isNotEmpty) {
      items = items
          .where(
            (item) =>
                item.name.toLowerCase().contains(query) ||
                item.category.toLowerCase().contains(query) ||
                item.storage.toLowerCase().contains(query),
          )
          .toList();
    }
    return [...items]..sort((a, b) {
      if (a.lowStock != b.lowStock) return a.lowStock ? -1 : 1;
      return a.name.compareTo(b.name);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final items = filteredItems;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.close,
                        tooltip: '关闭',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        '库存管理',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _CircleIconButton(
                            icon: Icons.category_outlined,
                            tooltip: '分类管理',
                            onTap: () => _showCategoryManager(context),
                          ),
                          const SizedBox(width: 8),
                          IosPlusCircleButton(
                            onPressed: () => _showInventoryEditor(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: IosSearchField(
                    controller: searchController,
                    hintText: '搜索试剂名称或分类',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterPill(
                        label: '全部',
                        selected: selectedCategory == null,
                        color: _teal,
                        onTap: () => setState(() => selectedCategory = null),
                      ),
                      const SizedBox(width: 8),
                      ...categories.expand(
                        (category) => [
                          _FilterPill(
                            label: category,
                            selected: selectedCategory == category,
                            color: _teal,
                            onTap: () => setState(
                              () => selectedCategory =
                                  selectedCategory == category
                                  ? null
                                  : category,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: store.inventory.isEmpty ? '库存为空' : '没有匹配的试剂',
                          body: store.inventory.isEmpty
                              ? '点击右上角 + 添加试剂到库存'
                              : '尝试调整搜索条件或分类筛选',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 108),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: IosSwipeDelete(
                                key: ValueKey('inventory-${item.id}'),
                                confirmTitle: '删除库存项？',
                                confirmMessage:
                                    '删除「${item.name}」后，对应库存交易记录也会一并移除。',
                                onDelete: () async =>
                                    store.deleteInventory(item.id),
                                child: InventoryItemCard(
                                  item: item,
                                  onDeduct: (amount) =>
                                      store.adjustInventory(item.id, -amount),
                                  onRestock: (amount) =>
                                      store.adjustInventory(item.id, amount),
                                  onEdit: () =>
                                      _showInventoryEditor(context, item),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInventoryEditor(
    BuildContext context, [
    LabInventoryItem? item,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InventoryEditorSheet(store: store, existing: item),
    );
  }

  Future<void> _showCategoryManager(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InventoryCategoryManagementSheet(store: store),
    );
    if (!mounted) return;
    if (selectedCategory != null && !categories.contains(selectedCategory)) {
      setState(() => selectedCategory = null);
    }
  }
}

class InventoryItemCard extends StatefulWidget {
  const InventoryItemCard({
    super.key,
    required this.item,
    required this.onDeduct,
    required this.onRestock,
    required this.onEdit,
  });

  final LabInventoryItem item;
  final ValueChanged<double> onDeduct;
  final ValueChanged<double> onRestock;
  final VoidCallback onEdit;

  @override
  State<InventoryItemCard> createState() => _InventoryItemCardState();
}

class _InventoryItemCardState extends State<InventoryItemCard> {
  late final TextEditingController amountController;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  double get amount => double.tryParse(amountController.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final statusColor = item.lowStock ? const Color(0xFFFF9500) : _teal;
    final progress = item.threshold <= 0
        ? 1.0
        : (item.quantity / (item.threshold * 3)).clamp(0.0, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: widget.onEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _labPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: item.lowStock ? statusColor.withValues(alpha: 0.30) : _line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.category} · ${item.storage}',
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.lowStock ? '低库存' : '充足',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatNumber(item.quantity),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    item.unit,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
                const Spacer(),
                Text(
                  '阈值 ${_formatNumber(item.threshold)} ${item.unit}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            IosProgressBar(value: progress, color: statusColor),
            if (item.supplier.isNotEmpty || item.lotNumber.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (item.supplier.isNotEmpty)
                    ChipLabel(text: item.supplier, color: _muted),
                  if (item.lotNumber.isNotEmpty)
                    ChipLabel(text: '批号 ${item.lotNumber}', color: _muted),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                InkResponse(
                  onTap: amount <= 0 ? null : () => widget.onDeduct(amount),
                  radius: 22,
                  child: const Icon(
                    Icons.remove_circle,
                    color: _muted,
                    size: 28,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _labInset,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 58,
                        child: TextField(
                          controller: amountController,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Text(
                        item.unit,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkResponse(
                  onTap: amount <= 0 ? null : () => widget.onRestock(amount),
                  radius: 22,
                  child: const Icon(Icons.add_circle, color: _teal, size: 28),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.onTap});

  final LabProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateLine = [
      '创建 ${project.createdDateLabel}',
      if (project.endDateLabel != null) '结束 ${project.endDateLabel}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _labInset,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: project.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (project.description.isNotEmpty)
                      Text(
                        project.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    Text(
                      dateLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IosGlyphIcon(
                IosGlyph.chevronRight,
                color: _muted.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosSwitchRow extends StatelessWidget {
  const _IosSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Widget title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                child: title,
              ),
            ),
            _IosSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _IosSwitch extends StatelessWidget {
  const _IosSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? _teal : _muted.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceNavRow extends StatelessWidget {
  const _PreferenceNavRow({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  final IosGlyph glyph;
  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (disabled ? _muted : _teal).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: IosGlyphIcon(
                  glyph,
                  color: disabled ? _muted : _teal,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: disabled ? _muted : _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    child: title,
                  ),
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: _muted.withValues(alpha: disabled ? 0.72 : 1),
                      fontSize: 12.5,
                    ),
                    child: subtitle,
                  ),
                ],
              ),
            ),
            IosGlyphIcon(
              IosGlyph.chevronRight,
              color: _muted.withValues(alpha: disabled ? 0.24 : 0.48),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadonlyPreferenceRow extends StatelessWidget {
  const _ReadonlyPreferenceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _muted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PreferencesSheet extends StatefulWidget {
  const PreferencesSheet({super.key, required this.store});

  final LabStore store;

  @override
  State<PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<PreferencesSheet> {
  late final TextEditingController nameController;
  late final TextEditingController labController;
  String? avatarPath;

  LabStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: store.userName);
    labController = TextEditingController(text: store.labName);
    avatarPath = store.avatarPath;
  }

  @override
  void dispose() {
    nameController.dispose();
    labController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final pref = store.preferences;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '偏好设置',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('preferences-done-button'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完成'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '个人信息',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Column(
                            children: [
                              InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _pickAvatar,
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 44,
                                      backgroundColor: _teal,
                                      backgroundImage: _profileAvatarImage(
                                        avatarPath,
                                      ),
                                    ),
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _teal,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '点击更换头像',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (avatarPath != null && avatarPath!.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setState(() => avatarPath = null);
                                    _syncProfile();
                                  },
                                  child: const Text('移除头像'),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: '昵称'),
                          onChanged: (_) => _syncProfile(),
                        ),
                        const SizedBox(height: 10),
                        _ReadonlyPreferenceRow(
                          label: '登录邮箱',
                          value: store.userEmail.trim().isEmpty
                              ? '未登录'
                              : store.userEmail,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: labController,
                          decoration: const InputDecoration(
                            labelText: '实验室 / 项目空间',
                          ),
                          onChanged: (_) => _syncProfile(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本地演示版',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '当前 APK 不需要服务器登录。使用预设演示邮箱和密码进入后，实验记录、Protocol、项目和偏好设置都只保存在本机。',
                          style: TextStyle(color: _muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '外观',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'system',
                              label: Text('跟随系统'),
                              icon: Icon(Icons.brightness_auto),
                            ),
                            ButtonSegment(
                              value: 'light',
                              label: Text('浅色'),
                              icon: Icon(Icons.light_mode),
                            ),
                            ButtonSegment(
                              value: 'dark',
                              label: Text('深色'),
                              icon: Icon(Icons.dark_mode),
                            ),
                          ],
                          selected: {pref.colorScheme},
                          onSelectionChanged: (value) =>
                              store.updatePreferences(colorScheme: value.first),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              '字体大小',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 214,
                              child: SegmentedButton<double>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(value: 0.85, label: Text('小')),
                                  ButtonSegment(value: 1.0, label: Text('标准')),
                                  ButtonSegment(value: 1.15, label: Text('大')),
                                  ButtonSegment(value: 1.3, label: Text('超大')),
                                ],
                                selected: {_nearestFontScale(pref.fontScale)},
                                onSelectionChanged: (value) => store
                                    .updatePreferences(fontScale: value.first),
                              ),
                            ),
                          ],
                        ),
                        _IosSwitchRow(
                          title: const Text('紧凑卡片模式'),
                          value: pref.compactCards,
                          onChanged: (value) =>
                              store.updatePreferences(compactCards: value),
                        ),
                        _PreferenceNavRow(
                          glyph: IosGlyph.palette,
                          title: const Text('实验颜色顺序'),
                          subtitle: Text(
                            '${store.activeExperimentPalette.length} 色',
                          ),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) =>
                                _ExperimentColorOrderSheet(store: store),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '实验台',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        _IosSwitchRow(
                          title: const Text('大字号实验台模式'),
                          value: pref.largeBenchMode,
                          onChanged: (value) =>
                              store.updatePreferences(largeBenchMode: value),
                        ),
                        _IosSwitchRow(
                          title: const Text('显示步骤计时时长'),
                          value: pref.showStepDuration,
                          onChanged: (value) =>
                              store.updatePreferences(showStepDuration: value),
                        ),
                        _IosSwitchRow(
                          title: const Text('自动保存实验记录'),
                          value: pref.autoSave,
                          onChanged: (value) =>
                              store.updatePreferences(autoSave: value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '通知与反馈',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        _IosSwitchRow(
                          title: const Text('计时结束提示音'),
                          value: pref.timerSound,
                          onChanged: (value) =>
                              store.updatePreferences(timerSound: value),
                        ),
                        _IosSwitchRow(
                          title: const Text('触感反馈（Haptics）'),
                          value: pref.haptics,
                          onChanged: (value) =>
                              store.updatePreferences(haptics: value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '单位管理',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        _PreferenceNavRow(
                          glyph: IosGlyph.sliders,
                          title: const Text('自定义单位'),
                          subtitle: Text('${store.customUnits.length} 个'),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => UnitManagementSheet(store: store),
                          ),
                        ),
                        _PreferenceNavRow(
                          glyph: IosGlyph.beaker,
                          title: const Text('自定义实验类型'),
                          subtitle: Text('${store.customAreas.length} 个'),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) =>
                                ExperimentTypeManagementSheet(store: store),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '语音播报内容',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 8),
                            ChipLabel(text: 'Pro'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pref.isProUser
                              ? '计时到点时自动语音播报，模板可使用 {实验} 和 {步骤}。'
                              : 'Pro 功能：计时到点时自动语音播报',
                          style: TextStyle(color: _muted, fontSize: 12.5),
                        ),
                        const SizedBox(height: 12),
                        if (pref.isProUser) ...[
                          _IosSwitchRow(
                            title: const Text('启用语音播报'),
                            value: pref.timerSound,
                            onChanged: (value) =>
                                store.updatePreferences(timerSound: value),
                          ),
                          if (pref.timerSound) ...[
                            const SizedBox(height: 8),
                            _VoiceAnnouncementTemplateField(
                              value: pref.voiceAnnouncementTemplate,
                              onChanged: (value) => store.updatePreferences(
                                voiceAnnouncementTemplate:
                                    _normalizedVoiceTemplate(value),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '可用变量：{实验} {步骤}',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => store.updatePreferences(
                                    voiceAnnouncementTemplate: LabPreferences
                                        .defaultVoiceAnnouncementTemplate,
                                  ),
                                  child: const Text('恢复默认'),
                                ),
                                const Spacer(),
                                const Text(
                                  '预览',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _voicePreview(
                                      pref.voiceAnnouncementTemplate,
                                    ),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: _teal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ] else
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _labInset,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.workspace_premium,
                                    color: _teal,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '升级 Pro 解锁语音自定义',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: _teal,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                  const IosGlyphIcon(
                                    IosGlyph.chevronRight,
                                    color: _teal,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PreferenceNavRow(
                          glyph: IosGlyph.creditCard,
                          title: const Text('Pro 订阅权益'),
                          subtitle: Text(
                            pref.isProUser
                                ? '已解锁：AI 助手 · 语音调度'
                                : '去除结果卡片水印 · AI 助手 · 语音调度 · 即将推出',
                          ),
                          onTap: () {},
                          disabled: !pref.isProUser,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '账号',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '退出登录不会删除本机实验记录、Protocol 或库存数据。',
                          style: TextStyle(color: _muted, fontSize: 12.5),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          key: const Key('preferences-sign-out-row'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            await store.signOut();
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: _labInset,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _line),
                            ),
                            child: const Text(
                              '退出登录',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final path = await store.pickAvatar();
      if (path == null || !mounted) return;
      setState(() => avatarPath = path);
      await _syncProfile();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像导入失败：$error')));
    }
  }

  Future<void> _syncProfile() async {
    await store.updateProfile(
      name: nameController.text.trim().isEmpty
          ? 'LabBuddy User'
          : nameController.text.trim(),
      email: store.userEmail.trim().isEmpty
          ? 'local@labbuddy'
          : store.userEmail,
      labName: labController.text.trim(),
      avatarPath: avatarPath,
    );
  }
}

class _VoiceAnnouncementTemplateField extends StatefulWidget {
  const _VoiceAnnouncementTemplateField({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_VoiceAnnouncementTemplateField> createState() =>
      _VoiceAnnouncementTemplateFieldState();
}

class _VoiceAnnouncementTemplateFieldState
    extends State<_VoiceAnnouncementTemplateField> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _VoiceAnnouncementTemplateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != controller.text) {
      controller.text = widget.value;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: '播报模板',
        hintText: LabPreferences.defaultVoiceAnnouncementTemplate,
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onChanged,
      onEditingComplete: () => widget.onChanged(controller.text),
    );
  }
}

String _normalizedVoiceTemplate(String value) {
  final normalized = value.trim();
  return normalized.isEmpty
      ? LabPreferences.defaultVoiceAnnouncementTemplate
      : normalized;
}

String _voicePreview(String template) {
  return _normalizedVoiceTemplate(template)
      .replaceAll('{实验}', '293T 细胞传代')
      .replaceAll('{experiment}', '293T 细胞传代')
      .replaceAll('{步骤}', '胰酶消化')
      .replaceAll('{step}', '胰酶消化');
}

double _nearestFontScale(double value) {
  const options = [0.85, 1.0, 1.15, 1.3];
  return options.reduce(
    (best, item) => (item - value).abs() < (best - value).abs() ? item : best,
  );
}

class _ExperimentColorOrderSheet extends StatefulWidget {
  const _ExperimentColorOrderSheet({required this.store});

  final LabStore store;

  @override
  State<_ExperimentColorOrderSheet> createState() =>
      _ExperimentColorOrderSheetState();
}

class _ExperimentColorOrderSheetState
    extends State<_ExperimentColorOrderSheet> {
  late List<int> palette;

  @override
  void initState() {
    super.initState();
    palette = List.of(widget.store.activeExperimentPalette);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              '实验颜色顺序',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '新出现的实验会按照这个顺序依次分配颜色；修改顺序后，已分配关系会重新生成。',
              style: TextStyle(color: _muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var index = 0; index < palette.length; index++)
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _cycleColor(index),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Color(palette[index]),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                palette = List.of(defaultExperimentPalette);
              }),
              icon: const Icon(Icons.restore),
              label: const Text('恢复 Apple 默认配色'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                await widget.store.updateProjectPalette(palette);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.check),
              label: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleColor(int index) {
    final current = palette[index];
    final currentIndex = defaultExperimentPalette.indexOf(current);
    setState(() {
      palette[index] =
          defaultExperimentPalette[(currentIndex + 1) %
              defaultExperimentPalette.length];
    });
  }
}

class UnitManagementSheet extends StatefulWidget {
  const UnitManagementSheet({super.key, required this.store});

  final LabStore store;

  @override
  State<UnitManagementSheet> createState() => _UnitManagementSheetState();
}

class _UnitManagementSheetState extends State<UnitManagementSheet> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                '单位管理',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '内置单位',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          ChipLabel(text: 'Pro 可修改'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...builtInUnitGroups.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${entry.value.length} 个',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: entry.value
                                    .map(
                                      (unit) => ChipLabel(
                                        text: '$unit 🔒',
                                        color: _muted,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Text(
                        '内置单位根据使用场景自动显示：库存管理显示体积、质量、计数单位；计算工具显示体积、质量、浓度单位',
                        style: TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: '新增单位，例如 U/IU/次'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  await widget.store.addCustomUnit(controller.text);
                  controller.clear();
                },
                icon: const Icon(Icons.add),
                label: const Text('添加自定义单位'),
              ),
              const SizedBox(height: 8),
              const Text(
                '自定义单位会在所有场景（库存、计算工具、实验方案）中显示',
                style: TextStyle(color: _muted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              ...widget.store.customUnits.map(
                (unit) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IosSwipeDelete(
                    key: ValueKey('custom-unit-$unit'),
                    confirmTitle: '删除自定义单位？',
                    confirmMessage: '删除「$unit」后，它不会再出现在库存、计算工具和实验方案的单位选择中。',
                    onDelete: () async => widget.store.removeCustomUnit(unit),
                    child: Card(child: ListTile(title: Text(unit))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExperimentTypeManagementSheet extends StatefulWidget {
  const ExperimentTypeManagementSheet({super.key, required this.store});

  final LabStore store;

  @override
  State<ExperimentTypeManagementSheet> createState() =>
      _ExperimentTypeManagementSheetState();
}

class _ExperimentTypeManagementSheetState
    extends State<ExperimentTypeManagementSheet> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                '实验类型管理',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '内置实验类型',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          ChipLabel(text: 'Pro 可修改'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: builtInExperimentAreas
                            .map(
                              (area) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        area,
                                        style: const TextStyle(
                                          color: _muted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.lock,
                                      color: _muted,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: '新增类型，例如 免疫实验'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  await widget.store.addCustomArea(controller.text);
                  controller.clear();
                },
                icon: const Icon(Icons.add),
                label: const Text('添加自定义实验类型'),
              ),
              const SizedBox(height: 8),
              const Text(
                '自定义类型将在新建实验和 Protocol 编辑中可用',
                style: TextStyle(color: _muted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              ...widget.store.customAreas.map(
                (area) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IosSwipeDelete(
                    key: ValueKey('custom-area-$area'),
                    confirmTitle: '删除自定义实验类型？',
                    confirmMessage: '删除「$area」后，它不会再出现在新建实验和 Protocol 编辑中。',
                    onDelete: () async => widget.store.removeCustomArea(area),
                    child: Card(child: ListTile(title: Text(area))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryCategoryManagementSheet extends StatefulWidget {
  const InventoryCategoryManagementSheet({super.key, required this.store});

  final LabStore store;

  @override
  State<InventoryCategoryManagementSheet> createState() =>
      _InventoryCategoryManagementSheetState();
}

class _InventoryCategoryManagementSheetState
    extends State<InventoryCategoryManagementSheet> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builtInCategories = widget.store.inventoryCategoryOptions
        .where((item) => !widget.store.customInventoryCategories.contains(item))
        .toList();
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                '库存分类',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '当前分类',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: builtInCategories
                            .map((category) => ChipLabel(text: category))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '新增分类，例如 抗体/耗材/细胞培养',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  await widget.store.addInventoryCategory(controller.text);
                  controller.clear();
                },
                icon: const Icon(Icons.add),
                label: const Text('添加分类'),
              ),
              const SizedBox(height: 12),
              ...widget.store.customInventoryCategories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(category),
                      trailing: IconButton(
                        tooltip: '删除',
                        onPressed: () =>
                            widget.store.removeInventoryCategory(category),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RunEditorSheet extends StatefulWidget {
  const RunEditorSheet({
    super.key,
    required this.store,
    required this.target,
    this.presetProtocol,
    this.date,
  });

  final LabStore store;
  final DayMode target;
  final LabProtocol? presetProtocol;
  final DateTime? date;

  @override
  State<RunEditorSheet> createState() => _RunEditorSheetState();
}

class _RunEditorSheetState extends State<RunEditorSheet> {
  late final TextEditingController titleController;
  late final TextEditingController scaleController;
  late LabProtocol? protocol;
  String area = '细胞实验';
  String? projectId;
  late int selectedHour;
  late int selectedMinute;

  @override
  void initState() {
    super.initState();
    protocol = widget.presetProtocol ?? widget.store.protocols.first;
    titleController = TextEditingController(text: protocol?.name ?? '手动实验');
    final initialTime = _timePartsFromLabel(
      widget.target == DayMode.tomorrow ? '09:30' : '10:00',
    );
    selectedHour = initialTime.hour;
    selectedMinute = initialTime.minute;
    scaleController = TextEditingController(
      text: protocol?.baseVolumeLabel ?? 'manual',
    );
    area = protocol?.area ?? '细胞实验';
  }

  @override
  void dispose() {
    titleController.dispose();
    scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('run-editor-cancel-button'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                Expanded(
                  child: Text(
                    widget.target == DayMode.tomorrow ? '添加到明天' : '添加到今天',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('run-editor-save-button'),
                  onPressed: _saveRun,
                  child: const Text('保存'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '插入位置',
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _showScheduleTimePicker,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _labInset,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: _teal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.target == DayMode.tomorrow
                                ? '${_futureDateLabel(widget.date)} $_selectedTimeLabel'
                                : '今天 $_selectedTimeLabel',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Icon(Icons.edit, color: _teal, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: protocol?.id ?? 'manual',
              decoration: const InputDecoration(labelText: '来源'),
              items: [
                ...widget.store.protocols.map(
                  (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                ),
                const DropdownMenuItem(value: 'manual', child: Text('手动实验')),
              ],
              onChanged: (value) {
                setState(() {
                  protocol = widget.store.protocols
                      .where((p) => p.id == value)
                      .firstOrNull;
                  titleController.text = protocol?.name ?? '手动实验';
                  scaleController.text = protocol?.baseVolumeLabel ?? 'manual';
                  area = protocol?.area ?? area;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '实验名称'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: scaleController,
              decoration: const InputDecoration(labelText: '规模 / 条件'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: area,
              decoration: const InputDecoration(labelText: '实验类型'),
              items: widget.store.areaOptions
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => area = value ?? area),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: projectId,
              decoration: const InputDecoration(labelText: '项目'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('不关联项目'),
                ),
                ...widget.store.projects.map(
                  (p) => DropdownMenuItem<String?>(
                    value: p.id,
                    child: Text(p.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => projectId = value),
            ),
          ],
        ),
      ),
    );
  }

  String get _selectedTimeLabel =>
      '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';

  Future<void> _showScheduleTimePicker() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RunScheduleTimePickerSheet(
        initialHour: selectedHour,
        initialMinute: selectedMinute,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedHour = picked.hour;
      selectedMinute = picked.minute;
    });
  }

  Future<void> _saveRun() async {
    await widget.store.addRun(
      target: widget.target,
      title: titleController.text.trim().isEmpty
          ? '手动实验'
          : titleController.text.trim(),
      area: area,
      timeLabel: _selectedTimeLabel,
      protocol: protocol,
      scale: scaleController.text.trim().isEmpty
          ? 'manual'
          : scaleController.text.trim(),
      projectId: projectId,
      date: widget.date,
    );
    if (mounted) Navigator.pop(context);
  }
}

class _RunScheduleTimePickerSheet extends StatefulWidget {
  const _RunScheduleTimePickerSheet({
    required this.initialHour,
    required this.initialMinute,
  });

  final int initialHour;
  final int initialMinute;

  @override
  State<_RunScheduleTimePickerSheet> createState() =>
      _RunScheduleTimePickerSheetState();
}

class _RunScheduleTimePickerSheetState
    extends State<_RunScheduleTimePickerSheet> {
  late int hour;
  late int minute;
  static const minuteOptions = [0, 15, 30, 45];

  @override
  void initState() {
    super.initState();
    hour = widget.initialHour.clamp(0, 23);
    minute = minuteOptions.reduce((best, value) {
      return (value - widget.initialMinute).abs() <
              (best - widget.initialMinute).abs()
          ? value
          : best;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择插入时间',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimerWheelColumn(
                  key: const Key('run-schedule-hour-wheel'),
                  label: '时',
                  value: hour,
                  max: 23,
                  onChanged: (value) => setState(() => hour = value),
                ),
                SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 160,
                        child: CupertinoPicker(
                          key: const Key('run-schedule-minute-picker'),
                          scrollController: FixedExtentScrollController(
                            initialItem: minuteOptions.indexOf(minute),
                          ),
                          itemExtent: 34,
                          magnification: 1.08,
                          squeeze: 1.1,
                          useMagnifier: true,
                          selectionOverlay:
                              const CupertinoPickerDefaultSelectionOverlay(
                                background: Color(0x1A00C7BE),
                              ),
                          onSelectedItemChanged: (index) =>
                              setState(() => minute = minuteOptions[index]),
                          children: [
                            for (final value in minuteOptions)
                              Center(
                                child: Text(
                                  value.toString().padLeft(2, '0'),
                                  style: const TextStyle(
                                    color: _ink,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Text(
                        '分',
                        style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, TimeOfDay(hour: hour, minute: minute)),
              icon: const Icon(Icons.check),
              label: const Text('应用时间'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryEditorSheet extends StatefulWidget {
  const InventoryEditorSheet({super.key, required this.store, this.existing});

  final LabStore store;
  final LabInventoryItem? existing;

  @override
  State<InventoryEditorSheet> createState() => _InventoryEditorSheetState();
}

class _InventoryEditorSheetState extends State<InventoryEditorSheet> {
  late final TextEditingController nameController;
  late final TextEditingController quantityController;
  late final TextEditingController thresholdController;
  late final TextEditingController unitController;
  late final TextEditingController categoryController;
  late final TextEditingController storageController;
  late final TextEditingController supplierController;
  late final TextEditingController lotNumberController;
  late final TextEditingController notesController;

  String get currentCategory => categoryController.text.trim().isEmpty
      ? '试剂'
      : categoryController.text.trim();

  List<String> get categoryOptions =>
      {...widget.store.inventoryCategoryOptions, currentCategory}.toList()
        ..sort();

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    nameController = TextEditingController(text: item?.name ?? '');
    nameController.addListener(_handleNameChanged);
    quantityController = TextEditingController(
      text: _formatNumber(item?.quantity ?? 0),
    );
    thresholdController = TextEditingController(
      text: _formatNumber(item?.threshold ?? 10),
    );
    unitController = TextEditingController(text: item?.unit ?? 'ml');
    categoryController = TextEditingController(text: item?.category ?? '培养基');
    storageController = TextEditingController(text: item?.storage ?? '4°C');
    supplierController = TextEditingController(text: item?.supplier ?? '');
    lotNumberController = TextEditingController(text: item?.lotNumber ?? '');
    notesController = TextEditingController(text: item?.notes ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    thresholdController.dispose();
    unitController.dispose();
    categoryController.dispose();
    storageController.dispose();
    supplierController.dispose();
    lotNumberController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('inventory-editor-cancel-button'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                Expanded(
                  child: Text(
                    widget.existing == null ? '新增库存项' : '编辑库存',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('inventory-editor-save-button'),
                  onPressed: nameController.text.trim().isEmpty
                      ? null
                      : _saveInventory,
                  child: const Text('保存'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '试剂名称'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: currentCategory,
              decoration: const InputDecoration(labelText: '分类'),
              items: categoryOptions
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                categoryController.text = value ?? currentCategory;
              }),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _showAddCategoryDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('新建分类'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: '当前数量'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: thresholdController,
              decoration: const InputDecoration(labelText: '低库存阈值'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: unitController,
              decoration: InputDecoration(
                labelText: '单位',
                suffixIcon: PopupMenuButton<String>(
                  tooltip: '选择单位',
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (value) => setState(() {
                    unitController.text = value;
                  }),
                  itemBuilder: (context) => widget.store.unitOptions
                      .map(
                        (unit) => PopupMenuItem(value: unit, child: Text(unit)),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: storageController,
              decoration: const InputDecoration(labelText: '存储位置'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: supplierController,
              decoration: const InputDecoration(labelText: '供应商'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lotNumberController,
              decoration: const InputDecoration(labelText: '批号'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: '备注'),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final category = await showDialog<String>(
      context: context,
      builder: (context) => const InventoryCategoryDialog(),
    );
    final normalized = category?.trim();
    if (normalized == null || normalized.isEmpty) return;
    await widget.store.addInventoryCategory(normalized);
    if (!mounted) return;
    setState(() => categoryController.text = normalized);
  }

  Future<void> _saveInventory() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final category = categoryController.text.trim();
    final quantity = double.tryParse(quantityController.text) ?? 0;
    final threshold = double.tryParse(thresholdController.text) ?? 0;
    final unit = unitController.text.trim().isEmpty
        ? 'unit'
        : unitController.text.trim();
    final storage = storageController.text.trim();
    if (widget.existing == null) {
      await widget.store.addInventory(
        name: name,
        category: category,
        quantity: quantity,
        threshold: threshold,
        unit: unit,
        storage: storage,
        supplier: supplierController.text.trim(),
        lotNumber: lotNumberController.text.trim(),
        notes: notesController.text.trim(),
      );
    } else {
      await widget.store.updateInventory(
        widget.existing!.copyWith(
          name: name,
          category: category,
          quantity: quantity,
          threshold: threshold,
          unit: unit,
          storage: storage,
          supplier: supplierController.text.trim(),
          lotNumber: lotNumberController.text.trim(),
          notes: notesController.text.trim(),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }
}

class InventoryCategoryDialog extends StatefulWidget {
  const InventoryCategoryDialog({super.key});

  @override
  State<InventoryCategoryDialog> createState() =>
      _InventoryCategoryDialogState();
}

class _InventoryCategoryDialogState extends State<InventoryCategoryDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建分类'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '分类名称'),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('添加'),
        ),
      ],
    );
  }
}

class ProjectEditorSheet extends StatefulWidget {
  const ProjectEditorSheet({super.key, required this.store, this.existing});

  final LabStore store;
  final LabProject? existing;

  @override
  State<ProjectEditorSheet> createState() => _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends State<ProjectEditorSheet> {
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late int selectedColor;
  late bool hasEndTime;
  late DateTime endTime;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.existing?.name ?? '');
    nameController.addListener(_handleNameChanged);
    descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    final palette = widget.store.activeProjectPalette;
    selectedColor =
        widget.existing?.colorValue ??
        palette[widget.store.projects.length % palette.length];
    hasEndTime = widget.existing?.endsAtMs != null;
    endTime = widget.existing?.endsAtMs == null
        ? DateTime.now().add(const Duration(days: 30))
        : DateTime.fromMillisecondsSinceEpoch(widget.existing!.endsAtMs!);
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                if (widget.existing == null)
                  TextButton(
                    key: const Key('project-editor-cancel-button'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  )
                else
                  IconButton(
                    key: const Key('project-editor-delete-button'),
                    tooltip: '删除项目',
                    onPressed: _confirmDeleteProject,
                    color: const Color(0xFFFF3B30),
                    icon: const Icon(Icons.delete_outline),
                  ),
                Expanded(
                  child: Text(
                    widget.existing == null ? '新建项目' : '编辑项目',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('project-editor-save-button'),
                  onPressed: nameController.text.trim().isEmpty
                      ? null
                      : _saveProject,
                  child: const Text('保存'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '项目信息',
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '项目名称'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: '描述（可选）'),
                  minLines: 2,
                  maxLines: 5,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '颜色标识',
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.store.activeProjectPalette
                      .map(
                        (value) => InkWell(
                          onTap: () => setState(() => selectedColor = value),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                              boxShadow: [
                                if (selectedColor == value)
                                  BoxShadow(
                                    color: Color(value).withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: selectedColor == value
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '时间',
              children: [
                _IosSwitchRow(
                  title: const Text('设置结束时间'),
                  value: hasEndTime,
                  onChanged: (value) => setState(() => hasEndTime = value),
                ),
                if (hasEndTime) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _pickEndTime,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _labInset,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined, color: _teal),
                          const SizedBox(width: 10),
                          const Text(
                            '结束时间',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Text(
                            _projectDateTimeLabel(endTime),
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (widget.existing != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _labInset,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '创建时间',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text(
                          widget.existing!.createdDateLabel,
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: endTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(endTime),
    );
    if (time == null || !mounted) return;
    setState(
      () => endTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _saveProject() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final projectEndsAtMs = hasEndTime ? endTime.millisecondsSinceEpoch : null;
    if (widget.existing == null) {
      await widget.store.addProject(
        name,
        descriptionController.text.trim(),
        selectedColor,
        projectEndsAtMs,
      );
    } else {
      await widget.store.updateProject(
        LabProject(
          id: widget.existing!.id,
          name: name,
          description: descriptionController.text.trim(),
          colorValue: selectedColor,
          createdAtMs: widget.existing!.createdAtMs,
          endsAtMs: projectEndsAtMs,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDeleteProject() async {
    final project = widget.existing;
    if (project == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('只会删除「${project.name}」项目标签，不会删除已经创建的实验记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.store.deleteProject(project.id);
    if (mounted) Navigator.pop(context);
  }
}

String _projectDateTimeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}/${date.month}/${date.day} $hour:$minute';
}

class DataCardSheet extends StatefulWidget {
  const DataCardSheet({super.key, required this.run, required this.store});

  final LabRun run;
  final LabStore store;

  @override
  State<DataCardSheet> createState() => _DataCardSheetState();
}

class _DataCardSheetState extends State<DataCardSheet> {
  final Set<String> hiddenFields = {};
  final notesController = TextEditingController();
  String? selectedImagePath;
  bool pickingImage = false;
  bool copied = false;
  bool saveSuccess = false;
  Timer? copiedResetTimer;
  Timer? saveResetTimer;

  LabRun get run => widget.run;
  LabStore get store => widget.store;

  @override
  void dispose() {
    copiedResetTimer?.cancel();
    saveResetTimer?.cancel();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = store.projectFor(run.projectId);
    final cardText = _cardText(project);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.close,
                tooltip: '关闭',
                onTap: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              Text(
                '结果卡片',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              const SizedBox(width: 38),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _labPanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            run.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.08,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(run.area, style: const TextStyle(color: _muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      run.timeLabel,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DataCardImageSlot(
                  imagePath: selectedImagePath,
                  picking: pickingImage,
                  onTap: () => _pickImage(context),
                  onClear: selectedImagePath == null
                      ? null
                      : () => setState(() => selectedImagePath = null),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _labInset.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '实验条件',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _FieldToggleRow(
                        label: 'Protocol',
                        value: run.protocolName,
                        fieldKey: 'protocol',
                        visible: _visible('protocol'),
                        onChanged: _toggleField,
                      ),
                      _FieldToggleRow(
                        label: '用量/规模',
                        value: run.scaledVolumeLabel,
                        fieldKey: 'scale',
                        visible: _visible('scale'),
                        onChanged: _toggleField,
                      ),
                      _FieldToggleRow(
                        label: '实验类型',
                        value: run.area,
                        fieldKey: 'type',
                        visible: _visible('type'),
                        onChanged: _toggleField,
                      ),
                      _FieldToggleRow(
                        label: '步骤完成',
                        value: '${run.completedCount}/${run.steps.length}',
                        fieldKey: 'steps',
                        visible: _visible('steps'),
                        onChanged: _toggleField,
                      ),
                      _FieldToggleRow(
                        label: '记录时间',
                        value: _nowLabel(),
                        fieldKey: 'time',
                        visible: _visible('time'),
                        onChanged: _toggleField,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '备注',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: '补充实验备注（可选）'),
                  onChanged: (_) => setState(() {}),
                ),
                if (store.preferences.dataCardWatermark) ...[
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Powered by LabBuddy',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: cardText));
                    if (!mounted) return;
                    copiedResetTimer?.cancel();
                    setState(() => copied = true);
                    copiedResetTimer = Timer(
                      const Duration(milliseconds: 1500),
                      () {
                        if (mounted) setState(() => copied = false);
                      },
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('实验条件已复制')));
                    }
                  },
                  icon: Icon(copied ? Icons.check_circle : Icons.copy),
                  label: Text(copied ? '已复制' : '复制实验条件'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _saveImage(context, project),
                  icon: Icon(
                    saveSuccess ? Icons.check_circle : Icons.image_outlined,
                  ),
                  label: Text(saveSuccess ? '已保存到相册' : '保存到相册'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _shareImage(context, project),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('分享'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _cardText(LabProject? project) {
    final lines = [
      if (_visible('protocol')) 'Protocol: ${run.protocolName}',
      if (_visible('scale')) '用量/规模: ${run.scaledVolumeLabel}',
      if (_visible('type')) '实验类型: ${run.area}',
      if (_visible('steps')) '步骤完成: ${run.completedCount}/${run.steps.length}',
      if (_visible('time')) '记录时间: ${_nowLabel()}',
      if (notesController.text.trim().isNotEmpty)
        '备注: ${notesController.text.trim()}',
    ];
    return lines.join('\n');
  }

  List<String> _cardImageLines(LabProject? project) {
    return [
      if (_visible('protocol')) 'Protocol: ${run.protocolName}',
      if (_visible('scale')) '用量/规模: ${run.scaledVolumeLabel}',
      if (_visible('type')) '实验类型: ${run.area}',
      if (_visible('steps')) '步骤完成: ${run.completedCount}/${run.steps.length}',
      if (_visible('time')) '记录时间: ${_nowLabel()}',
      if (notesController.text.trim().isNotEmpty)
        '备注: ${notesController.text.trim()}',
    ];
  }

  Map<String, Object?> _cardImagePayload(LabProject? project) => {
    'title': run.title,
    'subtitle': '${run.area} · ${run.timeLabel}',
    'lines': _cardImageLines(project),
    'imagePath': selectedImagePath,
    'watermark': store.preferences.dataCardWatermark,
  };

  Future<void> _pickImage(BuildContext context) async {
    if (pickingImage) return;
    setState(() => pickingImage = true);
    try {
      final path = await _dataCardChannel.invokeMethod<String>(
        'pickDataCardImage',
      );
      if (!mounted || path == null || path.isEmpty) return;
      setState(() => selectedImagePath = path);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片导入失败：$error')));
    } finally {
      if (mounted) setState(() => pickingImage = false);
    }
  }

  Future<void> _shareImage(BuildContext context, LabProject? project) async {
    try {
      await _dataCardChannel.invokeMethod<void>(
        'shareDataCard',
        _cardImagePayload(project),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享失败：$error')));
    }
  }

  Future<void> _saveImage(BuildContext context, LabProject? project) async {
    try {
      await _dataCardChannel.invokeMethod<void>(
        'saveDataCard',
        _cardImagePayload(project),
      );
      if (!mounted) return;
      saveResetTimer?.cancel();
      setState(() => saveSuccess = true);
      saveResetTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => saveSuccess = false);
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data Card 图片已保存')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  bool _visible(String fieldKey) => !hiddenFields.contains(fieldKey);

  void _toggleField(String fieldKey, bool visible) {
    setState(() {
      if (visible) {
        hiddenFields.remove(fieldKey);
      } else {
        hiddenFields.add(fieldKey);
      }
    });
  }

  String _nowLabel() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

class _DataCardImageSlot extends StatelessWidget {
  const _DataCardImageSlot({
    required this.imagePath,
    required this.picking,
    required this.onTap,
    required this.onClear,
  });

  final String? imagePath;
  final bool picking;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final image = imagePath == null ? null : File(imagePath!);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 202,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _teal.withValues(alpha: 0.18)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  Image.file(image, fit: BoxFit.cover)
                else
                  CustomPaint(
                    painter: _DataCardImageSlotPainter(),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (picking)
                            const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: _teal,
                              ),
                            )
                          else
                            const IosGlyphIcon(
                              IosGlyph.photo,
                              color: _teal,
                              size: 38,
                            ),
                          const SizedBox(height: 10),
                          Text(
                            picking ? '正在打开相册' : '点击添加结果图片',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '跑胶、WB、细胞图片均可',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (image != null) ...[
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          '点击更换图片',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onClear != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _CircleIconButton(
                        icon: Icons.close,
                        tooltip: '移除图片',
                        onTap: onClear!,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataCardImageSlotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.save();
    canvas.clipRRect(clip);
    final linePaint = Paint()
      ..color = _teal.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    const spacing = 18.0;
    for (var x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        linePaint,
      );
    }
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _teal.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.0),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRRect(clip, fillPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FieldToggleRow extends StatelessWidget {
  const _FieldToggleRow({
    required this.label,
    required this.value,
    required this.fieldKey,
    required this.visible,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String fieldKey;
  final bool visible;
  final void Function(String fieldKey, bool visible) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 13.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: visible ? _ink : _muted.withValues(alpha: 0.45),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                decoration: visible ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkResponse(
            onTap: () => onChanged(fieldKey, !visible),
            radius: 18,
            child: SizedBox.square(
              dimension: 28,
              child: Icon(
                visible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: visible ? _teal : _muted,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LabStore extends ChangeNotifier {
  static const _authKey = 'auth';
  static const _dataKey = 'labBuddyData';

  SharedPreferences? _prefs;
  bool isAuthenticated = false;
  String userName = '';
  String userEmail = '';
  String labName = '个人本地工作区';
  String? avatarPath;
  List<LabRun> todayRuns = [];
  List<LabRun> tomorrowRuns = [];
  List<LabRun> pastRuns = [];
  List<LabInventoryItem> inventory = [];
  List<LabProject> projects = [];
  List<LabTimer> timers = [];
  List<CalcHistoryItem> calcHistory = [];
  List<InventoryTransaction> inventoryTransactions = [];
  List<String> favoriteProtocolIds = [];
  List<String> recentProtocolIds = [];
  List<LabProtocol> protocols = [];
  List<BufferTemplate> bufferTemplates = [];
  List<SavedFormula> savedFormulas = [];
  List<String> customUnits = [];
  List<String> customAreas = [];
  List<String> customInventoryCategories = [];
  List<int> projectPaletteValues = List.of(defaultExperimentPalette);
  LabPreferences preferences = const LabPreferences();
  String lastOpenDate = '';
  Timer? _ticker;

  bool get needsNewDayRollover {
    final todayKey = _dayKey(DateTime.now());
    return (todayRuns.isNotEmpty || tomorrowRuns.isNotEmpty) &&
        lastOpenDate.isNotEmpty &&
        lastOpenDate != todayKey;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final authData = _prefs?.getString(_authKey);
    var shouldSaveAuth = false;
    if (authData != null) {
      final auth = jsonDecode(authData) as Map<String, dynamic>;
      isAuthenticated = auth['isAuthenticated'] == true;
      userName = auth['userName'] as String? ?? '';
      userEmail = auth['userEmail'] as String? ?? '';
      labName = auth['labName'] as String? ?? '个人本地工作区';
      final rawAvatarPath = auth['avatarPath'] as String?;
      avatarPath = _usableAvatarPath(rawAvatarPath);
      shouldSaveAuth = rawAvatarPath != null && avatarPath == null;
    }
    final data = _prefs?.getString(_dataKey);
    if (data == null) {
      _seed();
      await _saveData();
    } else {
      _decodeData(jsonDecode(data) as Map<String, dynamic>);
      final didRefreshRuns = _refreshSampleRunsForIosParity();
      final didRefreshProtocols = _refreshSampleProtocolsForIosParity();
      if (didRefreshRuns || didRefreshProtocols) {
        await _saveData();
      }
    }
    if (lastOpenDate.isEmpty) {
      lastOpenDate = _dayKey(DateTime.now());
      await _saveData();
    }
    if (shouldSaveAuth) await _saveAuth();
    _startTicker();
  }

  Future<void> signIn(String name, String email, {String? labName}) async {
    isAuthenticated = true;
    userName = name;
    userEmail = email;
    if (labName != null) {
      this.labName = labName.isEmpty ? '个人本地工作区' : labName;
    }
    await _saveAuth();
    notifyListeners();
  }

  Future<void> signOut() async {
    isAuthenticated = false;
    await _saveAuth();
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String labName,
    required String? avatarPath,
  }) async {
    userName = name;
    userEmail = email;
    this.labName = labName.isEmpty ? '个人本地工作区' : labName;
    this.avatarPath = _usableAvatarPath(avatarPath);
    await _saveAuth();
    notifyListeners();
  }

  Future<String?> pickAvatar() async {
    return _profileChannel.invokeMethod<String>('pickAvatarImage');
  }

  Future<void> _saveAuth() async {
    await _prefs?.setString(
      _authKey,
      jsonEncode({
        'isAuthenticated': isAuthenticated,
        'userName': userName,
        'userEmail': userEmail,
        'labName': labName,
        'avatarPath': _usableAvatarPath(avatarPath),
      }),
    );
  }

  Future<void> resetDemoData() async {
    _seed();
    await _saveData();
    notifyListeners();
  }

  Future<void> exportBackup() async {
    await _backupChannel.invokeMethod('shareBackup', {
      'fileName':
          'labbuddy-backup-${DateTime.now().toIso8601String().split(".").first.replaceAll(":", "-")}.json',
      'json': jsonEncode({
        'schema': 'labbuddy.android.backup',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'auth': {
          'userName': userName,
          'userEmail': userEmail,
          'labName': labName,
          'avatarPath': avatarPath,
        },
        'data': _dataSnapshot(),
      }),
    });
  }

  Future<bool> importBackup() async {
    final text = await _backupChannel.invokeMethod<String>('pickBackup');
    if (text == null || text.trim().isEmpty) return false;
    final root = jsonDecode(text) as Map<String, dynamic>;
    if (root['schema'] != 'labbuddy.android.backup' || root['data'] is! Map) {
      throw const FormatException('不是有效的 LabBuddy Android 备份文件');
    }
    final auth = root['auth'];
    if (auth is Map) {
      userName = auth['userName'] as String? ?? userName;
      userEmail = auth['userEmail'] as String? ?? userEmail;
      labName = auth['labName'] as String? ?? labName;
      avatarPath =
          _usableAvatarPath(auth['avatarPath'] as String?) ?? avatarPath;
      await _saveAuth();
    }
    _decodeData(Map<String, dynamic>.from(root['data'] as Map));
    await _saveData();
    notifyListeners();
    return true;
  }

  Future<void> updatePreferences({
    bool? largeBenchMode,
    bool? dataCardWatermark,
    bool? compactCards,
    bool? showStepDuration,
    bool? timerSound,
    bool? haptics,
    bool? autoSave,
    double? fontScale,
    String? colorScheme,
    String? apiBaseUrl,
    bool? isProUser,
    bool? voiceAnnouncementEnabled,
    String? voiceAnnouncementTemplate,
  }) async {
    preferences = preferences.copyWith(
      largeBenchMode: largeBenchMode,
      dataCardWatermark: dataCardWatermark,
      compactCards: compactCards,
      showStepDuration: showStepDuration,
      timerSound: timerSound,
      haptics: haptics,
      autoSave: autoSave,
      fontScale: fontScale,
      colorScheme: colorScheme,
      apiBaseUrl: apiBaseUrl == null
          ? null
          : _normalizedAuthApiBaseUrl(apiBaseUrl),
      isProUser: isProUser,
      voiceAnnouncementEnabled: voiceAnnouncementEnabled,
      voiceAnnouncementTemplate: voiceAnnouncementTemplate,
    );
    await _saveData();
    notifyListeners();
  }

  LabProject? projectFor(String? id) {
    if (id == null) return null;
    return projects.where((p) => p.id == id).firstOrNull;
  }

  LabRun? runById(String id) {
    return [
      ...todayRuns,
      ...tomorrowRuns,
      ...pastRuns,
    ].where((run) => run.id == id).firstOrNull;
  }

  int runCountForProject(String id) {
    return [
      ...todayRuns,
      ...tomorrowRuns,
      ...pastRuns,
    ].where((run) => run.projectId == id).length;
  }

  List<LabProtocol> get favoriteProtocols => favoriteProtocolIds
      .map((id) => protocols.where((protocol) => protocol.id == id).firstOrNull)
      .whereType<LabProtocol>()
      .toList();

  List<LabProtocol> get recentProtocols => recentProtocolIds
      .map((id) => protocols.where((protocol) => protocol.id == id).firstOrNull)
      .whereType<LabProtocol>()
      .toList();

  List<String> get unitOptions => {...builtInUnits, ...customUnits}.toList();

  List<String> get areaOptions =>
      {...builtInExperimentAreas, ...customAreas}.toList();

  List<int> get activeProjectPalette => List.of(defaultProjectPalette);

  List<int> get activeExperimentPalette => projectPaletteValues.isEmpty
      ? List.of(defaultExperimentPalette)
      : List.of(projectPaletteValues);

  List<String> get inventoryCategoryOptions {
    final values = {
      '培养基',
      '血清',
      '抗体',
      '试剂',
      '耗材',
      '抗生素',
      '缓冲液',
      '转染试剂',
      '核酸',
      '蛋白',
      ...inventory
          .map((item) => item.category.trim())
          .where((item) => item.isNotEmpty),
      ...customInventoryCategories,
    }.toList()..sort();
    return values;
  }

  bool isFavoriteProtocol(String id) => favoriteProtocolIds.contains(id);

  Future<void> toggleProtocolFavorite(String id) async {
    favoriteProtocolIds = favoriteProtocolIds.contains(id)
        ? favoriteProtocolIds.where((item) => item != id).toList()
        : [id, ...favoriteProtocolIds];
    await _saveData();
    notifyListeners();
  }

  Future<void> markProtocolRecent(String id) async {
    recentProtocolIds = [
      id,
      ...recentProtocolIds.where((item) => item != id),
    ].take(8).toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> addCustomUnit(String unit) async {
    final normalized = unit.trim();
    if (normalized.isEmpty || unitOptions.contains(normalized)) return;
    customUnits = [...customUnits, normalized];
    await _saveData();
    notifyListeners();
  }

  Future<void> removeCustomUnit(String unit) async {
    customUnits = customUnits.where((item) => item != unit).toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> addCustomArea(String area) async {
    final normalized = area.trim();
    if (normalized.isEmpty || areaOptions.contains(normalized)) return;
    customAreas = [...customAreas, normalized];
    await _saveData();
    notifyListeners();
  }

  Future<void> removeCustomArea(String area) async {
    customAreas = customAreas.where((item) => item != area).toList();
    protocols = protocols
        .map(
          (protocol) => protocol.area == area
              ? LabProtocol(
                  id: protocol.id,
                  name: protocol.name,
                  area: '细胞实验',
                  baseVolumeLabel: protocol.baseVolumeLabel,
                  baseScaleValue: protocol.baseScaleValue,
                  scaleUnit: protocol.scaleUnit,
                  expectedDuration: protocol.expectedDuration,
                  ingredients: protocol.ingredients,
                  variables: protocol.variables,
                  steps: protocol.steps,
                  sourceType: protocol.sourceType,
                  sourceTitle: protocol.sourceTitle,
                  confidence: protocol.confidence,
                )
              : protocol,
        )
        .toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> addInventoryCategory(String category) async {
    final normalized = category.trim();
    if (normalized.isEmpty || inventoryCategoryOptions.contains(normalized)) {
      return;
    }
    customInventoryCategories = [...customInventoryCategories, normalized];
    await _saveData();
    notifyListeners();
  }

  Future<void> removeInventoryCategory(String category) async {
    customInventoryCategories = customInventoryCategories
        .where((item) => item != category)
        .toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> updateProjectPalette(List<int> palette) async {
    projectPaletteValues = palette.isEmpty
        ? List.of(defaultExperimentPalette)
        : List.of(palette);
    await _saveData();
    notifyListeners();
  }

  Future<void> upsertProtocol({
    String? existingId,
    required String name,
    required String area,
    required String duration,
    required String scale,
    required double baseScaleValue,
    required String scaleUnit,
    required List<ProtocolIngredient> ingredients,
    required List<ProtocolVariable> variables,
    required List<LabStep> steps,
    String sourceType = _defaultProtocolSourceType,
    String sourceTitle = '手动创建',
    double confidence = 1.0,
  }) async {
    final protocol = LabProtocol(
      id: existingId ?? 'protocol-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      area: area,
      baseVolumeLabel: scale,
      baseScaleValue: baseScaleValue,
      scaleUnit: scaleUnit,
      expectedDuration: duration,
      ingredients: ingredients,
      variables: variables,
      steps: steps,
      sourceType: _normalizeProtocolSourceType(sourceType),
      sourceTitle: sourceTitle,
      confidence: confidence,
    );
    if (existingId == null) {
      protocols = [protocol, ...protocols];
    } else {
      protocols = protocols
          .map((item) => item.id == existingId ? protocol : item)
          .toList();
    }
    recentProtocolIds = [protocol.id, ...recentProtocolIds].take(8).toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> moveProtocol(String id, int delta) async {
    final currentIndex = protocols.indexWhere((protocol) => protocol.id == id);
    if (currentIndex == -1) return;
    final targetIndex = (currentIndex + delta).clamp(0, protocols.length - 1);
    if (targetIndex == currentIndex) return;
    final updated = List<LabProtocol>.of(protocols);
    final protocol = updated.removeAt(currentIndex);
    updated.insert(targetIndex, protocol);
    protocols = updated;
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteProtocol(String id) async {
    protocols = protocols.where((protocol) => protocol.id != id).toList();
    favoriteProtocolIds = favoriteProtocolIds
        .where((protocolId) => protocolId != id)
        .toList();
    recentProtocolIds = recentProtocolIds
        .where((protocolId) => protocolId != id)
        .toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> addRun({
    required DayMode target,
    required String title,
    required String area,
    required String timeLabel,
    required LabProtocol? protocol,
    required String scale,
    required String? projectId,
    DateTime? date,
  }) async {
    if (protocol != null) {
      await markProtocolRecent(protocol.id);
    }
    final steps = (protocol?.steps ?? manualSteps)
        .map(
          (step) => step.copyWith(
            id: '${step.id}-${DateTime.now().microsecondsSinceEpoch}',
          ),
        )
        .toList();
    final run = LabRun(
      id: 'run-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      area: area,
      timeLabel: timeLabel,
      status: target == DayMode.tomorrow ? '已排期' : '待开始',
      protocolName: protocol?.name ?? 'Manual experiment',
      scaledVolumeLabel: scale,
      projectId: projectId,
      planDateKey: target == DayMode.tomorrow
          ? _dayKey(date ?? DateTime.now().add(const Duration(days: 1)))
          : null,
      steps: steps,
    );
    if (target == DayMode.tomorrow) {
      tomorrowRuns = [...tomorrowRuns, run]..sort(_byTime);
    } else {
      todayRuns = [...todayRuns, run]..sort(_byTime);
    }
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteRun(String id, DayMode target, {DateTime? date}) async {
    if (target == DayMode.tomorrow) {
      final targetDayKey = date == null ? null : _dayKey(date);
      tomorrowRuns = tomorrowRuns.where((run) {
        if (run.id != id) return true;
        if (targetDayKey == null) return false;
        return (run.planDateKey ?? _defaultTomorrowKey()) != targetDayKey;
      }).toList();
    } else {
      todayRuns = todayRuns.where((run) => run.id != id).toList();
    }
    timers = timers.where((timer) => timer.runId != id).toList();
    await _saveData();
    notifyListeners();
  }

  List<LabRun> futureRunsForDate(DateTime date) {
    final key = _dayKey(date);
    return tomorrowRuns
        .where((run) => (run.planDateKey ?? _defaultTomorrowKey()) == key)
        .toList()
      ..sort(_byTime);
  }

  Future<void> updateRun(LabRun updated) async {
    todayRuns = _updateRunInRuns(todayRuns, updated)..sort(_byTime);
    tomorrowRuns = _updateRunInRuns(tomorrowRuns, updated)..sort(_byTime);
    pastRuns = _updateRunInRuns(pastRuns, updated)..sort(_byTime);
    timers = timers.map((timer) {
      if (timer.runId != updated.id) return timer;
      final stepId = timer.id.startsWith('${updated.id}-')
          ? timer.id.substring(updated.id.length + 1)
          : '';
      final updatedStep = updated.steps
          .where((step) => step.id == stepId)
          .firstOrNull;
      return timer.copyWith(
        runTitle: updated.title,
        stepTitle: updatedStep?.title,
      );
    }).toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> toggleStep(String runId, String stepId) async {
    todayRuns = _toggleInRuns(todayRuns, runId, stepId);
    tomorrowRuns = _toggleInRuns(tomorrowRuns, runId, stepId);
    pastRuns = _toggleInRuns(pastRuns, runId, stepId);
    await _saveData();
    notifyListeners();
  }

  Future<void> updateRunSteps(String runId, List<LabStep> steps) async {
    todayRuns = _updateRunStepsInRuns(todayRuns, runId, steps);
    tomorrowRuns = _updateRunStepsInRuns(tomorrowRuns, runId, steps);
    pastRuns = _updateRunStepsInRuns(pastRuns, runId, steps);
    await _saveData();
    notifyListeners();
  }

  Future<void> updateRunStep(String runId, LabStep updatedStep) async {
    todayRuns = _updateSingleRunStepInRuns(todayRuns, runId, updatedStep);
    tomorrowRuns = _updateSingleRunStepInRuns(tomorrowRuns, runId, updatedStep);
    pastRuns = _updateSingleRunStepInRuns(pastRuns, runId, updatedStep);
    timers = timers
        .map(
          (timer) => timer.id == '$runId-${updatedStep.id}'
              ? timer.copyWith(stepTitle: updatedStep.title)
              : timer,
        )
        .toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteRunStep(String runId, String stepId) async {
    todayRuns = _deleteRunStepInRuns(todayRuns, runId, stepId);
    tomorrowRuns = _deleteRunStepInRuns(tomorrowRuns, runId, stepId);
    pastRuns = _deleteRunStepInRuns(pastRuns, runId, stepId);
    timers = timers.where((timer) => timer.id != '$runId-$stepId').toList();
    await _cancelTimerNotification('$runId-$stepId');
    await _saveData();
    notifyListeners();
  }

  Future<void> startTimer(
    LabRun run,
    LabStep step, {
    int? customMinutes,
    int? customSeconds,
  }) async {
    final seconds = math.max(
      1,
      customSeconds ?? ((customMinutes ?? step.durationMinutes ?? 1) * 60),
    );
    final timer = LabTimer(
      id: '${run.id}-${step.id}',
      runId: run.id,
      runTitle: run.title,
      stepTitle: step.title,
      endsAtMs: DateTime.now()
          .add(Duration(seconds: seconds))
          .millisecondsSinceEpoch,
    );
    final replacedTimers = timers.where((item) => item.runId == run.id);
    for (final replaced in replacedTimers) {
      await _cancelTimerNotification(replaced.id);
    }
    timers = [...timers.where((item) => item.runId != run.id), timer];
    await _scheduleTimerNotification(timer);
    await _saveData();
    notifyListeners();
  }

  Future<void> stopTimer(String id) async {
    timers = timers.where((timer) => timer.id != id).toList();
    await _cancelTimerNotification(id);
    await _saveData();
    notifyListeners();
  }

  Future<void> pauseTimer(String id) async {
    timers = timers
        .map(
          (timer) => timer.id == id && !timer.isPaused
              ? timer.copyWith(pausedRemainingSeconds: timer.remainingSeconds)
              : timer,
        )
        .toList();
    await _cancelTimerNotification(id);
    await _saveData();
    notifyListeners();
  }

  Future<void> resumeTimer(String id) async {
    LabTimer? resumed;
    timers = timers.map((timer) {
      if (timer.id != id || !timer.isPaused) return timer;
      resumed = timer.copyWith(
        endsAtMs: DateTime.now()
            .add(Duration(seconds: timer.remainingSeconds))
            .millisecondsSinceEpoch,
        clearPausedRemainingSeconds: true,
      );
      return resumed!;
    }).toList();
    if (resumed != null) {
      await _scheduleTimerNotification(resumed!);
    }
    await _saveData();
    notifyListeners();
  }

  Future<void> _scheduleTimerNotification(LabTimer timer) async {
    if (timer.isPaused || timer.remainingSeconds <= 0) return;
    try {
      await _timerChannel.invokeMethod('scheduleTimerNotification', {
        'id': timer.id,
        'runTitle': timer.runTitle,
        'stepTitle': timer.stepTitle,
        'endsAtMs': timer.endsAtMs,
      });
    } catch (_) {
      // In-app timers still work if Android notification permission is denied.
    }
  }

  Future<void> _cancelTimerNotification(String id) async {
    try {
      await _timerChannel.invokeMethod('cancelTimerNotification', {'id': id});
    } catch (_) {
      // Notification cancellation is best effort.
    }
  }

  Future<void> endDay({DateTime? promoteDate}) async {
    for (final timer in timers) {
      await _cancelTimerNotification(timer.id);
    }
    timers = [];
    final todayKey = _dayKey(DateTime.now());
    pastRuns = [
      ...todayRuns.map(
        (run) => run.copyWith(
          id: run.id.startsWith('past-') ? run.id : 'past-$todayKey-${run.id}',
        ),
      ),
      ...pastRuns,
    ];
    final promoteKey = promoteDate == null
        ? _defaultTomorrowKey()
        : _dayKey(promoteDate);
    final nextTodayRuns = tomorrowRuns
        .where((run) => (run.planDateKey ?? promoteKey) == promoteKey)
        .map((run) => run.copyWith(status: '已排期', clearPlanDateKey: true))
        .toList();
    todayRuns = nextTodayRuns..sort(_byTime);
    tomorrowRuns =
        tomorrowRuns
            .where((run) => (run.planDateKey ?? promoteKey) != promoteKey)
            .toList()
          ..sort(_byTime);
    lastOpenDate = _dayKey(DateTime.now());
    await _saveData();
    notifyListeners();
  }

  Future<void> confirmNewDayRollover() async {
    await endDay(promoteDate: DateTime.now());
  }

  Future<void> dismissNewDayRollover() async {
    lastOpenDate = _dayKey(DateTime.now());
    await _saveData();
    notifyListeners();
  }

  Future<void> addInventory({
    required String name,
    required String category,
    required double quantity,
    required double threshold,
    required String unit,
    required String storage,
    String supplier = '',
    String lotNumber = '',
    String notes = '',
  }) async {
    final item = LabInventoryItem(
      id: 'inv-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      category: category,
      quantity: quantity,
      unit: unit,
      threshold: threshold,
      storage: storage,
      supplier: supplier,
      lotNumber: lotNumber,
      notes: notes,
    );
    inventory = [...inventory, item];
    await _saveData();
    notifyListeners();
  }

  Future<void> updateInventory(LabInventoryItem updated) async {
    inventory = inventory
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteInventory(String id) async {
    inventory = inventory.where((item) => item.id != id).toList();
    inventoryTransactions = inventoryTransactions
        .where((tx) => tx.itemId != id)
        .toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> adjustInventory(String id, double delta) async {
    final item = inventory.where((entry) => entry.id == id).firstOrNull;
    inventory = inventory
        .map(
          (item) => item.id == id
              ? item.copyWith(
                  quantity: (item.quantity + delta).clamp(0, double.infinity),
                )
              : item,
        )
        .toList();
    if (item != null) {
      inventoryTransactions = [
        InventoryTransaction.create(
          item: item,
          delta: delta,
          note: delta < 0 ? '手动扣减' : '手动补货',
        ),
        ...inventoryTransactions,
      ].take(50).toList();
    }
    await _saveData();
    notifyListeners();
  }

  Future<void> addProject(
    String name,
    String description,
    int colorValue,
    int? endsAtMs,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    projects = [
      ...projects,
      LabProject(
        id: 'proj-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        description: description,
        colorValue: colorValue,
        createdAtMs: now,
        endsAtMs: endsAtMs,
      ),
    ];
    await _saveData();
    notifyListeners();
  }

  Future<void> updateProject(LabProject updated) async {
    projects = projects
        .map((project) => project.id == updated.id ? updated : project)
        .toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    projects = projects.where((project) => project.id != id).toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> addCalcHistory(
    String title,
    String result, {
    String? mode,
    Map<String, double> inputs = const {},
  }) async {
    final filtered = mode == null
        ? calcHistory
        : calcHistory
              .where((item) => item.mode != mode || item.title != title)
              .toList();
    calcHistory = [
      CalcHistoryItem(
        id: 'calc-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        result: result,
        mode: mode,
        inputs: inputs,
      ),
      ...filtered,
    ].take(50).toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> clearCalcHistory() async {
    calcHistory = [];
    await _saveData();
    notifyListeners();
  }

  Future<void> upsertBufferTemplate(BufferTemplate template) async {
    final exists = bufferTemplates.any((item) => item.id == template.id);
    bufferTemplates = exists
        ? bufferTemplates
              .map((item) => item.id == template.id ? template : item)
              .toList()
        : [...bufferTemplates, template];
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteBufferTemplate(String id) async {
    if (_isSampleBufferTemplateId(id)) return;
    bufferTemplates = bufferTemplates.where((item) => item.id != id).toList();
    await _saveData();
    notifyListeners();
  }

  Future<void> upsertSavedFormula(SavedFormula formula) async {
    final exists = savedFormulas.any((item) => item.id == formula.id);
    savedFormulas = exists
        ? savedFormulas
              .map((item) => item.id == formula.id ? formula : item)
              .toList()
        : [
            formula,
            ...savedFormulas.where(
              (item) =>
                  item.label != formula.label ||
                  item.formula != formula.formula,
            ),
          ];
    await _saveData();
    notifyListeners();
  }

  Future<void> deleteSavedFormula(String id) async {
    savedFormulas = savedFormulas.where((item) => item.id != id).toList();
    await _saveData();
    notifyListeners();
  }

  void _seed() {
    protocols = List.of(sampleProtocols);
    bufferTemplates = List.of(sampleBufferTemplates);
    favoriteProtocolIds = ['cell-passage-protocol'];
    recentProtocolIds = ['cell-passage-protocol', 'miniprep-protocol'];
    projects = const [
      LabProject(
        id: 'proj-ace2',
        name: '2026 博士课题',
        description: '博士课题：细胞实验、转染验证和机制研究',
        colorValue: 0xFF30B0C7,
      ),
      LabProject(
        id: 'proj-wb',
        name: '2026 师兄的课题',
        description: '师兄课题：质粒构建、样品准备和协助验证',
        colorValue: 0xFF5856D6,
      ),
      LabProject(
        id: 'proj-coop',
        name: '2026 合作课题',
        description: '合作课题：蛋白表达、WB、ELISA 和 BLI 检测',
        colorValue: 0xFFFF9500,
      ),
    ];
    todayRuns = sampleRuns;
    tomorrowRuns = [
      sampleRuns[1].copyWith(
        id: 'tomorrow-miniprep',
        timeLabel: '10:30',
        status: '已排期',
        planDateKey: _defaultTomorrowKey(),
      ),
    ];
    pastRuns = [
      sampleRuns[0].copyWith(
        id: 'past-${_dayKey(DateTime.now().subtract(const Duration(days: 1)))}-cell',
        status: '已归档',
      ),
      sampleRuns[2].copyWith(
        id: 'past-${_dayKey(DateTime.now().subtract(const Duration(days: 3)))}-wb',
        status: '已归档',
      ),
    ];
    inventory = const [
      LabInventoryItem(
        id: 'inv-dmem',
        name: 'DMEM high glucose',
        category: '培养基',
        quantity: 680,
        unit: 'ml',
        threshold: 50,
        storage: '4°C',
      ),
      LabInventoryItem(
        id: 'inv-fbs',
        name: 'FBS',
        category: '血清',
        quantity: 42,
        unit: 'ml',
        threshold: 50,
        storage: '-20°C',
      ),
      LabInventoryItem(
        id: 'inv-penstrep',
        name: 'Pen/Strep 双抗',
        category: '抗生素',
        quantity: 23,
        unit: 'ml',
        threshold: 5,
        storage: '4°C',
      ),
      LabInventoryItem(
        id: 'inv-trypsin',
        name: 'Trypsin-EDTA',
        category: '消化液',
        quantity: 36,
        unit: 'ml',
        threshold: 10,
        storage: '4°C',
      ),
      LabInventoryItem(
        id: 'inv-opti',
        name: 'Opti-MEM',
        category: '培养基',
        quantity: 120,
        unit: 'ml',
        threshold: 20,
        storage: '4°C',
      ),
      LabInventoryItem(
        id: 'inv-lipo3000',
        name: 'Lipo3000',
        category: '转染试剂',
        quantity: 1.6,
        unit: 'ml',
        threshold: 0.2,
        storage: '4°C',
      ),
      LabInventoryItem(
        id: 'inv-lipo2000',
        name: 'Lipo2000',
        category: '转染试剂',
        quantity: 0.9,
        unit: 'ml',
        threshold: 0.2,
        storage: '4°C',
      ),
      LabInventoryItem(
        id: 'inv-pbs',
        name: '1x PBS',
        category: '缓冲液',
        quantity: 820,
        unit: 'ml',
        threshold: 100,
        storage: 'RT',
      ),
      LabInventoryItem(
        id: 'inv-tbst',
        name: '1x TBST',
        category: '缓冲液',
        quantity: 460,
        unit: 'ml',
        threshold: 100,
        storage: 'RT',
      ),
      LabInventoryItem(
        id: 'inv-ripa',
        name: 'RIPA 裂解液',
        category: '裂解液',
        quantity: 18,
        unit: 'ml',
        threshold: 5,
        storage: '4°C',
      ),
      LabInventoryItem(
        id: 'inv-bsa',
        name: 'BSA',
        category: '蛋白',
        quantity: 3.2,
        unit: 'g',
        threshold: 0.5,
        storage: '4°C',
      ),
      LabInventoryItem(
        id: 'inv-skim',
        name: '脱脂奶粉',
        category: '封闭液',
        quantity: 24,
        unit: 'g',
        threshold: 5,
        storage: 'RT',
      ),
      LabInventoryItem(
        id: 'inv-ecl',
        name: 'ECL 显影液',
        category: '显影',
        quantity: 14,
        unit: 'ml',
        threshold: 3,
        storage: '4°C',
      ),
      LabInventoryItem(
        id: 'inv-dna-ladder',
        name: 'DNA Ladder',
        category: '核酸',
        quantity: 80,
        unit: 'μl',
        threshold: 10,
        storage: '-20°C',
      ),
      LabInventoryItem(
        id: 'inv-agarose',
        name: 'Agarose',
        category: '核酸',
        quantity: 92,
        unit: 'g',
        threshold: 10,
        storage: 'RT',
      ),
      LabInventoryItem(
        id: 'inv-kan',
        name: 'Kanamycin',
        category: '抗生素',
        quantity: 6,
        unit: 'ml',
        threshold: 1,
        storage: '-20°C',
      ),
      LabInventoryItem(
        id: 'inv-amp',
        name: 'Ampicillin',
        category: '抗生素',
        quantity: 9,
        unit: 'ml',
        threshold: 1,
        storage: '-20°C',
      ),
    ];
    timers = [];
    calcHistory = [];
    inventoryTransactions = [];
    customUnits = [];
    customAreas = [];
    customInventoryCategories = [];
    projectPaletteValues = List.of(defaultExperimentPalette);
    preferences = const LabPreferences();
    lastOpenDate = _dayKey(DateTime.now());
  }

  void _decodeData(Map<String, dynamic> data) {
    todayRuns = _list(data['todayRuns'], LabRun.fromJson);
    tomorrowRuns = _list(data['tomorrowRuns'], LabRun.fromJson);
    pastRuns = _list(data['pastRuns'], LabRun.fromJson);
    inventory = _list(data['inventory'], LabInventoryItem.fromJson);
    projects = _list(data['projects'], LabProject.fromJson);
    timers = _list(data['timers'], LabTimer.fromJson);
    calcHistory = _list(data['calcHistory'], CalcHistoryItem.fromJson);
    inventoryTransactions = _list(
      data['inventoryTransactions'],
      InventoryTransaction.fromJson,
    );
    protocols = _list(data['protocols'], LabProtocol.fromJson);
    bufferTemplates = _list(data['bufferTemplates'], BufferTemplate.fromJson);
    savedFormulas = _list(data['savedFormulas'], SavedFormula.fromJson);
    if (bufferTemplates.isEmpty) {
      bufferTemplates = List.of(sampleBufferTemplates);
    }
    final preferenceData = data['preferences'];
    preferences = preferenceData is Map
        ? LabPreferences.fromJson(Map<String, dynamic>.from(preferenceData))
        : const LabPreferences();
    if (protocols.isEmpty) protocols = List.of(sampleProtocols);
    favoriteProtocolIds = (data['favoriteProtocolIds'] as List? ?? [])
        .whereType<String>()
        .toList();
    recentProtocolIds = (data['recentProtocolIds'] as List? ?? [])
        .whereType<String>()
        .toList();
    customUnits = (data['customUnits'] as List? ?? [])
        .whereType<String>()
        .toList();
    customAreas = (data['customAreas'] as List? ?? [])
        .whereType<String>()
        .toList();
    customInventoryCategories =
        (data['customInventoryCategories'] as List? ?? [])
            .whereType<String>()
            .toList();
    lastOpenDate =
        data['lastOpenDate'] as String? ??
        data['lastLabBuddyOpenDate'] as String? ??
        '';
    tomorrowRuns = _normalizeFutureRunDates(tomorrowRuns, lastOpenDate);
    projectPaletteValues = _intList(data['projectPaletteValues']);
    if (projectPaletteValues.isEmpty ||
        _samePalette(projectPaletteValues, defaultProjectPalette) ||
        _samePalette(
          projectPaletteValues,
          defaultProjectPalette.take(8).toList(),
        )) {
      projectPaletteValues = List.of(defaultExperimentPalette);
    }
    if (todayRuns.isEmpty && inventory.isEmpty) _seed();
  }

  List<LabRun> _normalizeFutureRunDates(
    List<LabRun> runs,
    String lastOpenDateKey,
  ) {
    final lastOpenDate = _dateFromDayKey(lastOpenDateKey);
    final fallbackKey = lastOpenDateKey.isEmpty
        ? _defaultTomorrowKey()
        : _dayKey(lastOpenDate.add(const Duration(days: 1)));
    return runs
        .map(
          (run) => run.planDateKey == null
              ? run.copyWith(planDateKey: fallbackKey)
              : run,
        )
        .toList()
      ..sort(_byTime);
  }

  bool _refreshSampleRunsForIosParity() {
    var changed = false;
    final sampleRunById = {for (final run in sampleRuns) run.id: run};

    List<LabRun> refreshRuns(List<LabRun> runs) {
      return runs.map((run) {
        final sample = sampleRunById[run.id];
        if (sample == null || run.steps.length == sample.steps.length) {
          return run;
        }
        changed = true;
        return run.copyWith(steps: sample.steps);
      }).toList();
    }

    todayRuns = refreshRuns(todayRuns);
    tomorrowRuns = refreshRuns(tomorrowRuns);
    pastRuns = refreshRuns(pastRuns);
    return changed;
  }

  bool _refreshSampleProtocolsForIosParity() {
    var changed = false;
    final sampleProtocolById = {
      for (final protocol in sampleProtocols) protocol.id: protocol,
    };
    protocols = protocols.map((protocol) {
      final sample = sampleProtocolById[protocol.id];
      if (sample == null) return protocol;
      final sameIngredientCount =
          protocol.ingredients.length == sample.ingredients.length;
      final sameFirstIngredients =
          protocol.ingredients.take(3).map((item) => item.name).join('|') ==
          sample.ingredients.take(3).map((item) => item.name).join('|');
      if (sameIngredientCount && sameFirstIngredients) return protocol;
      changed = true;
      return sample;
    }).toList();
    return changed;
  }

  List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) decode) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => decode(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _saveData() async {
    await _prefs?.setString(_dataKey, jsonEncode(_dataSnapshot()));
  }

  Map<String, dynamic> _dataSnapshot() => {
    'todayRuns': todayRuns.map((run) => run.toJson()).toList(),
    'tomorrowRuns': tomorrowRuns.map((run) => run.toJson()).toList(),
    'pastRuns': pastRuns.map((run) => run.toJson()).toList(),
    'inventory': inventory.map((item) => item.toJson()).toList(),
    'projects': projects.map((project) => project.toJson()).toList(),
    'timers': timers.map((timer) => timer.toJson()).toList(),
    'calcHistory': calcHistory.map((item) => item.toJson()).toList(),
    'inventoryTransactions': inventoryTransactions
        .map((item) => item.toJson())
        .toList(),
    'protocols': protocols.map((protocol) => protocol.toJson()).toList(),
    'bufferTemplates': bufferTemplates
        .map((template) => template.toJson())
        .toList(),
    'savedFormulas': savedFormulas.map((formula) => formula.toJson()).toList(),
    'favoriteProtocolIds': favoriteProtocolIds,
    'recentProtocolIds': recentProtocolIds,
    'customUnits': customUnits,
    'customAreas': customAreas,
    'customInventoryCategories': customInventoryCategories,
    'projectPaletteValues': projectPaletteValues,
    'preferences': preferences.toJson(),
    'lastOpenDate': lastOpenDate,
  };

  List<int> _intList(Object? value) {
    if (value is! List) return [];
    return value
        .map((item) {
          if (item is int) return item;
          if (item is num) return item.toInt();
          return null;
        })
        .whereType<int>()
        .toList();
  }

  bool _samePalette(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final active = timers
          .where((timer) => timer.isPaused || timer.remainingSeconds > 0)
          .toList();
      if (active.length != timers.length) {
        timers = active;
        _saveData();
      }
      notifyListeners();
    });
  }

  List<LabRun> _toggleInRuns(List<LabRun> runs, String runId, String stepId) {
    return runs
        .map(
          (run) => run.id == runId
              ? run.copyWith(
                  status: run.status == '待开始' ? '进行中' : run.status,
                  steps: run.steps
                      .map(
                        (step) => step.id == stepId
                            ? step.copyWith(done: !step.done)
                            : step,
                      )
                      .toList(),
                )
              : run,
        )
        .toList();
  }

  List<LabRun> _updateRunInRuns(List<LabRun> runs, LabRun updated) {
    return runs.map((run) => run.id == updated.id ? updated : run).toList();
  }

  List<LabRun> _updateRunStepsInRuns(
    List<LabRun> runs,
    String runId,
    List<LabStep> steps,
  ) {
    return runs
        .map(
          (run) => run.id == runId
              ? run.copyWith(
                  status: run.status == '待开始' ? '进行中' : run.status,
                  steps: steps,
                )
              : run,
        )
        .toList();
  }

  List<LabRun> _updateSingleRunStepInRuns(
    List<LabRun> runs,
    String runId,
    LabStep updatedStep,
  ) {
    return runs
        .map(
          (run) => run.id == runId
              ? run.copyWith(
                  status: run.status == '待开始' ? '进行中' : run.status,
                  steps: run.steps
                      .map(
                        (step) =>
                            step.id == updatedStep.id ? updatedStep : step,
                      )
                      .toList(),
                )
              : run,
        )
        .toList();
  }

  List<LabRun> _deleteRunStepInRuns(
    List<LabRun> runs,
    String runId,
    String stepId,
  ) {
    return runs
        .map(
          (run) => run.id == runId
              ? run.copyWith(
                  status: run.status == '待开始' ? '进行中' : run.status,
                  steps: run.steps.where((step) => step.id != stepId).toList(),
                )
              : run,
        )
        .toList();
  }

  int _byTime(LabRun a, LabRun b) => a.timeLabel.compareTo(b.timeLabel);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

enum DayMode { past, today, tomorrow }

class LabRun {
  const LabRun({
    required this.id,
    required this.title,
    required this.area,
    required this.timeLabel,
    required this.status,
    required this.protocolName,
    required this.scaledVolumeLabel,
    required this.projectId,
    this.planDateKey,
    required this.steps,
  });

  final String id;
  final String title;
  final String area;
  final String timeLabel;
  final String status;
  final String protocolName;
  final String scaledVolumeLabel;
  final String? projectId;
  final String? planDateKey;
  final List<LabStep> steps;

  int get completedCount => steps.where((step) => step.done).length;

  LabRun copyWith({
    String? id,
    String? title,
    String? area,
    String? timeLabel,
    String? status,
    String? protocolName,
    String? scaledVolumeLabel,
    String? projectId,
    bool clearProjectId = false,
    String? planDateKey,
    bool clearPlanDateKey = false,
    List<LabStep>? steps,
  }) {
    return LabRun(
      id: id ?? this.id,
      title: title ?? this.title,
      area: area ?? this.area,
      timeLabel: timeLabel ?? this.timeLabel,
      status: status ?? this.status,
      protocolName: protocolName ?? this.protocolName,
      scaledVolumeLabel: scaledVolumeLabel ?? this.scaledVolumeLabel,
      projectId: clearProjectId ? null : projectId ?? this.projectId,
      planDateKey: clearPlanDateKey ? null : planDateKey ?? this.planDateKey,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'area': area,
    'timeLabel': timeLabel,
    'status': status,
    'protocolName': protocolName,
    'scaledVolumeLabel': scaledVolumeLabel,
    'projectId': projectId,
    'planDateKey': planDateKey,
    'steps': steps.map((step) => step.toJson()).toList(),
  };

  factory LabRun.fromJson(Map<String, dynamic> json) => LabRun(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    area: json['area'] as String? ?? '',
    timeLabel: json['timeLabel'] as String? ?? '',
    status: json['status'] as String? ?? '',
    protocolName: json['protocolName'] as String? ?? '',
    scaledVolumeLabel: json['scaledVolumeLabel'] as String? ?? '',
    projectId: json['projectId'] as String?,
    planDateKey: json['planDateKey'] as String?,
    steps: (json['steps'] as List? ?? [])
        .whereType<Map>()
        .map((item) => LabStep.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
  );
}

class LabStep {
  const LabStep({
    required this.id,
    required this.title,
    required this.detail,
    required this.durationMinutes,
    required this.carryOver,
    required this.reagents,
    this.done = false,
  });

  final String id;
  final String title;
  final String detail;
  final int? durationMinutes;
  final bool carryOver;
  final List<StepReagent> reagents;
  final bool done;

  LabStep copyWith({
    String? id,
    String? title,
    String? detail,
    int? durationMinutes,
    bool clearDurationMinutes = false,
    bool? carryOver,
    List<StepReagent>? reagents,
    bool? done,
  }) {
    return LabStep(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      durationMinutes: clearDurationMinutes
          ? null
          : durationMinutes ?? this.durationMinutes,
      carryOver: carryOver ?? this.carryOver,
      reagents: reagents ?? this.reagents,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'detail': detail,
    'durationMinutes': durationMinutes,
    'carryOver': carryOver,
    'reagents': reagents.map((reagent) => reagent.toJson()).toList(),
    'done': done,
  };

  factory LabStep.fromJson(Map<String, dynamic> json) => LabStep(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    detail: json['detail'] as String? ?? '',
    durationMinutes: json['durationMinutes'] as int?,
    carryOver: json['carryOver'] == true,
    reagents: (json['reagents'] as List? ?? [])
        .whereType<Map>()
        .map((item) => StepReagent.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    done: json['done'] == true,
  );
}

class StepReagent {
  const StepReagent({
    this.id = '',
    required this.name,
    String? amount,
    String? amountExpression,
    required this.unit,
    this.isFormula = false,
  }) : amountExpression = amountExpression ?? amount ?? '';

  final String id;
  final String name;
  final String amountExpression;
  final String unit;
  final bool isFormula;

  String get amount => amountExpression;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amountExpression,
    'amountExpression': amountExpression,
    'unit': unit,
    'isFormula': isFormula,
  };

  factory StepReagent.fromJson(Map<String, dynamic> json) => StepReagent(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    amountExpression:
        json['amountExpression'] as String? ?? json['amount'] as String? ?? '',
    unit: json['unit'] as String? ?? '',
    isFormula:
        json['isFormula'] as bool? ??
        _looksLikeFormulaExpression(
          json['amountExpression'] as String? ??
              json['amount'] as String? ??
              '',
        ),
  );
}

bool _looksLikeFormulaExpression(String expression) {
  final trimmed = expression.trim();
  if (trimmed.isEmpty) return false;
  if (double.tryParse(trimmed) != null) return false;
  return RegExp(r'[A-Za-z_\u4e00-\u9fff]').hasMatch(trimmed);
}

class LabProtocol {
  const LabProtocol({
    required this.id,
    required this.name,
    required this.area,
    required this.baseVolumeLabel,
    this.baseScaleValue = 1,
    this.scaleUnit = 'reaction',
    required this.expectedDuration,
    required this.ingredients,
    this.variables = const [],
    required this.steps,
    this.sourceType = _defaultProtocolSourceType,
    this.sourceTitle = '',
    this.confidence = 1.0,
  });

  final String id;
  final String name;
  final String area;
  final String baseVolumeLabel;
  final double baseScaleValue;
  final String scaleUnit;
  final String expectedDuration;
  final List<ProtocolIngredient> ingredients;
  final List<ProtocolVariable> variables;
  final List<LabStep> steps;
  final String sourceType;
  final String sourceTitle;
  final double confidence;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'area': area,
    'baseVolumeLabel': baseVolumeLabel,
    'baseScaleValue': baseScaleValue,
    'scaleUnit': scaleUnit,
    'expectedDuration': expectedDuration,
    'ingredients': ingredients.map((item) => item.toJson()).toList(),
    'variables': variables.map((variable) => variable.toJson()).toList(),
    'steps': steps.map((step) => step.toJson()).toList(),
    'sourceType': sourceType,
    'sourceTitle': sourceTitle,
    'confidence': confidence,
  };

  factory LabProtocol.fromJson(Map<String, dynamic> json) {
    final sourceTitle = json['sourceTitle'] as String? ?? '';
    return LabProtocol(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      area: json['area'] as String? ?? '细胞实验',
      baseVolumeLabel: json['baseVolumeLabel'] as String? ?? '',
      baseScaleValue: (json['baseScaleValue'] as num?)?.toDouble() ?? 1,
      scaleUnit: json['scaleUnit'] as String? ?? 'reaction',
      expectedDuration: json['expectedDuration'] as String? ?? '',
      ingredients: (json['ingredients'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                ProtocolIngredient.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      variables: (json['variables'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                ProtocolVariable.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      steps: (json['steps'] as List? ?? [])
          .whereType<Map>()
          .map((item) => LabStep.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      sourceType: _normalizeProtocolSourceType(
        json['sourceType'] as String? ??
            _sourceTypeFromLegacyTitle(sourceTitle),
      ),
      sourceTitle: _sourceTitleWithoutLegacyPrefix(sourceTitle),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class ProtocolIngredient {
  const ProtocolIngredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  final String name;
  final double amount;
  final String unit;

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
  };

  factory ProtocolIngredient.fromJson(Map<String, dynamic> json) =>
      ProtocolIngredient(
        name: json['name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
      );
}

class ProtocolVariable {
  const ProtocolVariable({
    required this.id,
    required this.symbol,
    required this.name,
    required this.baseValue,
    required this.unit,
    required this.isScalable,
    this.minValue,
    this.maxValue,
  });

  final String id;
  final String symbol;
  final String name;
  final double baseValue;
  final String unit;
  final bool isScalable;
  final double? minValue;
  final double? maxValue;

  double get computedBaseValue => baseValue;

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'name': name,
    'baseValue': baseValue,
    'unit': unit,
    'isScalable': isScalable,
    'minValue': minValue,
    'maxValue': maxValue,
  };

  factory ProtocolVariable.fromJson(Map<String, dynamic> json) =>
      ProtocolVariable(
        id: json['id'] as String? ?? _draftId('variable'),
        symbol: json['symbol'] as String? ?? '',
        name: json['name'] as String? ?? '',
        baseValue: (json['baseValue'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
        isScalable: json['isScalable'] as bool? ?? true,
        minValue: (json['minValue'] as num?)?.toDouble(),
        maxValue: (json['maxValue'] as num?)?.toDouble(),
      );
}

class BufferTemplate {
  const BufferTemplate({
    required this.id,
    required this.name,
    required this.area,
    required this.baseVolume,
    required this.volumeUnit,
    required this.ingredients,
  });

  final String id;
  final String name;
  final String area;
  final double baseVolume;
  final String volumeUnit;
  final List<BufferIngredient> ingredients;

  BufferTemplate copyWith({
    String? name,
    String? area,
    double? baseVolume,
    String? volumeUnit,
    List<BufferIngredient>? ingredients,
  }) => BufferTemplate(
    id: id,
    name: name ?? this.name,
    area: area ?? this.area,
    baseVolume: baseVolume ?? this.baseVolume,
    volumeUnit: volumeUnit ?? this.volumeUnit,
    ingredients: ingredients ?? this.ingredients,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'area': area,
    'baseVolume': baseVolume,
    'volumeUnit': volumeUnit,
    'ingredients': ingredients.map((item) => item.toJson()).toList(),
  };

  factory BufferTemplate.fromJson(Map<String, dynamic> json) => BufferTemplate(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    area: json['area'] as String? ?? '细胞实验',
    baseVolume: (json['baseVolume'] as num?)?.toDouble() ?? 100,
    volumeUnit: json['volumeUnit'] as String? ?? 'ml',
    ingredients: (json['ingredients'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => BufferIngredient.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
  );
}

class BufferIngredient {
  const BufferIngredient({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    this.scalable = true,
  });

  final String id;
  final String name;
  final double amount;
  final String unit;
  final bool scalable;

  BufferIngredient copyWith({
    String? name,
    double? amount,
    String? unit,
    bool? scalable,
  }) => BufferIngredient(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    scalable: scalable ?? this.scalable,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'unit': unit,
    'scalable': scalable,
  };

  factory BufferIngredient.fromJson(
    Map<String, dynamic> json,
  ) => BufferIngredient(
    id: json['id'] as String? ?? 'ing-${DateTime.now().microsecondsSinceEpoch}',
    name: json['name'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    unit: json['unit'] as String? ?? '',
    scalable: json['scalable'] as bool? ?? true,
  );
}

class LabProject {
  const LabProject({
    required this.id,
    required this.name,
    this.description = '',
    required this.colorValue,
    this.createdAtMs = 0,
    this.endsAtMs,
  });

  final String id;
  final String name;
  final String description;
  final int colorValue;
  final int createdAtMs;
  final int? endsAtMs;

  Color get color => Color(colorValue);

  String get createdDateLabel {
    if (createdAtMs <= 0) return '未知';
    final date = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    return '${date.year}/${date.month}/${date.day}';
  }

  String? get endDateLabel {
    final value = endsAtMs;
    if (value == null || value <= 0) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}/${date.month}/${date.day} $hour:$minute';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'colorValue': colorValue,
    'createdAtMs': createdAtMs,
    'endsAtMs': endsAtMs,
  };

  factory LabProject.fromJson(Map<String, dynamic> json) => LabProject(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    colorValue: json['colorValue'] as int? ?? 0xFF007AFF,
    createdAtMs: json['createdAtMs'] as int? ?? 0,
    endsAtMs: json['endsAtMs'] as int?,
  );
}

class LabInventoryItem {
  const LabInventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.threshold,
    required this.storage,
    this.supplier = '',
    this.lotNumber = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final double threshold;
  final String storage;
  final String supplier;
  final String lotNumber;
  final String notes;

  bool get lowStock => quantity <= threshold;

  LabInventoryItem copyWith({
    String? name,
    String? category,
    double? quantity,
    String? unit,
    double? threshold,
    String? storage,
    String? supplier,
    String? lotNumber,
    String? notes,
  }) => LabInventoryItem(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    threshold: threshold ?? this.threshold,
    storage: storage ?? this.storage,
    supplier: supplier ?? this.supplier,
    lotNumber: lotNumber ?? this.lotNumber,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'threshold': threshold,
    'storage': storage,
    'supplier': supplier,
    'lotNumber': lotNumber,
    'notes': notes,
  };

  factory LabInventoryItem.fromJson(Map<String, dynamic> json) =>
      LabInventoryItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
        storage: json['storage'] as String? ?? '',
        supplier: json['supplier'] as String? ?? '',
        lotNumber: json['lotNumber'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.delta,
    required this.unit,
    required this.note,
    required this.createdAtMs,
  });

  final String id;
  final String itemId;
  final String itemName;
  final double delta;
  final String unit;
  final String note;
  final int createdAtMs;

  String get deltaLabel {
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(delta.truncateToDouble() == delta ? 0 : 1)} $unit';
  }

  String get dateLabel {
    final date = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static InventoryTransaction create({
    required LabInventoryItem item,
    required double delta,
    required String note,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return InventoryTransaction(
      id: 'tx-$now-${item.id}',
      itemId: item.id,
      itemName: item.name,
      delta: delta,
      unit: item.unit,
      note: note,
      createdAtMs: now,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'itemName': itemName,
    'delta': delta,
    'unit': unit,
    'note': note,
    'createdAtMs': createdAtMs,
  };

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) =>
      InventoryTransaction(
        id: json['id'] as String? ?? '',
        itemId: json['itemId'] as String? ?? '',
        itemName: json['itemName'] as String? ?? '',
        delta: (json['delta'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
        note: json['note'] as String? ?? '',
        createdAtMs: json['createdAtMs'] as int? ?? 0,
      );
}

class LabTimer {
  const LabTimer({
    required this.id,
    required this.runId,
    required this.runTitle,
    required this.stepTitle,
    required this.endsAtMs,
    this.pausedRemainingSeconds,
  });

  final String id;
  final String runId;
  final String runTitle;
  final String stepTitle;
  final int endsAtMs;
  final int? pausedRemainingSeconds;

  bool get isPaused => pausedRemainingSeconds != null;

  int get remainingSeconds {
    if (pausedRemainingSeconds != null) return pausedRemainingSeconds!;
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      endsAtMs,
    ).difference(DateTime.now()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  String get remainingLabel {
    final seconds = remainingSeconds;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'runId': runId,
    'runTitle': runTitle,
    'stepTitle': stepTitle,
    'endsAtMs': endsAtMs,
    'pausedRemainingSeconds': pausedRemainingSeconds,
  };

  LabTimer copyWith({
    String? runTitle,
    String? stepTitle,
    int? endsAtMs,
    int? pausedRemainingSeconds,
    bool clearPausedRemainingSeconds = false,
  }) => LabTimer(
    id: id,
    runId: runId,
    runTitle: runTitle ?? this.runTitle,
    stepTitle: stepTitle ?? this.stepTitle,
    endsAtMs: endsAtMs ?? this.endsAtMs,
    pausedRemainingSeconds: clearPausedRemainingSeconds
        ? null
        : pausedRemainingSeconds ?? this.pausedRemainingSeconds,
  );

  factory LabTimer.fromJson(Map<String, dynamic> json) => LabTimer(
    id: json['id'] as String? ?? '',
    runId: json['runId'] as String? ?? '',
    runTitle: json['runTitle'] as String? ?? '',
    stepTitle: json['stepTitle'] as String? ?? '',
    endsAtMs: json['endsAtMs'] as int? ?? 0,
    pausedRemainingSeconds: json['pausedRemainingSeconds'] as int?,
  );
}

class CalcHistoryItem {
  const CalcHistoryItem({
    required this.id,
    required this.title,
    required this.result,
    this.mode,
    this.inputs = const {},
  });

  final String id;
  final String title;
  final String result;
  final String? mode;
  final Map<String, double> inputs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'result': result,
    if (mode != null) 'mode': mode,
    if (inputs.isNotEmpty) 'inputs': inputs,
  };

  factory CalcHistoryItem.fromJson(Map<String, dynamic> json) =>
      CalcHistoryItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        result: json['result'] as String? ?? '',
        mode: json['mode'] as String?,
        inputs: _doubleMapFromJson(json['inputs']),
      );
}

Map<String, double> _doubleMapFromJson(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.key is String)
        entry.key as String: entry.value is num
            ? (entry.value as num).toDouble()
            : 0,
  };
}

class SavedFormula {
  const SavedFormula({
    required this.id,
    required this.label,
    required this.formula,
    required this.resultUnit,
    required this.variables,
    this.steps = const [],
    this.resultFields = const [],
    this.referenceRows = const [],
  });

  final String id;
  final String label;
  final String formula;
  final String resultUnit;
  final List<FormulaVariable> variables;
  final List<CustomCalculationStep> steps;
  final List<CustomResultField> resultFields;
  final List<CustomReferenceRow> referenceRows;

  List<CustomCalculationStep> get workflowSteps => steps.isEmpty
      ? [
          CustomCalculationStep(
            outputName: 'result',
            formula: formula,
            outputUnit: resultUnit,
          ),
        ]
      : steps;

  List<CustomResultField> get workflowResultFields => resultFields.isEmpty
      ? [
          CustomResultField(
            variableName: 'result',
            label: label,
            displayUnit: resultUnit,
          ),
        ]
      : resultFields;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'formula': formula,
    'resultUnit': resultUnit,
    'variables': variables.map((item) => item.toJson()).toList(),
    'steps': steps.map((item) => item.toJson()).toList(),
    'resultFields': resultFields.map((item) => item.toJson()).toList(),
    'referenceRows': referenceRows.map((item) => item.toJson()).toList(),
  };

  factory SavedFormula.fromJson(Map<String, dynamic> json) => SavedFormula(
    id: json['id'] as String? ?? '',
    label: json['label'] as String? ?? '',
    formula: json['formula'] as String? ?? '',
    resultUnit: json['resultUnit'] as String? ?? '',
    variables: (json['variables'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => FormulaVariable.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    steps: (json['steps'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) =>
              CustomCalculationStep.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    resultFields: (json['resultFields'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => CustomResultField.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    referenceRows: (json['referenceRows'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) =>
              CustomReferenceRow.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
  );
}

class CustomCalculationStep {
  const CustomCalculationStep({
    required this.outputName,
    required this.formula,
    required this.outputUnit,
  });

  final String outputName;
  final String formula;
  final String outputUnit;

  Map<String, dynamic> toJson() => {
    'outputName': outputName,
    'formula': formula,
    'outputUnit': outputUnit,
  };

  factory CustomCalculationStep.fromJson(Map<String, dynamic> json) =>
      CustomCalculationStep(
        outputName: json['outputName'] as String? ?? '',
        formula: json['formula'] as String? ?? '',
        outputUnit: json['outputUnit'] as String? ?? '',
      );
}

class CustomResultField {
  const CustomResultField({
    required this.variableName,
    required this.label,
    required this.displayUnit,
  });

  final String variableName;
  final String label;
  final String displayUnit;

  Map<String, dynamic> toJson() => {
    'variableName': variableName,
    'label': label,
    'displayUnit': displayUnit,
  };

  factory CustomResultField.fromJson(Map<String, dynamic> json) =>
      CustomResultField(
        variableName: json['variableName'] as String? ?? '',
        label: json['label'] as String? ?? '',
        displayUnit: json['displayUnit'] as String? ?? '',
      );
}

class CustomReferenceRow {
  const CustomReferenceRow({
    required this.name,
    required this.condition,
    required this.value,
    required this.note,
  });

  final String name;
  final String condition;
  final String value;
  final String note;

  Map<String, dynamic> toJson() => {
    'name': name,
    'condition': condition,
    'value': value,
    'note': note,
  };

  factory CustomReferenceRow.fromJson(Map<String, dynamic> json) =>
      CustomReferenceRow(
        name: json['name'] as String? ?? '',
        condition: json['condition'] as String? ?? '',
        value: json['value'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
}

class FormulaVariable {
  const FormulaVariable({
    required this.name,
    required this.value,
    required this.unit,
  });

  final String name;
  final double value;
  final String unit;

  Map<String, dynamic> toJson() => {'name': name, 'value': value, 'unit': unit};

  factory FormulaVariable.fromJson(Map<String, dynamic> json) =>
      FormulaVariable(
        name: json['name'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
      );
}

enum _FormulaUnitFamily {
  volume,
  mass,
  molarConcentration,
  massConcentration,
  molecularWeight,
}

class _FormulaUnitSpec {
  const _FormulaUnitSpec(this.family, this.factorToBase);

  final _FormulaUnitFamily family;
  final double factorToBase;
}

const _formulaUnitSpecs = <String, _FormulaUnitSpec>{
  'μl': _FormulaUnitSpec(_FormulaUnitFamily.volume, 1),
  'ul': _FormulaUnitSpec(_FormulaUnitFamily.volume, 1),
  'ml': _FormulaUnitSpec(_FormulaUnitFamily.volume, 1000),
  'L': _FormulaUnitSpec(_FormulaUnitFamily.volume, 1000000),
  'l': _FormulaUnitSpec(_FormulaUnitFamily.volume, 1000000),
  'ng': _FormulaUnitSpec(_FormulaUnitFamily.mass, 0.001),
  'μg': _FormulaUnitSpec(_FormulaUnitFamily.mass, 1),
  'ug': _FormulaUnitSpec(_FormulaUnitFamily.mass, 1),
  'mg': _FormulaUnitSpec(_FormulaUnitFamily.mass, 1000),
  'g': _FormulaUnitSpec(_FormulaUnitFamily.mass, 1000000),
  'M': _FormulaUnitSpec(_FormulaUnitFamily.molarConcentration, 1),
  'mM': _FormulaUnitSpec(_FormulaUnitFamily.molarConcentration, 0.001),
  'μM': _FormulaUnitSpec(_FormulaUnitFamily.molarConcentration, 0.000001),
  'uM': _FormulaUnitSpec(_FormulaUnitFamily.molarConcentration, 0.000001),
  'nM': _FormulaUnitSpec(_FormulaUnitFamily.molarConcentration, 0.000000001),
  'ng/μl': _FormulaUnitSpec(_FormulaUnitFamily.massConcentration, 0.001),
  'ng/ul': _FormulaUnitSpec(_FormulaUnitFamily.massConcentration, 0.001),
  'μg/μl': _FormulaUnitSpec(_FormulaUnitFamily.massConcentration, 1),
  'ug/ul': _FormulaUnitSpec(_FormulaUnitFamily.massConcentration, 1),
  'μg/ml': _FormulaUnitSpec(_FormulaUnitFamily.massConcentration, 0.001),
  'ug/ml': _FormulaUnitSpec(_FormulaUnitFamily.massConcentration, 0.001),
  'mg/ml': _FormulaUnitSpec(_FormulaUnitFamily.massConcentration, 1),
  'g/mol': _FormulaUnitSpec(_FormulaUnitFamily.molecularWeight, 1),
  'Da': _FormulaUnitSpec(_FormulaUnitFamily.molecularWeight, 1),
  'kDa': _FormulaUnitSpec(_FormulaUnitFamily.molecularWeight, 1000),
};

class _FormulaWorkflowEvaluation {
  const _FormulaWorkflowEvaluation(this.lines);

  final List<_FormulaResultLine> lines;
}

double _normalizeFormulaUnitValue(double value, String unit) {
  final normalized = unit.trim();
  if (normalized.isEmpty) return value;
  if (normalized == '%') return value / 100;
  final spec = _formulaUnitSpecs[normalized];
  return spec == null ? value : value * spec.factorToBase;
}

String _normalizedFormulaUnit(String unit) {
  final normalized = unit.trim();
  if (normalized.isEmpty || normalized == '%') return '';
  final spec = _formulaUnitSpecs[normalized];
  if (spec == null) return normalized;
  return switch (spec.family) {
    _FormulaUnitFamily.volume => 'μl',
    _FormulaUnitFamily.mass => 'μg',
    _FormulaUnitFamily.molarConcentration => 'M',
    _FormulaUnitFamily.massConcentration => 'μg/μl',
    _FormulaUnitFamily.molecularWeight => 'g/mol',
  };
}

double? _convertFormulaUnitValue(
  double value,
  String sourceUnit,
  String targetUnit,
) {
  final source = sourceUnit.trim();
  final target = targetUnit.trim();
  if (target.isEmpty || source == target) return value;
  if (source.isEmpty && target == '%') return value * 100;
  final sourceSpec = _formulaUnitSpecs[source];
  final targetSpec = _formulaUnitSpecs[target];
  if (sourceSpec == null || targetSpec == null) return null;
  if (sourceSpec.family != targetSpec.family) return null;
  return value / targetSpec.factorToBase;
}

_FormulaWorkflowEvaluation? _evaluateCustomFormulaWorkflow({
  required List<FormulaVariable> variables,
  required List<CustomCalculationStep> steps,
  required List<CustomResultField> resultFields,
  List<String>? variableValueOverrides,
}) {
  try {
    final values = <String, double>{};
    final units = <String, String>{};
    for (var i = 0; i < variables.length; i++) {
      final variable = variables[i];
      final name = _safeFormulaName(variable.name);
      if (name.isEmpty) continue;
      final rawText = variableValueOverrides == null
          ? _formatNumber(variable.value)
          : variableValueOverrides[i];
      final rawValue = double.tryParse(rawText.trim());
      if (rawValue == null) return null;
      values[name] = _normalizeFormulaUnitValue(rawValue, variable.unit);
      units[name] = _normalizedFormulaUnit(variable.unit);
    }

    for (final step in steps) {
      final outputName = _safeFormulaName(step.outputName);
      if (outputName.isEmpty || step.formula.trim().isEmpty) continue;
      final rawValue = FormulaParser(step.formula, values).parse();
      values[outputName] = _normalizeFormulaUnitValue(
        rawValue,
        step.outputUnit,
      );
      units[outputName] = _normalizedFormulaUnit(step.outputUnit);
    }

    final lines = <_FormulaResultLine>[];
    for (final field in resultFields) {
      final variableName = _safeFormulaName(field.variableName);
      final value = values[variableName];
      if (value == null) continue;
      final sourceUnit = units[variableName] ?? '';
      final displayUnit = field.displayUnit.trim().isEmpty
          ? sourceUnit
          : field.displayUnit.trim();
      final converted = _convertFormulaUnitValue(
        value,
        sourceUnit,
        displayUnit,
      );
      if (converted == null) return null;
      lines.add(
        _FormulaResultLine(
          label: field.label.trim().isEmpty ? variableName : field.label.trim(),
          value: converted,
          unit: displayUnit,
        ),
      );
    }
    return lines.isEmpty ? null : _FormulaWorkflowEvaluation(lines);
  } on FormatException {
    return null;
  }
}

Map<String, double> _currentFormulaInputs(
  List<FormulaVariable> variables,
  List<String> rawValues,
) {
  final inputs = <String, double>{};
  for (var i = 0; i < variables.length; i++) {
    final name = _safeFormulaName(variables[i].name);
    if (name.isEmpty) continue;
    final rawText = i < rawValues.length
        ? rawValues[i]
        : _formatNumber(variables[i].value);
    final value = double.tryParse(rawText.trim());
    if (value != null) inputs[name] = value;
  }
  return inputs;
}

class FormulaParser {
  FormulaParser(this.source, this.variables);

  final String source;
  final Map<String, double> variables;
  int index = 0;

  double parse() {
    final value = _parseExpression();
    _skipSpaces();
    if (index != source.length) {
      throw const FormatException('公式包含无法识别的字符');
    }
    return value;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      _skipSpaces();
      if (_match('+')) {
        value += _parseTerm();
      } else if (_match('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (true) {
      _skipSpaces();
      if (_match('*')) {
        value *= _parseFactor();
      } else if (_match('/')) {
        final divisor = _parseFactor();
        if (divisor == 0) throw const FormatException('公式出现除以 0');
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _parseFactor() {
    _skipSpaces();
    if (_match('+')) return _parseFactor();
    if (_match('-')) return -_parseFactor();
    if (_match('(')) {
      final value = _parseExpression();
      if (!_match(')')) throw const FormatException('公式括号不完整');
      return value;
    }
    if (_isAtEnd) throw const FormatException('公式不完整');
    final code = source.codeUnitAt(index);
    if (_isDigit(code) || source[index] == '.') return _parseNumber();
    if (_isNameStart(code)) return _parseVariable();
    throw const FormatException('公式包含无法识别的字符');
  }

  double _parseNumber() {
    final start = index;
    while (!_isAtEnd) {
      final char = source[index];
      if (!_isDigit(source.codeUnitAt(index)) && char != '.') break;
      index++;
    }
    final number = double.tryParse(source.substring(start, index));
    if (number == null) throw const FormatException('数字格式不正确');
    return number;
  }

  double _parseVariable() {
    final start = index;
    while (!_isAtEnd && _isNamePart(source.codeUnitAt(index))) {
      index++;
    }
    final name = source.substring(start, index);
    final value = variables[name];
    if (value == null) throw FormatException('未知变量：$name');
    return value;
  }

  bool _match(String token) {
    _skipSpaces();
    if (_isAtEnd || source[index] != token) return false;
    index++;
    return true;
  }

  void _skipSpaces() {
    while (!_isAtEnd && source.codeUnitAt(index) <= 32) {
      index++;
    }
  }

  bool get _isAtEnd => index >= source.length;

  bool _isDigit(int code) => code >= 48 && code <= 57;

  bool _isNameStart(int code) =>
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      code == 95 ||
      code > 127;

  bool _isNamePart(int code) => _isNameStart(code) || _isDigit(code);
}

class ProtocolTextExtractor {
  static LabProtocol extract({
    required String text,
    required String sourceTitle,
    required String sourceType,
    required String area,
  }) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final title = _inferTitle(lines, sourceType);
    final steps = _inferSteps(lines);
    final ingredients = _inferIngredients(lines);
    final duration = _inferDuration(steps);
    return LabProtocol(
      id: 'extracted-${DateTime.now().microsecondsSinceEpoch}',
      name: title,
      area: area,
      baseVolumeLabel: 'extracted draft',
      baseScaleValue: 1,
      scaleUnit: 'draft',
      expectedDuration: duration,
      ingredients: ingredients,
      steps: steps.isEmpty
          ? [
              LabStep(
                id: 'extracted-review',
                title: 'Review extracted text',
                detail: lines.take(3).join(' '),
                durationMinutes: null,
                carryOver: false,
                reagents: const [],
              ),
            ]
          : steps,
      sourceType: _normalizeProtocolSourceType(sourceType),
      sourceTitle: sourceTitle.trim().isEmpty
          ? 'Untitled source'
          : sourceTitle.trim(),
      confidence: _confidence(lines, steps, ingredients),
    );
  }

  static String _inferTitle(List<String> lines, String sourceType) {
    if (lines.isEmpty) return '$sourceType Protocol 草稿';
    final first = _cleanPrefix(lines.first);
    if (first.length <= 72 && !_looksLikeStep(first)) return first;
    return '$sourceType Protocol 草稿';
  }

  static List<LabStep> _inferSteps(List<String> lines) {
    final stepLines = lines.where(_looksLikeStep).toList();
    final source = stepLines.isEmpty
        ? lines.where((line) => line.length > 18).take(8).toList()
        : stepLines;
    return [
      for (var i = 0; i < source.length; i++)
        LabStep(
          id: 'extracted-step-$i',
          title: _stepTitle(_cleanPrefix(source[i]), i),
          detail: _cleanPrefix(source[i]),
          durationMinutes: _inferMinutes(source[i]),
          carryOver: false,
          reagents: _inferStepReagents(source[i]),
        ),
    ];
  }

  static List<ProtocolIngredient> _inferIngredients(List<String> lines) {
    final ingredients = <ProtocolIngredient>[];
    final pattern = RegExp(
      r'([A-Za-z0-9α-ωΑ-Ω\u4e00-\u9fa5 /%+\-]+?)\s*[:：]?\s+(\d+(?:\.\d+)?)\s*(μl|ul|ml|mL|L|mg|g|μg|ug|ng|mM|μM|uM|%)\b',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      final name = (match.group(1) ?? '').trim();
      final amount = double.tryParse(match.group(2) ?? '') ?? 0;
      final unit = _normalizeUnit(match.group(3) ?? '');
      if (name.isEmpty || amount <= 0) continue;
      ingredients.add(
        ProtocolIngredient(name: name, amount: amount, unit: unit),
      );
    }
    final seen = <String>{};
    return ingredients
        .where((item) {
          final key = '${item.name}-${item.amount}-${item.unit}';
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        })
        .take(12)
        .toList();
  }

  static List<StepReagent> _inferStepReagents(String line) =>
      _inferIngredients([line])
          .take(3)
          .map(
            (item) => StepReagent(
              name: item.name,
              amount: _formatNumber(item.amount),
              unit: item.unit,
            ),
          )
          .toList();

  static int? _inferMinutes(String line) {
    final match = RegExp(
      r'(\d+)\s*(min|mins|minute|minutes|分钟)',
      caseSensitive: false,
    ).firstMatch(line);
    return int.tryParse(match?.group(1) ?? '');
  }

  static String _inferDuration(List<LabStep> steps) {
    final total = steps
        .map((step) => step.durationMinutes ?? 0)
        .fold<int>(0, (sum, value) => sum + value);
    return total > 0 ? '$total min' : '待确认';
  }

  static double _confidence(
    List<String> lines,
    List<LabStep> steps,
    List<ProtocolIngredient> ingredients,
  ) {
    var score = 0.45;
    if (lines.length >= 4) score += 0.15;
    if (steps.length >= 3) score += 0.2;
    if (ingredients.isNotEmpty) score += 0.12;
    return score.clamp(0.35, 0.92);
  }

  static bool _looksLikeStep(String line) {
    final trimmed = line.trim();
    return RegExp(
          r'^(\d+[\.)、]|step\s*\d+|步骤\s*\d+)',
          caseSensitive: false,
        ).hasMatch(trimmed) ||
        RegExp(
          r'\b(add|wash|spin|centrifuge|incubate|mix|transfer|remove|observe|加入|洗|离心|孵育|混匀|转移|观察)\b',
          caseSensitive: false,
        ).hasMatch(trimmed);
  }

  static String _cleanPrefix(String line) => line
      .replaceFirst(
        RegExp(
          r'^(\d+[\.)、]\s*|step\s*\d+[:：.\s]*|步骤\s*\d+[:：.\s]*)',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  static String _stepTitle(String line, int index) {
    if (line.isEmpty) return 'Step ${index + 1}';
    final sentence = line.split(RegExp(r'[。.;；]')).first.trim();
    return sentence.length > 34 ? '${sentence.substring(0, 34)}...' : sentence;
  }

  static String _normalizeUnit(String unit) {
    switch (unit) {
      case 'ul':
      case 'uL':
        return 'μl';
      case 'ug':
        return 'μg';
      case 'uM':
        return 'μM';
      default:
        return unit;
    }
  }
}

const sampleProtocols = [
  LabProtocol(
    id: 'cell-passage-protocol',
    name: '细胞传代',
    area: '细胞实验',
    baseVolumeLabel: '10 ml（培养皿）',
    baseScaleValue: 1,
    scaleUnit: 'flask',
    expectedDuration: '15 min',
    sourceTitle: '细胞培养室常规 SOP',
    ingredients: [
      ProtocolIngredient(name: 'DMEM 基础培养基', amount: 180, unit: 'ml'),
      ProtocolIngredient(name: 'FBS (10%)', amount: 20, unit: 'ml'),
      ProtocolIngredient(name: '双抗 (1%)', amount: 0.2, unit: 'ml'),
      ProtocolIngredient(name: '10× PBS', amount: 25, unit: 'ml'),
      ProtocolIngredient(name: 'ddH₂O', amount: 225, unit: 'ml'),
      ProtocolIngredient(name: '0.5M EDTA', amount: 0.4, unit: 'ml'),
      ProtocolIngredient(name: 'Versene 洗涤液', amount: 2, unit: 'ml'),
      ProtocolIngredient(name: '胰酶', amount: 2, unit: 'ml'),
    ],
    variables: [
      ProtocolVariable(
        id: 'passage-v-total',
        symbol: 'V_total',
        name: '总体积',
        baseValue: 200,
        unit: 'ml',
        isScalable: true,
        minValue: 10,
        maxValue: 1000,
      ),
      ProtocolVariable(
        id: 'passage-split-ratio',
        symbol: 'split_ratio',
        name: '传代比例',
        baseValue: 3,
        unit: '倍',
        isScalable: false,
        minValue: 2,
        maxValue: 10,
      ),
      ProtocolVariable(
        id: 'passage-a-dish',
        symbol: 'A_dish',
        name: '培养皿面积',
        baseValue: 78.54,
        unit: 'cm²',
        isScalable: true,
        minValue: 9.6,
        maxValue: 150,
      ),
    ],
    steps: [
      LabStep(
        id: 'passage-prep-medium',
        title: '准备完全培养基',
        detail: '180 mL DMEM + 20 mL FBS + 200 μL 双抗，混匀备用。',
        durationMinutes: null,
        carryOver: false,
        reagents: [
          StepReagent(name: 'DMEM', amount: '180', unit: 'ml'),
          StepReagent(name: 'FBS', amount: '20', unit: 'ml'),
        ],
      ),
      LabStep(
        id: 'passage-observe',
        title: '镜下观察细胞状态',
        detail: '确认密度、生长状态和污染风险，密度约 90% 可传代。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'passage-versene',
        title: 'Versene 洗涤',
        detail: '倒去旧培养液，加入 2 mL Versene，轻晃后吸净。',
        durationMinutes: null,
        carryOver: false,
        reagents: [StepReagent(name: 'Versene', amount: '2', unit: 'ml')],
      ),
      LabStep(
        id: 'passage-trypsin',
        title: '胰酶消化',
        detail: '加入消化液覆盖瓶底，培养箱消化至细胞变圆。',
        durationMinutes: 3,
        carryOver: false,
        reagents: [StepReagent(name: '胰酶', amount: '2', unit: 'ml')],
      ),
      LabStep(
        id: 'passage-stop',
        title: '终止消化 & 收集',
        detail: '加入完全培养基终止消化，吹打悬浮后转入离心管。',
        durationMinutes: null,
        carryOver: false,
        reagents: [StepReagent(name: '完全培养基', amount: '2', unit: 'ml')],
      ),
      LabStep(
        id: 'passage-centrifuge',
        title: '离心',
        detail: '300 rpm，离心 4 分钟。',
        durationMinutes: 4,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'passage-split',
        title: '传代接种',
        detail: '按目标比例重悬，补培养基至目标体积，用 8 字法混匀。',
        durationMinutes: null,
        carryOver: false,
        reagents: [StepReagent(name: '完全培养基', amount: '5', unit: 'ml')],
      ),
      LabStep(
        id: 'passage-label',
        title: '标记培养瓶',
        detail: '标记细胞名、传代比例、日期和操作者。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'passage-medium',
        title: '补足培养基',
        detail: '确认培养基体积覆盖瓶底并无气泡。',
        durationMinutes: null,
        carryOver: false,
        reagents: [StepReagent(name: '完全培养基', amount: '3', unit: 'ml')],
      ),
      LabStep(
        id: 'passage-incubator',
        title: '放回培养箱',
        detail: '37°C、5% CO2 培养箱中平稳放置。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'passage-clean',
        title: '清理台面',
        detail: '废液灭活，擦拭生物安全柜台面。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'passage-log',
        title: '记录传代信息',
        detail: '记录密度、比例、培养基批号和异常情况。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'passage-photo',
        title: '拍照留档',
        detail: '必要时保存镜下状态图用于对照。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'passage-inventory',
        title: '同步库存',
        detail: '扣减 DMEM、FBS、双抗和胰酶用量。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'passage-reminder',
        title: '设置复查提醒',
        detail: '设置明日细胞状态检查提醒。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'passage-review',
        title: '确认 Data Card',
        detail: '检查记录是否完整并保存本地 Data Card。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
    ],
  ),
  LabProtocol(
    id: 'miniprep-protocol',
    name: '转染（Lipo3000）',
    area: '细胞实验',
    baseVolumeLabel: '1 孔（6孔板）',
    baseScaleValue: 6,
    scaleUnit: 'tubes',
    expectedDuration: '24 h',
    sourceTitle: '用户提供 Protocol',
    ingredients: [
      ProtocolIngredient(name: '细胞', amount: 500000, unit: 'cells'),
      ProtocolIngredient(name: '无双抗培养基', amount: 1.75, unit: 'ml'),
      ProtocolIngredient(name: 'Opti-MEM', amount: 250, unit: 'μl'),
      ProtocolIngredient(name: 'Lipofectamine 3000', amount: 5, unit: 'μl'),
      ProtocolIngredient(name: '质粒 DNA', amount: 2.5, unit: 'μg'),
      ProtocolIngredient(name: 'P3000 Reagent', amount: 5, unit: 'μl'),
    ],
    variables: [
      ProtocolVariable(
        id: 'lipo3000-n-cell',
        symbol: 'N_cell',
        name: '每孔细胞数',
        baseValue: 500000,
        unit: 'cells',
        isScalable: true,
        minValue: 100000,
        maxValue: 2000000,
      ),
      ProtocolVariable(
        id: 'lipo3000-dna',
        symbol: 'DNA',
        name: '质粒 DNA',
        baseValue: 2.5,
        unit: 'μg',
        isScalable: true,
        minValue: 0.1,
        maxValue: 10,
      ),
    ],
    steps: [
      LabStep(
        id: 'spin1',
        title: '菌液离心',
        detail: '12000 rpm 收集菌体。',
        durationMinutes: 1,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'lysis',
        title: '裂解反应',
        detail: '加入 P2 后轻柔颠倒混匀，避免剧烈震荡。',
        durationMinutes: 5,
        carryOver: false,
        reagents: [StepReagent(name: 'P2', amount: '250', unit: 'μl')],
      ),
      LabStep(
        id: 'neutralize',
        title: '中和',
        detail: '加入 N3，混匀后离心。',
        durationMinutes: 10,
        carryOver: false,
        reagents: [StepReagent(name: 'N3', amount: '350', unit: 'μl')],
      ),
      LabStep(
        id: 'elute',
        title: '洗脱 DNA',
        detail: 'EB 预热后静置 2 分钟再离心。',
        durationMinutes: 2,
        carryOver: false,
        reagents: [StepReagent(name: 'EB', amount: '50', unit: 'μl')],
      ),
      LabStep(
        id: 'transfection-complex',
        title: '配制转染复合物',
        detail: '按 DNA:Lipo3000 比例混合，室温孵育。',
        durationMinutes: 15,
        carryOver: false,
        reagents: [
          StepReagent(name: 'DNA/Lipo3000 mix', amount: '250', unit: 'μl'),
        ],
      ),
      LabStep(
        id: 'transfection-add',
        title: '滴加复合物',
        detail: '沿孔壁均匀滴加并轻轻摇匀。',
        durationMinutes: null,
        carryOver: false,
        reagents: [],
      ),
    ],
  ),
  LabProtocol(
    id: 'wb-transfer-protocol',
    name: '转染（Lipo2000）',
    area: '细胞实验',
    baseVolumeLabel: '1 孔（12孔板）',
    baseScaleValue: 1,
    scaleUnit: 'well',
    expectedDuration: '24 h',
    sourceTitle: '用户提供 Protocol',
    ingredients: [
      ProtocolIngredient(name: '细胞', amount: 1000000, unit: 'cells'),
      ProtocolIngredient(name: '无双抗培养基', amount: 1.75, unit: 'ml'),
      ProtocolIngredient(name: 'Opti-MEM', amount: 600, unit: 'μl'),
      ProtocolIngredient(name: 'Lipofectamine 2000', amount: 2, unit: 'μl'),
      ProtocolIngredient(name: '质粒 DNA', amount: 1, unit: 'μg'),
    ],
    variables: [
      ProtocolVariable(
        id: 'lipo2000-n-cell',
        symbol: 'N_cell',
        name: '每孔细胞数',
        baseValue: 1000000,
        unit: 'cells',
        isScalable: true,
        minValue: 100000,
        maxValue: 3000000,
      ),
      ProtocolVariable(
        id: 'lipo2000-dna',
        symbol: 'DNA',
        name: '质粒 DNA',
        baseValue: 1,
        unit: 'μg',
        isScalable: true,
        minValue: 0.1,
        maxValue: 5,
      ),
    ],
    steps: [
      LabStep(
        id: 'transfer-check',
        title: '检查转膜',
        detail: '确认 Marker 与膜方向。',
        durationMinutes: null,
        carryOver: true,
        reagents: [],
      ),
      LabStep(
        id: 'transfer-run',
        title: '转膜',
        detail: '按目标蛋白大小设置转膜条件。',
        durationMinutes: 60,
        carryOver: false,
        reagents: [],
      ),
      LabStep(
        id: 'block',
        title: '封闭',
        detail: '5% milk / TBST 封闭。',
        durationMinutes: 60,
        carryOver: true,
        reagents: [StepReagent(name: '5% milk/TBST', amount: '10', unit: 'ml')],
      ),
    ],
  ),
];

const sampleBufferTemplates = [
  BufferTemplate(
    id: 'complete-dmem-template',
    name: 'Complete DMEM',
    area: '细胞实验',
    baseVolume: 200,
    volumeUnit: 'ml',
    ingredients: [
      BufferIngredient(
        id: 'dmem-base',
        name: 'DMEM 基础培养基',
        amount: 180,
        unit: 'ml',
      ),
      BufferIngredient(id: 'fbs-10', name: 'FBS', amount: 20, unit: 'ml'),
      BufferIngredient(id: 'ps-1', name: '双抗', amount: 0.2, unit: 'ml'),
    ],
  ),
  BufferTemplate(
    id: 'pbs-template',
    name: '1x PBS',
    area: '细胞实验',
    baseVolume: 1000,
    volumeUnit: 'ml',
    ingredients: [
      BufferIngredient(id: 'pbs-10x', name: '10x PBS', amount: 100, unit: 'ml'),
      BufferIngredient(id: 'pbs-water', name: 'ddH2O', amount: 900, unit: 'ml'),
    ],
  ),
  BufferTemplate(
    id: 'tbst-template',
    name: '1x TBST',
    area: '蛋白实验',
    baseVolume: 1000,
    volumeUnit: 'ml',
    ingredients: [
      BufferIngredient(
        id: 'tbst-10x',
        name: '10x TBS',
        amount: 100,
        unit: 'ml',
      ),
      BufferIngredient(id: 'tween20', name: 'Tween-20', amount: 1, unit: 'ml'),
      BufferIngredient(
        id: 'tbst-water',
        name: 'ddH2O',
        amount: 899,
        unit: 'ml',
      ),
    ],
  ),
  BufferTemplate(
    id: 'skim-milk-template',
    name: '5% Skim Milk TBST',
    area: '蛋白实验',
    baseVolume: 20,
    volumeUnit: 'ml',
    ingredients: [
      BufferIngredient(id: 'skim-milk', name: '脱脂奶粉', amount: 1, unit: 'g'),
      BufferIngredient(
        id: 'skim-tbst',
        name: '1x TBST',
        amount: 20,
        unit: 'ml',
      ),
    ],
  ),
  BufferTemplate(
    id: 'ripa-template',
    name: 'RIPA Lysis Buffer',
    area: '蛋白实验',
    baseVolume: 10,
    volumeUnit: 'ml',
    ingredients: [
      BufferIngredient(id: 'ripa-stock', name: 'RIPA', amount: 9.9, unit: 'ml'),
      BufferIngredient(id: 'pmsf', name: 'PMSF', amount: 100, unit: 'μl'),
    ],
  ),
];

bool _isSampleBufferTemplateId(String id) {
  return sampleBufferTemplates.any((template) => template.id == id);
}

final sampleRuns = [
  LabRun(
    id: 'cell-passage',
    title: '293T 细胞传代',
    area: '细胞实验',
    timeLabel: '09:00',
    status: '进行中',
    protocolName: '细胞传代',
    scaledVolumeLabel: 'T25 flask / 1:4',
    projectId: 'proj-ace2',
    steps: sampleProtocols[0].steps,
  ),
  LabRun(
    id: 'lipo3000-transfection',
    title: 'Lipo3000 转染 pLVX-GFP',
    area: '细胞实验',
    timeLabel: '11:00',
    status: '待开始',
    protocolName: '转染（Lipo3000）',
    scaledVolumeLabel: '6 孔板 / 1 孔',
    projectId: 'proj-ace2',
    steps: sampleProtocols[1].steps,
  ),
  LabRun(
    id: 'mini-prep',
    title: '质粒小提与测序准备',
    area: '核酸实验',
    timeLabel: '14:30',
    status: '待开始',
    protocolName: '质粒小提',
    scaledVolumeLabel: '6 tubes',
    projectId: 'proj-wb',
    steps: manualSteps,
  ),
  LabRun(
    id: 'western-transfer',
    title: '二抗孵育与显影',
    area: '蛋白实验',
    timeLabel: '17:00',
    status: '顺延占位',
    protocolName: 'WB 显影',
    scaledVolumeLabel: '1 mini gel',
    projectId: 'proj-coop',
    steps: manualSteps,
  ),
];

const manualSteps = [
  LabStep(
    id: 'manual-plan',
    title: '确认实验条件',
    detail: '记录样本、试剂批号、关键条件和风险点。',
    durationMinutes: null,
    carryOver: false,
    reagents: [],
  ),
  LabStep(
    id: 'manual-run',
    title: '执行实验',
    detail: '按本地 SOP 执行并记录异常。',
    durationMinutes: 15,
    carryOver: false,
    reagents: [],
  ),
  LabStep(
    id: 'manual-record',
    title: '记录结果',
    detail: '补充关键 metadata 并生成 Data Card。',
    durationMinutes: null,
    carryOver: false,
    reagents: [],
  ),
  LabStep(
    id: 'manual-photo',
    title: '拍照留档',
    detail: '保存关键图像、胶图或显微镜视野。',
    durationMinutes: null,
    carryOver: false,
    reagents: [],
  ),
  LabStep(
    id: 'manual-share',
    title: '整理汇报',
    detail: '生成可分享结果卡片并归档。',
    durationMinutes: null,
    carryOver: false,
    reagents: [],
  ),
];

class TimePill extends StatelessWidget {
  const TimePill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _labInset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _teal, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class ChipLabel extends StatelessWidget {
  const ChipLabel({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color?.withValues(alpha: 0.14) ?? _labInset;
    final fg = color ?? _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color?.withValues(alpha: 0.16) ?? _line),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: _teal.withValues(alpha: 0.34)),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _teal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(color: _muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
