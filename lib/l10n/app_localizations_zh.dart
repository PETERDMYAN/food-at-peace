// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Food at Peace';

  @override
  String greetMorning(String name) {
    return '早上好，$name';
  }

  @override
  String greetAfternoon(String name) {
    return '下午好，$name';
  }

  @override
  String greetEvening(String name) {
    return '晚上好，$name';
  }

  @override
  String get onboardingWelcomeTitle => '欢迎使用\nFood at Peace';

  @override
  String get onboardingWelcomeBody => '用简洁平静的每日视图记录卡路里与营养。';

  @override
  String get onboardingNameTitle => '怎么称呼你？';

  @override
  String get onboardingNameBody => '用 Apple 登录即可带入你的名字，或直接输入。我们每天都会用名字问候你。';

  @override
  String get onboardingNameLabel => '你的名字';

  @override
  String get onboardingNameManual => '或手动输入';

  @override
  String get onboardingGoalTitle => '你的目标是什么？';

  @override
  String get onboardingGoalBody => '这将设置你的每日卡路里缺口，随时可以更改。';

  @override
  String get onboardingHealthTitle => '连接 Apple 健康';

  @override
  String get onboardingHealthBody =>
      '我们会从 Apple 健康（含 Garmin）读取你的年龄、身高、体重和消耗的卡路里，让目标保持准确——每日刷新。';

  @override
  String get onboardingHealthConnected => '已连接——你的数据将保持同步。';

  @override
  String perDayKcal(String value) {
    return '$value 千卡/天';
  }

  @override
  String get continueLabel => '继续';

  @override
  String get getStarted => '开始使用';

  @override
  String get skip => '跳过';

  @override
  String get back => '返回';

  @override
  String get navToday => '今天';

  @override
  String get navTrends => '趋势';

  @override
  String get navSettings => '设置';

  @override
  String get addFood => '添加食物';

  @override
  String get save => '保存';

  @override
  String get ok => '好';

  @override
  String get remove => '移除';

  @override
  String get cancel => '取消';

  @override
  String get caloriesLeftToday => '今日剩余卡路里';

  @override
  String get overBudget => '超出预算';

  @override
  String budgetEaten(String budget, String eaten) {
    return '预算 $budget · 已摄入 $eaten';
  }

  @override
  String burnViaHealth(String burn, String active) {
    return '消耗 $burn 千卡 · 活动 $active（来自健康）';
  }

  @override
  String estBurn(String burn) {
    return '预计消耗 ~$burn 千卡/天';
  }

  @override
  String goalLine(String goal) {
    return '目标：$goal';
  }

  @override
  String goalLineAdjusted(String goal, String adjustment) {
    return '目标：$goal（$adjustment 千卡/天）';
  }

  @override
  String budgetBreakdown(String resting, String active, String adjustment) {
    return '静息 $resting · 活动 $active · 目标 $adjustment';
  }

  @override
  String budgetBreakdownEst(String burn, String adjustment) {
    return '预计消耗 $burn · 目标 $adjustment';
  }

  @override
  String get protein => '蛋白质';

  @override
  String get saturatedFat => '饱和脂肪';

  @override
  String get calories => '卡路里';

  @override
  String get chartActual => '实际';

  @override
  String get chartTarget => '目标';

  @override
  String daysCount(int count) {
    return '$count天';
  }

  @override
  String onTargetDays(int met, int total) {
    return '$total 天中 $met 天达标';
  }

  @override
  String get editTargets => '编辑目标';

  @override
  String get useAutomatic => '使用自动计算';

  @override
  String get targetReached => '已达目标';

  @override
  String toGo(String amount) {
    return '还差 $amount';
  }

  @override
  String overBy(String amount) {
    return '超出 $amount';
  }

  @override
  String amountLeft(String amount) {
    return '剩余 $amount';
  }

  @override
  String get todaysFood => '今日饮食';

  @override
  String get nothingLogged => '还没有记录。\n点击“添加食物”开始。';

  @override
  String get connectHealthGarmin => '连接 Apple 健康与 Garmin';

  @override
  String get appleHealthConnected => '已连接 Apple 健康';

  @override
  String get healthNotGranted => '未授予健康访问权限';

  @override
  String get profilePrompt => '在设置中完善个人资料，以获得准确的目标。';

  @override
  String get workouts => '锻炼';

  @override
  String get noTrendsYet => '暂无数据。\n记录一些食物即可查看趋势。';

  @override
  String kcalValue(String value) {
    return '$value 千卡';
  }

  @override
  String gramsValue(String value) {
    return '$value 克';
  }

  @override
  String get scanPhoto => '用 Claude 扫描照片';

  @override
  String get foodName => '食物名称';

  @override
  String get foodNameHint => '例如：烤鸡沙拉';

  @override
  String get enterName => '请输入名称';

  @override
  String get meal => '餐次';

  @override
  String get caloriesKcal => '卡路里（千卡）';

  @override
  String get proteinG => '蛋白质（克）';

  @override
  String get saturatedFatG => '饱和脂肪（克）';

  @override
  String get servingOptional => '份量（可选）';

  @override
  String get servingHint => '例如：1 碗、200 克';

  @override
  String get saveEntry => '保存记录';

  @override
  String get required => '必填';

  @override
  String get enterValidNumber => '请输入有效数字';

  @override
  String get takePhoto => '拍照';

  @override
  String get chooseFromLibrary => '从相册选择';

  @override
  String get cameraError => '无法打开相机或相册。';

  @override
  String get analysisFailed => '分析失败，请重试。';

  @override
  String get addApiKeyTitle => '添加 API 密钥';

  @override
  String get addApiKeyBody => '此版本未启用照片分析。可在设置中添加你自己的 Anthropic API 密钥来扫描照片。';

  @override
  String get estimatedByClaude => '由 Claude 估算 — 请在下方查看并修改。';

  @override
  String confidenceLabel(String value) {
    return '置信度：$value';
  }

  @override
  String get analyzingPhoto => '正在分析照片…';

  @override
  String get profile => '个人资料';

  @override
  String get sex => '性别';

  @override
  String get age => '年龄';

  @override
  String get heightCm => '身高（厘米）';

  @override
  String get weightKg => '体重（千克）';

  @override
  String get activityLevel => '活动水平';

  @override
  String get goal => '目标';

  @override
  String get yourTargets => '你的目标';

  @override
  String get restingBurn => '静息消耗（BMR）';

  @override
  String get estDailyBurn => '预计每日消耗';

  @override
  String get dailyCalorieTarget => '每日卡路里目标';

  @override
  String get calorieGapTarget => '卡路里缺口目标';

  @override
  String estBurnDailyTarget(String burn, String target) {
    return '预计消耗 $burn · 每日目标 $target';
  }

  @override
  String get proteinTargetLabel => '蛋白质目标';

  @override
  String get satFatCap => '饱和脂肪上限';

  @override
  String get saveProfile => '保存资料';

  @override
  String get profileSaved => '资料已保存';

  @override
  String get foodPhotoAnalysis => '食物照片分析（Claude）';

  @override
  String get apiKeySavedDevice => '正在本设备使用你自己的 Anthropic 密钥。移除后将恢复使用内置分析。';

  @override
  String get apiKeyPrompt =>
      '照片分析开箱即用。高级：添加你自己的 Anthropic API 密钥即可改用你自己的账户 — 可在 console.anthropic.com 获取。';

  @override
  String get replaceApiKey => '替换 API 密钥';

  @override
  String get apiKeyLabel => 'API 密钥（sk-ant-…）';

  @override
  String get saveKey => '保存密钥';

  @override
  String get apiKeySavedToast => 'API 密钥已保存';

  @override
  String get apiKeyRemoved => 'API 密钥已移除';

  @override
  String get account => '账户';

  @override
  String get signInPrompt => '登录后可在多设备间同步数据。可选 — 不登录也能使用。';

  @override
  String signedInAs(String value) {
    return '已登录：$value';
  }

  @override
  String get signOut => '退出登录';

  @override
  String get signInFailed => '登录失败，请重试。';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncing => '同步中…';

  @override
  String lastSynced(String time) {
    return '上次同步 $time';
  }

  @override
  String get healthGarminTitle => 'Apple 健康与 Garmin';

  @override
  String get healthNotAvailable => '此平台不支持。';

  @override
  String get healthConnectedBody =>
      '已连接。你的预算将使用真实消耗的卡路里（活动 + 静息），体重会自动从体脂秤同步，所记录的食物也会写回 Apple 健康。Garmin 数据通过 Apple 健康接入。';

  @override
  String get healthConnectBody =>
      '连接 Apple 健康即可使用真实消耗的卡路里（含 Garmin）、自动同步体重、查看锻炼，并把记录的食物写回健康。';

  @override
  String get connectAppleHealth => '连接 Apple 健康';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get sexMale => '男';

  @override
  String get sexFemale => '女';

  @override
  String get activitySedentary => '久坐';

  @override
  String get activityLight => '轻度活动';

  @override
  String get activityModerate => '中度活动';

  @override
  String get activityActive => '活跃';

  @override
  String get activityVeryActive => '非常活跃';

  @override
  String get activitySedentaryHint => '几乎不运动';

  @override
  String get activityLightHint => '每周运动 1-3 天';

  @override
  String get activityModerateHint => '每周运动 3-5 天';

  @override
  String get activityActiveHint => '每周运动 6-7 天';

  @override
  String get activityVeryActiveHint => '高强度运动或体力劳动';

  @override
  String get goalLose => '减重';

  @override
  String get goalMaintain => '保持';

  @override
  String get goalGain => '增肌';

  @override
  String get mealBreakfast => '早餐';

  @override
  String get mealLunch => '午餐';

  @override
  String get mealDinner => '晚餐';

  @override
  String get mealSnack => '加餐';

  @override
  String get addWeight => '记录体重';

  @override
  String get logWeight => '记录体重';

  @override
  String get weightSaved => '体重已保存';

  @override
  String get latestWeight => '最新体重';

  @override
  String get enterWeight => '请输入体重';

  @override
  String get weightTitle => '体重';

  @override
  String weightKgValue(String value) {
    return '$value 千克';
  }

  @override
  String get feedback => '反馈';

  @override
  String get feedbackPrompt => '发现问题或有好点子？欢迎告诉我们。';

  @override
  String get feedbackHint => '你的反馈…';

  @override
  String get yourEmailOptional => '你的邮箱（可选）';

  @override
  String get submit => '提交';

  @override
  String get feedbackThanks => '感谢你的反馈！';

  @override
  String get feedbackError => '反馈发送失败，请重试。';

  @override
  String get feedbackEmpty => '请输入反馈内容';
}
