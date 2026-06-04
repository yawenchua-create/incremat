import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Lightweight, code-based localization for the caregiver app.
///
/// Each string is declared once as a getter that carries both the English and
/// Chinese text via [_t], so there's no separate key/ARB file to keep in sync.
/// Access anywhere with `AppLocalizations.of(context)`; the active language is
/// driven by `MaterialApp.locale` (see `localeProvider`).
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Delegates needed by MaterialApp: ours + the Flutter framework ones so
  /// built-in widgets (date pickers, tooltips, etc.) also localize.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [Locale('en'), Locale('zh')];

  bool get isZh => locale.languageCode == 'zh';
  String _t(String en, String zh) => isZh ? zh : en;

  // ── App-level ──────────────────────────────────────────────────────────────
  String get appTitle => _t('IncreMat Caregiver', 'IncreMat 护理');
  String get languageName => _t('English', '中文');

  // ── Bottom navigation (main shell) ──────────────────────────────────────────
  String get navHome => _t('Home', '主页');
  String get navInsights => _t('Insights', '洞察');
  String get navHardware => _t('Hardware', '设备');
  String get navReports => _t('Reports', '报告');
  String get navSettings => _t('Settings', '设置');

  // ── Common ──────────────────────────────────────────────────────────────────
  String get cancel => _t('Cancel', '取消');
  String get done => _t('Done', '完成');
  String get save => _t('Save', '保存');
  String get tryAgain => _t('Try Again', '重试');
  String get delete => _t('Delete', '删除');
  String repsLabel(int n) => _t('$n reps', '$n 次');

  // ── Auth: login ─────────────────────────────────────────────────────────────
  String get caregiverOverline => _t('C A R E G I V E R', '护 理 端');
  String get welcomeBack => _t('Welcome back.', '欢迎回来。');
  String get signInToAccount => _t('Sign in to your account.', '登录您的账户。');
  String get email => _t('Email', '电子邮箱');
  String get password => _t('Password', '密码');
  String get enterYourEmail => _t('Enter your email', '请输入电子邮箱');
  String get enterValidEmail => _t('Enter a valid email', '请输入有效的电子邮箱');
  String get enterYourPassword => _t('Enter your password', '请输入密码');
  String get forgotPassword => _t('Forgot password?', '忘记密码？');
  String get signIn => _t('Sign In', '登录');
  String get noAccountCreate =>
      _t("Don't have an account? Create one", '还没有账户？立即创建');
  String get enterEmailFirst =>
      _t('Enter your email above first.', '请先在上方输入电子邮箱。');
  String passwordResetSent(String email) =>
      _t('Password reset email sent to $email', '密码重置邮件已发送至 $email');

  // ── Auth: account creation ──────────────────────────────────────────────────
  String get careBeginsWith => _t('Care begins with ', '关爱，始于');
  String get careBeginsYou => _t('you', '你');
  String get createAccountSubtitle => _t(
      'Create your account to support,\nnurture, and make a difference.',
      '创建账户，给予支持、\n呵护，带来改变。');
  String get name => _t('Name', '姓名');
  String get enterYourName => _t('Enter your name', '请输入姓名');
  String get minSixChars => _t('Minimum 6 characters', '至少 6 个字符');
  String get createAccount => _t('Create Account', '创建账户');
  String get infoSafe =>
      _t('Your information is safe with us.', '您的信息将安全保管。');
  String get haveAccountSignIn =>
      _t('Already have an account? Sign in', '已有账户？立即登录');

  // ── Auth: error messages ────────────────────────────────────────────────────
  String get errIncorrectCredentials =>
      _t('Incorrect email or password. Please try again.', '邮箱或密码错误，请重试。');
  String get errEmailInUse =>
      _t('An account with this email already exists.', '该邮箱的账户已存在。');
  String get errWeakPassword =>
      _t('Password must be at least 6 characters.', '密码至少需 6 个字符。');
  String get errInvalidEmail =>
      _t('Please enter a valid email address.', '请输入有效的电子邮箱地址。');
  String get errUserDisabled => _t(
      'This account has been disabled. Please contact support.',
      '该账户已被停用，请联系支持。');
  String get errTooManyRequests => _t(
      'Too many attempts. Please wait a moment and try again.',
      '尝试次数过多，请稍后再试。');
  String get errNoNetwork =>
      _t('No internet connection. Please check your network.', '无网络连接，请检查您的网络。');
  String get errRecentLogin => _t(
      'Please sign in again before making this change.', '请重新登录后再进行此更改。');
  String get errGeneric =>
      _t('Something went wrong. Please try again.', '出了点问题，请重试。');

  // ── Home screen ─────────────────────────────────────────────────────────────
  String get yourLovedOnes => _t('Your Loved Ones', '您的亲人');
  String removePersonQ(String name) => _t('Remove $name?', '移除 $name？');
  String get removeFromCircle => _t(
      'This will remove them from your care circle.', '这会将其从您的关护圈中移除。');
  String get remove => _t('Remove', '移除');
  String get addExistingSenior => _t('Add Existing Senior', '添加现有长者');
  String get noLovedOnes => _t('No loved ones yet', '还没有亲人');
  String get noLovedOnesSubtitle => _t(
      'Add your first loved one to start\ntracking their sit-to-stand progress.',
      '添加您的第一位亲人，\n开始记录他们的起坐进度。');
  String get addALovedOne => _t('Add a Loved One', '添加亲人');
  String couldNotLoadSeniors(String msg) =>
      _t('Could not load seniors: $msg', '无法加载长者：$msg');
  String get noSessionsYet => _t('No sessions yet', '暂无训练记录');
  String get lastSessionToday => _t('Last session: Today', '上次训练：今天');
  String get lastSessionYesterday => _t('Last session: Yesterday', '上次训练：昨天');
  String lastSessionDaysAgo(int d) =>
      _t('Last session: ${d}d ago', '上次训练：$d 天前');
  String get today => _t('Today', '今天');
  String get vsYesterday => _t('vs. yesterday', '较昨天');
  String get avgTime => _t('Avg. Time', '平均时长');
  String secondsShort(String s) => _t('${s}s', '$s秒');
  String get thisWeek => _t('This Week', '本周');
  String daysActiveOfWeek(int a, int b) =>
      _t('$a of $b days', '$b 天中 $a 天');
  String get goalMet => _t('Goal met!', '已达标！');
  String get notStarted => _t('Not started', '未开始');
  String get keepGoing => _t('Keep going!', '继续加油！');

  // ── Add loved one ───────────────────────────────────────────────────────────
  String get seniorName => _t('Senior Name', '长者姓名');
  String get enterAName => _t('Enter a name', '请输入姓名');
  String get age => _t('Age', '年龄');
  String get enterAge => _t('Enter age', '请输入年龄');
  String get enterValidAge => _t('Enter a valid age', '请输入有效年龄');
  String get dailyRepGoal => _t('Daily Rep Goal', '每日目标次数');
  String get enterAGoal => _t('Enter a goal', '请输入目标');
  String get goalBetween =>
      _t('Enter a goal between 5 and 50', '请输入 5 到 50 之间的目标');
  String get incrematPaired => _t('IncreMat Paired', 'IncreMat 已配对');
  String get pairIncreMat => _t('Pair IncreMat', '配对 IncreMat');
  String get connectedSuccessfully => _t('Connected successfully', '连接成功');
  String get connectViaBluetooth =>
      _t('Connect your IncreMat via Bluetooth', '通过蓝牙连接您的 IncreMat');
  String get addToCareCircle => _t('Add to Care Circle', '加入关护圈');
  String failedToSave(String e) => _t('Failed to save: $e', '保存失败：$e');

  // ── Edit senior sheet ───────────────────────────────────────────────────────
  String editSenior(String name) => _t('Edit $name', '编辑 $name');
  String get saveChanges => _t('Save Changes', '保存更改');
  String failedToSaveChanges(String e) =>
      _t('Failed to save changes: $e', '保存更改失败：$e');

  // ── Record session sheet ────────────────────────────────────────────────────
  String get recordSession => _t('Record Session', '记录训练');
  String logSessionFor(String name) =>
      _t('Log a sit-to-stand session for $name', '为 $name 记录一次起坐训练');
  String get numberOfReps => _t('Number of reps', '次数');
  String get enterRepCount => _t('Enter rep count', '请输入次数');
  String get enterValidNumber => _t('Enter a valid number', '请输入有效数字');
  String get avgTimePerRep =>
      _t('Avg. time per rep (seconds)', '每次平均时长（秒）');
  String get enterAverageTime => _t('Enter average time', '请输入平均时长');
  String get enterValidTime => _t('Enter a valid time', '请输入有效时长');
  String get saveSession => _t('Save Session', '保存训练');
  String failedToSaveSession(String e) =>
      _t('Failed to save session: $e', '保存训练失败：$e');

  // ── Connect senior ──────────────────────────────────────────────────────────
  String get connectToSenior => _t('Connect to a Senior', '关联长者');
  String get connectSeniorSubtitle => _t(
      "Enter the Play code for the person you'd like to monitor.",
      '输入您想关注的长者的 Play 代码。');
  String get connectCodeHint => _t('e.g. WORD-1234', '例如 WORD-1234');
  String get connect => _t('Connect', '关联');
  String get notSignedIn => _t('Not signed in', '尚未登录');
  String get codeNotFound => _t(
      "That code wasn't found. Please check with the primary caregiver.",
      '未找到该代码，请与主护理人确认。');
  String get alreadyMonitoring =>
      _t("You're already monitoring this person.", '您已经在关注此人。');

  // ── Senior added ────────────────────────────────────────────────────────────
  String seniorAddedToCircle(String name) => _t(
      '$name has been added\nto your Care Circle.', '$name 已加入\n您的关护圈。');
  String get theirPlayCode => _t('Their Play Code is:', '他们的 Play 代码是：');
  String get codeCopied => _t('Code copied to clipboard', '代码已复制到剪贴板');
  String shareCodeWith(String name) => _t(
      'Share this with $name to\nlog into IncreMat Play.',
      '将此代码分享给 $name，\n以登录 IncreMat Play。');
  String get enrolNfcCard => _t('Enrol NFC Card', '登记 NFC 卡片');

  // ── NFC enrol sheet ─────────────────────────────────────────────────────────
  String get nfcReadyToEnrol => _t('Ready to Enrol', '准备登记');
  String get nfcTapCardToPhone => _t('Tap Card to Phone', '将卡片贴近手机');
  String get nfcCardEnrolled => _t('Card Enrolled!', '卡片已登记！');
  String get nfcEnrolFailed => _t('Enrolment Failed', '登记失败');
  String get nfcNotAvailableTitle => _t('NFC Not Available', 'NFC 不可用');
  String get nfcWaitingSubtitle => _t(
      'Hold any NFC card — EZ-Link, access fob, etc. — to the back of the phone.',
      '将任意 NFC 卡片（EZ-Link、门禁卡等）贴近手机背面。');
  String nfcScanningSubtitle(String name) => _t(
      "Hold $name's card flat against the back of the phone.",
      '将 $name 的卡片平贴在手机背面。');
  String nfcSuccessSubtitle(String name, String uid) => _t(
      "$name's card has been enrolled. They can now tap it on the mat to log in automatically.\n\nUID: $uid",
      '$name 的卡片已登记。现在可在坐垫上轻触即可自动登录。\n\nUID: $uid');
  String get nfcUnavailableSubtitle => _t(
      'This device does not have NFC or it is turned off. Enable NFC in Settings and try again.',
      '此设备没有 NFC 或已关闭。请在设置中启用 NFC 后重试。');
  String get nfcSaveFailed =>
      _t('Failed to save card. Please try again.', '保存卡片失败，请重试。');

  // ── Session music ───────────────────────────────────────────────────────────
  String get sessionMusic => _t('Session Music', '训练音乐');
  String musicNowLoaded(String song) => _t(
      "Now loaded: $song — layers up live as your loved one exercises, driven by the mat's rep count.",
      '当前加载：$song — 随着亲人锻炼，根据坐垫的次数实时叠加音乐层。');
  String get musicSessionCompleteLabel => _t('Session Complete', '训练完成');
  String get musicWaitingFirstRep => _t('Waiting for First Rep', '等待第一次');
  String get musicNowPlaying => _t('Now Playing', '正在播放');
  String get musicPaused => _t('Paused', '已暂停');
  String get musicSessionComplete => _t('Session complete', '训练完成');
  String get musicReadyWhenStarts =>
      _t('Ready when the session starts', '训练开始时即就绪');
  String musicLayerTitle(int layer, String name) =>
      _t('Layer $layer · $name', '第 $layer 层 · $name');
  String get musicStemsMissing => _t(
      'Stem files not found — add them under assets/audio/stems/',
      '未找到音轨文件 — 请添加至 assets/audio/stems/');
  String musicSessionEnded(int reps) =>
      _t('Session ended · $reps reps', '训练结束 · $reps 次');
  String get musicBeginsAutomatically => _t(
      'Music begins automatically on the first rep detected',
      '检测到第一次时音乐将自动开始');
  String musicStemsPlaying(int layer, int total, int reps) => _t(
      '$layer of $total stems playing · $reps reps',
      '$total 个音轨中播放 $layer 个 · $reps 次');
  String get musicReps => _t('Reps', '次数');
  String get musicLayers => _t('Layers', '层');
  String get musicNextLayer => _t('Next Layer', '下一层');
  String musicRepN(int n) => _t('rep $n', '第 $n 次');
  String get musicFull => _t('full', '已满');
  String get musicDash => '—';
  String get musicEndSession => _t('End session', '结束训练');
  String get musicRestart => _t('Restart from chunk 1', '从头重新开始');
  String get musicSessionLayers => _t('Session Layers', '训练音乐层');
  String musicLayersCount(int n) => _t('$n layers', '$n 层');
  String musicLayerActive(int n) => _t('Layer $n active', '第 $n 层进行中');
  String get musicPlaying => _t('Playing', '播放中');
  String get musicUnlocked => _t('Unlocked', '已解锁');
  String layerName(int i) => isZh
      ? const ['鼓点', '贝斯', '吉他', '旋律', '人声'][i]
      : const ['Drums', 'Bass', 'Guitar', 'Melody', 'Vocals'][i];
  String layerHint(int i) => isZh
      ? const ['节奏基础', '贝斯律动加入', '吉他加入', '键盘与配器丰富', '人声 · 完整歌曲'][i]
      : const [
          'Rhythmic foundation',
          'Bass groove joins',
          'Guitar joins in',
          'Keys & extras fill out',
          'Vocals — full song'
        ][i];

  // ── Reports / PDF export ────────────────────────────────────────────────────
  String get exportMobilityReport => _t('Export Mobility Report', '导出活动报告');
  String get previewMobilityReport =>
      _t('Preview your mobility report', '预览您的活动报告');
  String get mobilityExerciseReport =>
      _t('Mobility & Exercise Report', '活动与锻炼报告');
  String reportMeta(String name, String range) =>
      _t('IncreMat Data  •  $name  •  $range', 'IncreMat 数据  •  $name  •  $range');
  String get totalRepsThisMonth => _t('Total Reps this Month', '本月总次数');
  String get totalRepetitions => _t('Total Repetitions', '总重复次数');
  String get dailyConsistency => _t('Daily Consistency', '每日坚持度');
  String get daysWithIncreMat => _t('Days with IncreMat', '使用 IncreMat 的天数');
  String pdfDaysWithIncreMat(int a, int b) => _t(
      'Days with IncreMat  •  $a/$b days', '使用 IncreMat 的天数  •  $b 天中 $a 天');
  String get sitToStandSpeed => _t('Sit-to-Stand Speed', '起坐速度');
  String get avgRepTimeThisMonth =>
      _t('Average rep time this month', '本月平均每次时长');
  String get weeklyRepetitions => _t('Weekly Repetitions', '每周重复次数');
  String get daysWord => _t('days', '天');
  String dayN(int n) => _t('Day $n', '第 $n 天');
  String get selectDateRange => _t('Select Date Range', '选择日期范围');
  String get shareWithDoctor => _t('Share with Doctor', '与医生分享');
  String generatedBy(String date) =>
      _t('Generated by IncreMat Caregiver  •  $date',
          '由 IncreMat 护理端生成  •  $date');

  // ── Insights ────────────────────────────────────────────────────────────────
  String get repStatistics => _t('Rep Statistics', '次数统计');
  String get noDataYet => _t('No data yet', '暂无数据');
  String get insightsEmptySubtitle => _t(
      'Add a loved one on the Home tab to start\ntracking their sit-to-stand progress.',
      '在主页添加一位亲人，\n开始记录他们的起坐进度。');
  String get performanceTrends => _t('Performance Trends', '表现趋势');
  String get dailyRepActivity =>
      _t('Daily rep activity for the current week', '本周每日次数活动');
  String get dailyRepsLegend => _t('Daily Reps', '每日次数');
  String get weeklyConsistency => _t('Weekly Consistency', '每周坚持度');
  String get consistentProgress => _t(
      'Consistent progress. Keep up the great work!', '保持稳定进步，继续加油！');
  String get speed => _t('Speed', '速度');
  String get averageRepTime => _t('Average Rep Time', '平均每次时长');
  String get secUnit => _t('sec', '秒');
  String get perRepetitionMonth => _t('per repetition this month', '本月每次');
  String get repCompletionRate => _t('Rep Completion Rate', '完成率');
  String daysActiveMonth(int a, int b) =>
      _t('$a/$b days active', '$b 天中 $a 天活跃');
  String get insightsCta => _t(
      'Small, consistent efforts\nlead to meaningful progress.',
      '小而持续的努力，\n带来有意义的进步。');

  // ── Senior detail ───────────────────────────────────────────────────────────
  String get monthlySummary => _t('Monthly Summary', '月度总结');
  String get recentSessions => _t('Recent Sessions', '最近训练');
  String get todaysProgress => _t("Today's Progress", '今日进度');
  String get live => _t('Live', '实时');
  String get avgRepTime => _t('Avg. Rep Time', '平均每次时长');
  String get dailyGoal => _t('Daily goal', '每日目标');
  String weekdayShort(int i) => isZh
      ? const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][i]
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i];
  String daysActiveThisWeek(int a, int b) =>
      _t('$a of $b days active', '$b 天中 $a 天活跃');
  String get totalReps => _t('Total Reps', '总次数');
  String get consistency => _t('Consistency', '坚持度');
  String get avgSpeed => _t('Avg Speed', '平均速度');
  String get noSessionsRecorded => _t('No sessions recorded yet', '尚无训练记录');
  String get sessionsWillAppear => _t(
      'Sessions will appear here once the mat syncs.', '坐垫同步后，训练将显示在这里。');
  String playCodeOf(String name) =>
      _t("$name's Play Code: ", '$name 的 Play 代码：');
  String repsSyncing(int reps) =>
      _t('$reps reps  •  syncing…', '$reps 次  •  同步中…');
  String get yesterday => _t('Yesterday', '昨天');
  String daysAgo(int d) => _t('$d days ago', '$d 天前');
  String sessionRepsAvg(int reps, String s) =>
      _t('$reps reps  •  avg ${s}s', '$reps 次  •  平均 $s 秒');

  // ── Hardware screen ─────────────────────────────────────────────────────────
  String get hardwareTitle => _t('Hardware Status', '硬件状态');
  String get hardwareSubtitle => _t(
      'View the connection and performance\nof your IncreMat sensor.',
      '查看您的 IncreMat 传感器的\n连接与性能。');
  String get statusLabel => _t('Status: ', '状态：');
  String get connected => _t('Connected', '已连接');
  String get disconnected => _t('Disconnected', '已断开');
  String get matOnChair => _t('Mat on chair', '坐垫已就位');
  String get matRemoved => _t('Mat removed', '坐垫已移除');
  String get liveSessionLabel => _t('Live session: ', '实时训练：');
  String avgSeconds(String s) => _t('$s' 's avg', '平均 $s 秒');
  String batteryLabel(int pct) => _t('Battery: $pct%', '电量：$pct%');
  String signalLabelText(String level) => _t('Signal: $level', '信号：$level');
  String get signalStrong => _t('Strong', '强');
  String get signalGood => _t('Good', '良好');
  String get signalWeak => _t('Weak', '弱');
  String get connectToIncreMat => _t('Connect to IncreMat', '连接 IncreMat');
  String get disconnect => _t('Disconnect', '断开连接');
  String connectionFailed(String e) => _t('Connection failed: $e', '连接失败：$e');
  String get nfcUnavailable =>
      _t('NFC is not available on this device.', '此设备不支持 NFC。');
  String get cardNotRecognised =>
      _t('Card not recognised. Has it been enrolled?', '无法识别此卡片，是否已登记？');
  String get userNotInCircle =>
      _t("That user isn't in your Care Circle.", '该用户不在您的关护圈中。');
  String nowTracking(String name) => _t('Now tracking: $name', '正在记录：$name');
  String get identifyUser => _t('Identify User', '识别用户');
  String get identifyUserSubtitle => _t(
      "Tap a senior's NFC tag to assign this session.",
      '轻触长者的 NFC 标签以归属此次训练。');
  String get holdTagToPhone => _t('Hold tag to phone…', '将标签靠近手机…');
  String get scanNfcTag => _t('Scan NFC Tag', '扫描 NFC 标签');

  // ── Settings screen ─────────────────────────────────────────────────────────
  String get settingsTitle => _t('Settings', '设置');
  String get exerciseSettings => _t('Exercise Settings', '锻炼设置');
  String get language => _t('Language', '语言');
  String get languageSubtitle =>
      _t('Choose your preferred language.', '选择您的首选语言。');
  String get english => _t('English', 'English');
  String get chinese => _t('中文', '中文');
  String get repsPerDay => _t('reps per day', '每日次数');
  String get couldNotSaveGoal =>
      _t('Could not save goal. Please try again.', '无法保存目标，请重试。');
  String get weeklyRewardDays => _t('Weekly Reward Days', '每周奖励天数');
  String get couldNotSave => _t('Could not save. Please try again.', '无法保存，请重试。');
  String eggRewardExplain(String name, int threshold) => _t(
      '$name earns an egg in IncreMat Play when the daily goal of $threshold ${threshold == 1 ? 'day' : 'days'} a week is met.',
      '当每周有 $threshold 天达成每日目标时，$name 将在 IncreMat Play 中获得一枚蛋。');
  String get selectTrack => _t('Select Track', '选择曲目');
  String get orDivider => _t('OR', '或');
  String get randomizeTracks => _t('Randomize Tracks', '随机播放曲目');
  String get randomizeSubtitle =>
      _t('Play a different mix each session', '每次训练播放不同的混音');
  String get sessionPlayer => _t('Session Player', '训练播放器');
  String get sessionPlayerSubtitle =>
      _t('Live layers & playback controls', '实时音乐层与播放控制');
  String get dailyReminders => _t('Daily Reminders', '每日提醒');
  String get goalReminder => _t('Goal Reminder', '目标提醒');
  String reminderSetFor(String time) =>
      _t('Reminder set for $time daily', '每日 $time 提醒');
  String get notifyIfGoalNotMet =>
      _t("Notify if daily rep goal isn't met", '未达成每日目标时提醒');
  String get reminderTime => _t('Reminder Time', '提醒时间');
  String get amLabel => _t('AM', '上午');
  String get pmLabel => _t('PM', '下午');
  String get account => _t('Account', '账户');
  String get signingOut => _t('Signing out…', '正在退出…');
  String get signOut => _t('Sign Out', '退出登录');
  String get deleteAccount => _t('Delete Account', '删除账户');
  String get deleteAccountQ => _t('Delete Account?', '删除账户？');
  String get deleteAccountWarning => _t(
      'This permanently removes your account and all care data. Enter your password to confirm.',
      '这将永久删除您的账户和所有护理数据。请输入密码确认。');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
