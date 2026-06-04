import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/insights_provider.dart';
import '../../providers/senior_provider.dart';

class ExportReportScreen extends ConsumerStatefulWidget {
  const ExportReportScreen({super.key});

  @override
  ConsumerState<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends ConsumerState<ExportReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
  }
  bool _isGenerating = false;

  String get _dateRangeLabel {
    final fmt = DateFormat('MMM d, yyyy');
    return '${fmt.format(_startDate)} – ${fmt.format(_endDate)}';
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.sageGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _shareReport() async {
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await _buildPdf();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'incremat_mobility_report_${DateFormat('yyyy_MM').format(_startDate)}.pdf',
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final l = AppLocalizations.of(context);
    final senior = ref.read(selectedSeniorProvider);
    final insights = senior != null
        ? ref.read(seniorInsightsProvider(senior.id))
        : null;
    final doc = pw.Document();

    late final pw.Font notoFont;
    late final pw.Font notoFontBold;
    try {
      notoFont = await PdfGoogleFonts.notoSansSCRegular();
      notoFontBold = await PdfGoogleFonts.notoSansSCBold();
    } catch (_) {
      notoFont = pw.Font.helvetica();
      notoFontBold = pw.Font.helveticaBold();
    }

    final sageColor = PdfColor.fromHex('8DA399');
    final espressoColor = PdfColor.fromHex('3E3636');
    final creamColor = PdfColor.fromHex('F7F3F0');

    final totalReps = insights?.totalRepsThisMonth ?? 0;
    final daysActive = insights?.daysActiveThisMonth ?? 0;
    final totalDays = insights?.totalDaysThisMonth ?? 1;
    final avgRepTime = insights?.avgRepTimeSeconds ?? 0.0;
    final weeklyReps = insights?.weeklyReps ?? [];

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: creamColor,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    l.mobilityExerciseReport,
                    style: pw.TextStyle(
                      font: notoFontBold,
                      fontSize: 22,
                      color: espressoColor,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    l.reportMeta(senior?.name ?? '—', _dateRangeLabel),
                    style: pw.TextStyle(font: notoFont, fontSize: 11, color: sageColor),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            _pdfStatRow(
              notoFont: notoFont,
              notoFontBold: notoFontBold,
              label: l.totalRepsThisMonth,
              value: '$totalReps',
              sub: l.totalRepetitions,
              sageColor: sageColor,
              espressoColor: espressoColor,
            ),
            pw.Divider(color: PdfColor.fromHex('E8E3DF')),
            _pdfStatRow(
              notoFont: notoFont,
              notoFontBold: notoFontBold,
              label: l.dailyConsistency,
              value: '${(daysActive / totalDays * 100).round()}%',
              sub: l.pdfDaysWithIncreMat(daysActive, totalDays),
              sageColor: sageColor,
              espressoColor: espressoColor,
            ),
            pw.Divider(color: PdfColor.fromHex('E8E3DF')),
            _pdfStatRow(
              notoFont: notoFont,
              notoFontBold: notoFontBold,
              label: l.sitToStandSpeed,
              value: '${avgRepTime.toStringAsFixed(1)}s',
              sub: l.avgRepTimeThisMonth,
              sageColor: sageColor,
              espressoColor: espressoColor,
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              l.weeklyRepetitions,
              style: pw.TextStyle(font: notoFontBold, fontSize: 14, color: espressoColor),
            ),
            pw.SizedBox(height: 8),
            if (weeklyReps.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('E8E3DF'), width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('D4DDD9')),
                    children: List.generate(weeklyReps.length, (i) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          i < 7 ? l.weekdayShort(i) : l.dayN(i + 1),
                          style: pw.TextStyle(font: notoFontBold, fontSize: 10, color: espressoColor),
                          textAlign: pw.TextAlign.center,
                        ),
                      );
                    }),
                  ),
                  pw.TableRow(
                    children: weeklyReps.map((reps) =>
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '$reps',
                          style: pw.TextStyle(font: notoFont, fontSize: 11, color: espressoColor),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ).toList(),
                  ),
                ],
              ),
            pw.Spacer(),
            pw.Divider(color: PdfColor.fromHex('E8E3DF')),
            pw.SizedBox(height: 6),
            pw.Text(
              l.generatedBy(DateFormat('MMMM d, yyyy').format(DateTime.now())),
              style: pw.TextStyle(font: notoFont, fontSize: 9, color: sageColor),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfStatRow({
    required pw.Font notoFont,
    required pw.Font notoFontBold,
    required String label,
    required String value,
    required String sub,
    required PdfColor sageColor,
    required PdfColor espressoColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: pw.TextStyle(font: notoFontBold, fontSize: 12, color: espressoColor)),
              pw.SizedBox(height: 2),
              pw.Text(sub, style: pw.TextStyle(font: notoFont, fontSize: 9, color: sageColor)),
            ],
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: notoFontBold, fontSize: 20, color: espressoColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final senior = ref.watch(selectedSeniorProvider);
    final insights = senior != null
        ? ref.watch(seniorInsightsProvider(senior.id))
        : null;

    final totalReps = insights?.totalRepsThisMonth ?? 0;
    final daysActive = insights?.daysActiveThisMonth ?? 0;
    final totalDays = insights?.totalDaysThisMonth ?? 1;
    final avgRepTime = insights?.avgRepTimeSeconds ?? 0.0;
    final weeklyReps = insights?.weeklyReps ?? [];

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(l.exportMobilityReport, style: AppTextStyles.titleLarge),
            Text(l.previewMobilityReport, style: AppTextStyles.caption),
          ],
        ),
        centerTitle: true,
        toolbarHeight: 60,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.eco, size: 48, color: AppColors.lightSage),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.espresso.withValues(alpha: 0.07),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.mobilityExerciseReport,
                              style: AppTextStyles.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.reportMeta(senior?.name ?? '—', _dateRangeLabel),
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            const Divider(),
                            _ReportRow(
                              icon: Icons.directions_walk_outlined,
                              label: l.totalRepsThisMonth,
                              value: '$totalReps',
                              sub: l.totalRepetitions,
                            ),
                            const Divider(),
                            _ReportRow(
                              icon: Icons.calendar_today_outlined,
                              label: l.dailyConsistency,
                              value: '${(daysActive / totalDays * 100).round()}%',
                              sub: l.daysWithIncreMat,
                              trailing: _ConsistencyCircle(
                                daysActive: daysActive,
                                totalDays: totalDays,
                              ),
                            ),
                            const Divider(),
                            _ReportRow(
                              icon: Icons.timer_outlined,
                              label: l.sitToStandSpeed,
                              value: '${avgRepTime.toStringAsFixed(1)}s',
                              sub: l.avgRepTimeThisMonth,
                            ),
                            const SizedBox(height: 20),
                            Text(l.weeklyRepetitions, style: AppTextStyles.titleMedium),
                            const SizedBox(height: 12),
                            _WeeklyBarChart(weeklyReps: weeklyReps),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(l.selectDateRange, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _selectDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: AppColors.subtleText),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_dateRangeLabel, style: AppTextStyles.bodyMedium),
                            ),
                            const Icon(Icons.keyboard_arrow_down,
                                size: 20, color: AppColors.subtleText),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _shareReport,
                child: _isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.medical_services_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(l.shareWithDoctor, style: AppTextStyles.buttonText),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Widget? trailing;

  const _ReportRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.lightSage.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.sageGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.titleMedium.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: AppTextStyles.statMedium.copyWith(fontSize: 26),
                      ),
                    ],
                  ),
                ),
                Text(sub, style: AppTextStyles.caption),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ConsistencyCircle extends StatelessWidget {
  final int daysActive;
  final int totalDays;

  const _ConsistencyCircle({required this.daysActive, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    final progress = totalDays > 0 ? daysActive / totalDays : 0.0;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: AppColors.lightSage,
            valueColor: const AlwaysStoppedAnimation(AppColors.sageGreen),
            strokeCap: StrokeCap.round,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$daysActive',
                style: AppTextStyles.titleMedium.copyWith(fontSize: 12),
              ),
              Text(
                AppLocalizations.of(context).daysWord,
                style: AppTextStyles.caption.copyWith(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<int> weeklyReps;
  const _WeeklyBarChart({required this.weeklyReps});

  @override
  Widget build(BuildContext context) {
    if (weeklyReps.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    final groups = weeklyReps.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.toDouble(),
            color: AppColors.sageGreen,
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    final maxReps = weeklyReps.isEmpty ? 10 : weeklyReps.reduce((a, b) => a > b ? a : b);
    final maxY = (maxReps + 5).toDouble().clamp(10.0, double.infinity);

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).ceilToDouble(),
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.divider,
              strokeWidth: 0.8,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (maxY / 4).ceilToDouble(),
                reservedSize: 32,
                getTitlesWidget: (v, _) =>
                    Text(v.toInt().toString(), style: AppTextStyles.caption),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  return Text(
                    i < 7 ? l.weekdayShort(i) : '',
                    style: AppTextStyles.caption,
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: groups,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.espresso,
              getTooltipItem: (group, groupIdx, rod, rodIdx) => BarTooltipItem(
                '${rod.toY.toInt()}',
                AppTextStyles.caption.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
