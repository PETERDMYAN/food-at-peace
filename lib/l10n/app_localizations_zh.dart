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
  String get goodMorning => '早上好';

  @override
  String get goodAfternoon => '下午好';

  @override
  String get goodEvening => '晚上好';

  @override
  String get weatherClear => '晴';

  @override
  String get weatherPartlyCloudy => '局部多云';

  @override
  String get weatherCloudy => '多云';

  @override
  String get weatherFog => '雾';

  @override
  String get weatherDrizzle => '小雨';

  @override
  String get weatherRain => '雨';

  @override
  String get weatherSnow => '雪';

  @override
  String get weatherThunder => '雷暴';

  @override
  String get editProfile => '编辑资料';

  @override
  String get nickname => '昵称';

  @override
  String get aboutYouTitle => '关于你';

  @override
  String get aboutYouBody =>
      '性别、年龄、身高和体重决定你的卡路里与蛋白质目标。Apple 健康提供的数据已自动填入，其余请补充。';

  @override
  String get todoCompleteProfile => '完善个人资料';

  @override
  String get todoCompleteProfileBody => '性别、年龄、身高和体重决定你的目标';

  @override
  String autoFromGoal(String value) {
    return '按目标自动：$value 千卡';
  }

  @override
  String autoProteinRule(String weight, String value) {
    return '自动：1.6 克 × $weight 千克 = $value 克';
  }

  @override
  String autoSatFatRule(String value) {
    return '自动：卡路里预算的 10% = $value 克';
  }

  @override
  String get sourcesTitle => '数据来源与方法';

  @override
  String get sourcesIntro => '你的目标是如何估算的，附可查证的参考资料。';

  @override
  String get sourcesDisclaimer =>
      '以上为面向健康成年人的一般估算，并非医疗建议。在做出重大调整前，请咨询医生或注册营养师，尤其是孕期、未满 18 岁或有健康状况时。';

  @override
  String get viewSource => '查看来源';

  @override
  String get howCalculated => '预算是如何计算的';

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
  String get finishSetup => '完成设置';

  @override
  String get todoAddName => '添加你的名字';

  @override
  String get todoAddNameBody => '以便每天用名字问候你';

  @override
  String get todoConnectHealthBody => '同步年龄、身高、体重和卡路里';

  @override
  String get syncedFromHealth => '来自 Apple 健康';

  @override
  String get heightTitle => '身高';

  @override
  String get calorieBudgetExplainer => '每日卡路里预算 = 基础代谢 + 活动消耗 + 卡路里缺口目标。';

  @override
  String get navToday => '今天';

  @override
  String get navTrends => '趋势';

  @override
  String get navSettings => '我的';

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
    return '静息 $resting · 活动 $active · 缺口 $adjustment';
  }

  @override
  String budgetBreakdownEst(String burn, String adjustment) {
    return '预计消耗 $burn · 缺口 $adjustment';
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
  String onTargetShort(int met, int total) {
    return '$met/$total 天达标';
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
  String get repeatDaily => '每天记录';

  @override
  String get repeatDailyHint => '适合补剂或每日常吃的食物——每天都会计入，无需重复记录';

  @override
  String get dailyBadge => '每天';

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
  String get deleteAccount => '删除账户';

  @override
  String get deleteAccountBody =>
      '这将从我们的服务器永久删除你的账户和所有同步数据，并退出登录。本设备上的数据将保留。此操作无法撤销。';

  @override
  String get accountDeleted => '账户已删除';

  @override
  String get deleteAccountFailed => '删除账户失败，请重试。';

  @override
  String get deleteAccountSignInAgain => '登录已过期，未删除任何数据。请重新登录后再试一次。';

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

  @override
  String get reminders => '提醒';

  @override
  String get remindersSubtitle => '轻松提醒你记录每一餐——早餐、午餐、晚餐，还有深夜补记。';

  @override
  String get remindersEnable => '每日用餐提醒';

  @override
  String get remindersDenied => '本应用的通知已关闭，请在系统「设置」中开启以接收提醒。';

  @override
  String remindersActive(int count) {
    return '$count 个已开启';
  }

  @override
  String get remindersOff => '已关闭';

  @override
  String get remindersNone => '还没有提醒，点击下方添加一个。';

  @override
  String get addReminder => '添加提醒';

  @override
  String get onboardingRemindersTitle => '保持记录习惯';

  @override
  String get onboardingRemindersBody =>
      '我们会发送轻松友好的提醒，帮你记录每一餐——早餐、午餐和晚餐（还有可选的深夜补记）。随时可在设置中调整或关闭。';

  @override
  String get enableReminders => '开启提醒';

  @override
  String get onboardingRemindersEnabled => '提醒已开启——我们会帮你养成记录习惯。';

  @override
  String get reminderBreakfastTitle => '早餐时间到 🍳';

  @override
  String get reminderBreakfastBody => '先吃饱，再顺手记一笔，别让这一天溜走啦。';

  @override
  String get reminderLunchTitle => '午休啦！🥪';

  @override
  String get reminderLunchBody => '不管吃的是什么，花两秒记一下。两下点击，搞定。';

  @override
  String get reminderDinnerTitle => '开饭咯 🍝';

  @override
  String get reminderDinnerBody => '别让这些卡路里悄悄溜走——趁还没吃甜点，快记一下！';

  @override
  String get reminderSnackTitle => '深夜小馋猫？🌙';

  @override
  String get reminderSnackBody => '零食也要算——我们不评判。记一笔，今天就圆满收工。';

  @override
  String get beans => '豆子';

  @override
  String get beansBalance => '豆子余额';

  @override
  String get beansPerScan => '每次拍照分析消耗 1 颗豆子';

  @override
  String get beansHistory => '交易记录';

  @override
  String get beansEmpty => '暂无交易记录。';

  @override
  String get topUp => '充值';

  @override
  String get beansGrant => '新人福利';

  @override
  String get beansSpend => '拍照分析';

  @override
  String get beansPurchase => '充值';

  @override
  String get beansRefund => '退款';

  @override
  String beansCount(int count) {
    return '$count 颗豆子';
  }

  @override
  String priceSgd(String value) {
    return 'SGD $value';
  }

  @override
  String get paywallTitle => '豆子用完啦';

  @override
  String get paywallBody => '每次拍照分析消耗 1 颗豆子。充值后即可继续记录每一餐。';

  @override
  String get beansStubNote => '演示版本——购买即时到账，正式支付即将上线。';

  @override
  String beansBought(int count) {
    return '已添加 $count 颗豆子';
  }

  @override
  String scansLeft(int count) {
    return '剩余 $count 次拍照';
  }

  @override
  String get iapUnavailable => '暂时无法购买。';

  @override
  String get iapPending => '购买处理中…';

  @override
  String get iapFailed => '购买失败，请重试。';

  @override
  String get beansChoosePack => '充值豆子';

  @override
  String get beansSecretUnlocked => '已解锁隐藏礼包 🫘';

  @override
  String get beansCustom => '自定义';

  @override
  String get beansCustomTitle => '自定义充值';

  @override
  String get beansCustomLabel => '豆子数量';

  @override
  String get beansBestValue => '超值';

  @override
  String get dashboard => '数据看板';

  @override
  String get dashboardSample => '示例数据——接入分析与 App Store Connect 后可查看真实数据。';

  @override
  String get mDownloads => '下载量';

  @override
  String get mActiveToday => '今日活跃';

  @override
  String get mOpens => '总打开次数';

  @override
  String get mOpens7d => '打开 · 近 7 天';

  @override
  String get mPhotos => '拍照分析次数';

  @override
  String get mBeansSold => '豆子售出';

  @override
  String get mRevenue => '收入';

  @override
  String get mRefunds => '退款';

  @override
  String versionLabel(String name, String version, String build) {
    return '$name $version ($build)';
  }

  @override
  String get accountIdTitle => '账户 ID';

  @override
  String get accountIdHint => '你的账户在同步数据库中的 ID。';

  @override
  String get accountIdSignedOut => '登录后可查看账户 ID。';

  @override
  String get accountIdCopied => '已复制账户 ID';

  @override
  String get copy => '复制';

  @override
  String get close => '关闭';

  @override
  String get yourCircle => '我的圈子';

  @override
  String get evaDailyLesson => '每日一课';

  @override
  String get addFriend => '添加';

  @override
  String get circleRequests => '好友请求';

  @override
  String circleRequestsN(int count) {
    return '好友请求（$count）';
  }

  @override
  String get pendingLabel => '待接受';

  @override
  String get invitePeople => '添加好友';

  @override
  String get inviteShareLink => '分享邀请链接';

  @override
  String get inviteLinkCopied => '邀请链接已复制';

  @override
  String get inviteHandleHelp => '好友的用户名会显示在对方「添加好友」页面的顶部——可向对方索取。';

  @override
  String get inviteSend => '发送邀请';

  @override
  String inviteSent(String handle) {
    return '已向 $handle 发送邀请';
  }

  @override
  String get yourHandle => '我的用户名';

  @override
  String get setHandle => '设置用户名';

  @override
  String get handleHint => '字母、数字或下划线';

  @override
  String handleCopied(String handle) {
    return '已复制 $handle';
  }

  @override
  String handleSaved(String handle) {
    return '你的用户名是 $handle，分享给好友即可添加你';
  }

  @override
  String get handleTaken => '该用户名已被占用，换一个试试';

  @override
  String get handleInvalid => '请使用 2–20 个字母、数字或下划线';

  @override
  String get handleError => '保存用户名失败，请重试';

  @override
  String get shareToCircle => '分享到圈子';

  @override
  String get shareToCircleHint => '圈子好友可见 3 天';

  @override
  String get feedTitle => '圈子动态';

  @override
  String get feedYou => '你';

  @override
  String get foodStory => '美食故事';

  @override
  String get foodStoryArchive => '最近 7 天';

  @override
  String get shareFirstMeal => '扫一张餐食，开启你的美食故事。';

  @override
  String get deleteStory => '从故事中删除';

  @override
  String get deleteStoryBody => '将这餐从美食故事中移除？你的饮食日志仍会保留。';

  @override
  String get storyDeleted => '已从美食故事中移除';

  @override
  String get profilePhoto => '头像';

  @override
  String get removePhoto => '移除照片';

  @override
  String get feedSomeone => '好友';

  @override
  String get feedEmpty => '还没有动态。拍一餐分享到你的圈子吧。';

  @override
  String feedReceived(int count) {
    return '$count 个反应';
  }

  @override
  String get todayLabel => '今天';

  @override
  String get streakLabel => '连续天数';

  @override
  String streakDays(int count) {
    return '$count 天';
  }

  @override
  String get friendAdherence => '达标 · 近 7 天';

  @override
  String get removeFriend => '移出圈子';

  @override
  String removeFriendQ(String name) {
    return '确定将 $name 移出你的圈子吗？';
  }

  @override
  String get noRequests => '暂无待处理的请求。';

  @override
  String get accept => '接受';

  @override
  String get decline => '拒绝';

  @override
  String friendAccepted(String name) {
    return '$name 加入了你的圈子 🎉';
  }

  @override
  String get manageCircle => '管理圈子';

  @override
  String get shareInvite => '分享邀请';

  @override
  String get scanToConnect => '扫码把我加入你的圈子';

  @override
  String get inviteLinkLabel => '我的邀请链接';

  @override
  String get copyLink => '复制链接';

  @override
  String shareInviteMessage(String link) {
    return '在 Food at Peace 添加我 🍵 $link';
  }

  @override
  String get connectTitle => '加入你的圈子';

  @override
  String connectPrompt(String handle) {
    return '与 $handle 互相连接？你们将看到彼此每天的饮食趋势。';
  }

  @override
  String get connectCta => '连接';

  @override
  String get connecting => '连接中…';

  @override
  String connectedToast(String name) {
    return '你已和 $name 互相连接 🎉';
  }

  @override
  String get connectFailed => '连接失败，请重试。';

  @override
  String get sectionConnected => '已连接';

  @override
  String get sectionRequests => '请求';

  @override
  String get sectionInvited => '已邀请';

  @override
  String get cancelInvite => '取消';

  @override
  String get circleEmpty => '你的圈子还是空的。分享邀请链接来添加好友吧。';

  @override
  String get circleActivity => '圈子动态';

  @override
  String get circleActivitySubtitle => '好友分享餐食时通知我';

  @override
  String circleSharedMeal(String name) {
    return '$name 分享了一餐 🍵';
  }

  @override
  String get aFriend => '一位好友';

  @override
  String circleRequestNotif(String name) {
    return '$name 想加入你的圈子 👋';
  }

  @override
  String circleAcceptedNotif(String name) {
    return '$name 接受了 — 你们已连接 🎉';
  }

  @override
  String circleReactionNotif(String name, String emoji) {
    return '$name 对你的餐食回应了 $emoji';
  }

  @override
  String get addByHandle => '通过 @用户名 添加';

  @override
  String addByHandleSent(String handle) {
    return '已向 $handle 发送好友请求';
  }
}
