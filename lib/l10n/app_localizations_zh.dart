// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Wavelog 移动端';

  @override
  String get splashConnecting => '正在连接';

  @override
  String get navHome => '首页';

  @override
  String get navLogbook => '通联日志';

  @override
  String get navLookup => '查询';

  @override
  String get navStation => '电台';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get refresh => '刷新';

  @override
  String get continueBtn => '继续';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get loading => '加载中…';

  @override
  String get error => '错误';

  @override
  String get success => '成功';

  @override
  String get change => '修改';

  @override
  String get goWeb => '前往 →';

  @override
  String get editOnWeb => '网页端编辑';

  @override
  String get openInBrowser => '在浏览器打开';

  @override
  String get serverSetupTitle => '服务器设置';

  @override
  String get serverSetupSubtitle => '配置你的 Wavelog 服务器';

  @override
  String get serverUrlLabel => 'Wavelog 服务器地址';

  @override
  String get serverUrlHint => 'https://log.example.com';

  @override
  String get testConnection => '测试连接';

  @override
  String get testingConnection => '正在测试…';

  @override
  String get sslIssueTitle => 'SSL 证书异常';

  @override
  String get sslIssueBody =>
      '无法验证该服务器 SSL 证书，可能是自签名证书或证书已过期。是否继续并跳过验证？（仅建议在你信任的服务器上使用）';

  @override
  String get sslIssueAllow => '跳过验证继续';

  @override
  String get scopeTestSectionTitle => '权限域检测';

  @override
  String get scopeTestRunning => '正在检测权限…';

  @override
  String get scopeTestAllPassed => '所需全部权限域已配置';

  @override
  String get scopeTestSomeFailed => '缺少部分权限域';

  @override
  String get scopeTestAddHint => '创建 API 令牌时添加该权限域';

  @override
  String get qsoSyncBigTitle => '哇，通联记录数量非常多！';

  @override
  String get qsoSyncBigBody => '正在同步你的通联记录，可能需要一两分钟。';

  @override
  String get qsoSyncSection => '通联记录同步';

  @override
  String get qsoSyncResetBtn => '重置同步';

  @override
  String get qsoSyncResetHint => '适用于修改通联记录或同步异常时';

  @override
  String get qsoSyncResetStarted => '后台已重新启动同步';

  @override
  String get qsoSyncIntervalLabel => '检查间隔';

  @override
  String get qsoSyncIntervalHint => '后台重新检查 QSO 内容的频率';

  @override
  String get connectionSuccess => '连接成功！';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get apiKeyCopied => 'API 密钥已复制';

  @override
  String get loginTitle => '登录';

  @override
  String get serverBtn => '服务器';

  @override
  String get addAccountBtn => '添加账号';

  @override
  String get signInBtn => '登录';

  @override
  String get deleteProfile => '删除';

  @override
  String get deleteProfileTitle => '删除账号';

  @override
  String deleteProfileConfirm(String name) {
    return '从本设备移除 $name？';
  }

  @override
  String get displayName => '显示名称';

  @override
  String get callsign => '呼号';

  @override
  String get apiKeyLabel => 'API 密钥';

  @override
  String get validating => '正在验证…';

  @override
  String get profileSaved => '账号已保存';

  @override
  String get loginFailed => '登录失败';

  @override
  String get noStationFound => '未找到匹配的电台，将使用呼号';

  @override
  String get homeTitle => '首页';

  @override
  String get addQso => '添加 QSO';

  @override
  String get recentQsos => '最近 QSO';

  @override
  String get statsToday => '今天';

  @override
  String get statsMonth => '本月';

  @override
  String get statsYear => '本年';

  @override
  String get statsTotal => '总计';

  @override
  String get noRecentQsos => '暂无 QSO';

  @override
  String get syncNow => '立即同步';

  @override
  String pendingSync(int count) {
    return '$count 条 QSO 待同步';
  }

  @override
  String get offlineBanner => '离线 — QSO 已保存在本地';

  @override
  String get activeStation => '当前电台';

  @override
  String get logbookTitle => '通联日志';

  @override
  String get filterAll => '全部';

  @override
  String get filterAllModes => '全部模式';

  @override
  String get searchHint => '搜索呼号…';

  @override
  String get noQsos => '未找到 QSO';

  @override
  String get qsoDetailTitle => 'QSO 详情';

  @override
  String get qsoNotFound => '未找到该 QSO';

  @override
  String get signal => '信号';

  @override
  String get rstSent => '发送 RST';

  @override
  String get rstReceived => '接收 RST';

  @override
  String get txPower => '发射功率';

  @override
  String get counterStation => '对方电台';

  @override
  String get country => '国家';

  @override
  String get continent => '大洲';

  @override
  String get dxcc => 'DXCC';

  @override
  String get cqZone => 'CQ 分区';

  @override
  String get ituZone => 'ITU 分区';

  @override
  String get gridSquare => '网格';

  @override
  String get propMode => '传播方式';

  @override
  String get distance => '距离';

  @override
  String get qslStatus => 'QSL 状态';

  @override
  String get paperQsl => '纸质';

  @override
  String get lotwQsl => 'LoTW';

  @override
  String get eqslQsl => 'eQSL';

  @override
  String get qrzQsl => 'QRZ.com';

  @override
  String get clublog => 'Club Log';

  @override
  String get hrdlog => 'HRDLog';

  @override
  String get qslSent => '已发送';

  @override
  String get qslRcvd => '已收到';

  @override
  String get qslReceived => '已收到';

  @override
  String get qslMethod => '方式';

  @override
  String get awards => '奖状编号';

  @override
  String get iota => 'IOTA';

  @override
  String get sota => 'SOTA';

  @override
  String get wwff => 'WWFF';

  @override
  String get pota => 'POTA';

  @override
  String get myStation => '我的电台';

  @override
  String get myCallsign => '我的呼号';

  @override
  String get contest => '竞赛';

  @override
  String get serialSent => '发送序号';

  @override
  String get serialReceived => '接收序号';

  @override
  String get solarConditions => '太阳活动状况';

  @override
  String get aIndex => 'A 指数';

  @override
  String get kIndex => 'K 指数';

  @override
  String get sfi => 'SFI';

  @override
  String get notesSection => '备注';

  @override
  String get rawAdif => '原始 ADIF';

  @override
  String get showAll => '显示全部';

  @override
  String get showLess => '收起';

  @override
  String get qrzProfile => 'QRZ 资料';

  @override
  String get addQsoTitle => '添加 QSO';

  @override
  String get liveQso => '实时 QSO';

  @override
  String get historicalQso => '补记 QSO';

  @override
  String get callsignField => '呼号 *';

  @override
  String get lookupSearch => 'QRZ 查询';

  @override
  String get liveDateTimeLabel => '日期/时间（UTC）— 实时';

  @override
  String get dateTimeLabel => '日期/时间（UTC）';

  @override
  String get bandField => '波段 *';

  @override
  String get modeField => '模式 *';

  @override
  String get frequencyField => '频率（MHz）';

  @override
  String get rstSentField => '发送 RST *';

  @override
  String get rstRcvdField => '接收 RST *';

  @override
  String get nameField => '姓名';

  @override
  String get qthField => 'QTH';

  @override
  String get gridField => '网格';

  @override
  String get commentField => '备注';

  @override
  String get stationProfileField => '电台配置';

  @override
  String get saveQsoBtn => '保存 QSO';

  @override
  String qsoSaved(String callsign) {
    return '✓  $callsign 已保存';
  }

  @override
  String qsoSavedLocal(String callsign) {
    return '✓  $callsign 已保存到本地';
  }

  @override
  String get noActiveStation => '未选择当前电台';

  @override
  String get lookupTitle => '呼号查询';

  @override
  String get lookupHint => '输入呼号…';

  @override
  String get lookupBtn => '搜索';

  @override
  String get recentSearches => '最近搜索';

  @override
  String get clearHistory => '清空历史';

  @override
  String get makeQso => '记录 QSO';

  @override
  String get notFound => '未找到';

  @override
  String get stationsTitle => '电台';

  @override
  String stationActivated(String callsign) {
    return '已将 $callsign 设为当前电台';
  }

  @override
  String get stationWebInfo => '请通过 Wavelog 网页端添加和编辑电台。';

  @override
  String get noStations => '暂无电台';

  @override
  String get noStationsHint => '请通过 Wavelog 网页端添加电台。';

  @override
  String get addStationOnWeb => '在 Wavelog 上添加电台';

  @override
  String get adifTitle => 'ADIF 导入 / 导出';

  @override
  String get importTab => '导入';

  @override
  String get exportTab => '导出';

  @override
  String get selectAdifFile => '选择 ADIF 文件';

  @override
  String get selectFileBtn => '选择文件（.adi / .adif）';

  @override
  String get stationRequired => '电台配置 *';

  @override
  String importing(int done, int total) {
    return '正在导入… $done/$total';
  }

  @override
  String get importBtn => '导入';

  @override
  String get fileReadError => '无法读取文件内容，请重试';

  @override
  String get invalidFileExtension => '请选择 .adi 或 .adif 扩展名的文件';

  @override
  String get exportFilters => '导出筛选';

  @override
  String get stationFilter => '电台';

  @override
  String get allStations => '全部电台';

  @override
  String get startDate => '开始';

  @override
  String get endDate => '结束';

  @override
  String get notSelected => '未选择';

  @override
  String get clearDates => '清除日期';

  @override
  String get exporting => '正在导出…';

  @override
  String get exportAndShare => '导出并分享';

  @override
  String get copyPath => '复制路径';

  @override
  String get reshare => '再次分享';

  @override
  String get pathCopied => '文件路径已复制';

  @override
  String qsoExported(int count) {
    return '已导出 $count 条 QSO';
  }

  @override
  String get noStationForExport => '未找到可导出的电台';

  @override
  String qsoImported(int imported, int total) {
    return '已导入 $imported / $total 条 QSO';
  }

  @override
  String get selectSaveLocation => '选择保存位置';

  @override
  String get copySuffix => '（副本）';

  @override
  String get errNetwork => '无网络连接 — 请检查网络';

  @override
  String get errTimeout => '连接超时';

  @override
  String get errLocalNetworkPermission => '需要本地网络权限，请在 Android 设置中为本应用开启';

  @override
  String get errUnauthorized => 'API 密钥无效';

  @override
  String get settingsTitle => '设置';

  @override
  String get connectionSection => '连接';

  @override
  String get sessionSection => '会话';

  @override
  String get loggedIn => '已登录';

  @override
  String get logoutBtn => '退出登录';

  @override
  String get logoutTitle => '退出登录';

  @override
  String get logoutConfirm => '确定要退出登录吗？';

  @override
  String get switchAccountBtn => '切换账号';

  @override
  String get activeStationSection => '当前电台';

  @override
  String get selectStationBtn => '选择电台';

  @override
  String get addStationWeb => '在网页端添加电台';

  @override
  String get defaultsSection => '默认值';

  @override
  String get defaultBand => '默认波段';

  @override
  String get defaultMode => '默认模式';

  @override
  String get appSection => '应用';

  @override
  String get darkTheme => '深色主题';

  @override
  String get darkThemeHint => '户外使用推荐';

  @override
  String get offlineMode => '离线模式';

  @override
  String get offlineModeHint => '先将 QSO 保存到本地，之后再同步';

  @override
  String get allowInsecureSsl => '允许未验证的 SSL 证书';

  @override
  String get allowInsecureSslHint => '信任自签名或私有 CA 证书（适用于自建服务器）。不建议在公共网络上使用。';

  @override
  String get languageLabel => '语言';

  @override
  String get infoSection => '信息';

  @override
  String get aboutAppBtn => '关于';

  @override
  String get aboutAppHint => '版本、开发者、许可协议';

  @override
  String get dataSection => '数据';

  @override
  String get clearCacheBtn => '清除 QSO 缓存';

  @override
  String get clearCacheHint => '删除本地 QSO 缓存';

  @override
  String get clearCacheTitle => '清除缓存';

  @override
  String get clearCacheConfirm => '本地 QSO 缓存将被删除，此操作无法撤销。';

  @override
  String get clearCacheAction => '清除';

  @override
  String get cacheCleared => '缓存已清除';

  @override
  String get langSystem => '跟随系统';

  @override
  String get langEnglish => 'English';

  @override
  String get langTurkish => 'Türkçe';

  @override
  String get langPolish => 'Polski';

  @override
  String get langGerman => 'Deutsch';

  @override
  String get langFrench => 'Français';

  @override
  String get langItalian => 'Italiano';

  @override
  String get langJapanese => '日本語';

  @override
  String get langKorean => '한국어';

  @override
  String get langRussian => 'Русский';

  @override
  String get langChinese => '简体中文';

  @override
  String get aboutTitle => '关于';

  @override
  String get appDescription => '面向 Wavelog 的开源 Android 日志应用';

  @override
  String versionLabel(String version, String build) {
    return '版本 $version（构建 $build）';
  }

  @override
  String get mobileDeveloperSection => '移动端应用开发者';

  @override
  String get wavelogProjectSection => 'Wavelog 项目';

  @override
  String get wavelogDescription => '基于网页的业余无线电日志系统';

  @override
  String get coreDevelopers => '核心开发者';

  @override
  String get mitLicense => 'MIT 许可证';

  @override
  String get mitDescription => '本应用与 Wavelog 项目均以 MIT 许可证发布。开源软件，不提供任何担保。';

  @override
  String get licenseSection => '许可证';

  @override
  String get dxccDataSection => 'DXCC 数据';

  @override
  String get dxccDataDescription =>
      'DXCC 实体与呼号前缀数据 © 1994– Jim Reisert, AD1C（country-files.com），依据 MIT 许可证使用。';

  @override
  String get errorNoConnection => '无网络连接';

  @override
  String get errorUnauthorized => '未授权 — 请检查 API 密钥';

  @override
  String get errorServer => '服务器错误';

  @override
  String get patchRequiredTitle => '需要安装服务器补丁';

  @override
  String get patchRequiredMessage =>
      '编辑与删除功能需要先在服务器上安装 Wavelog Mobile API 补丁。\n\n安装说明请访问 sp9aqg.pl/install.html。';

  @override
  String get patchRequiredBanner => '编辑与删除功能需要先在服务器上安装 Wavelog Mobile API 补丁。';

  @override
  String get patchViewGuide => '查看指南';

  @override
  String get setupGuideTitle => '设置指南';

  @override
  String get setupGuideIntro => '记录 QSO 之前，请先将应用连接到你的 Wavelog 服务器，按以下步骤操作。';

  @override
  String get setupGuideStep1Title => '1. 服务器地址';

  @override
  String get setupGuideStep1Body =>
      '填写你在浏览器中打开 Wavelog 所用的地址，例如 https://yourdomain.com，末尾不要带斜杠。';

  @override
  String get setupGuideStep2Title => '2. API v2 令牌';

  @override
  String get setupGuideStep2Body =>
      '在 Wavelog 中依次进入 设置 → API → API 令牌（v2）→ 新建令牌，勾选应用所需的权限域（粘贴令牌后应用会自动检测）。复制生成的令牌（以 wl2_ 开头）并粘贴到应用中。';

  @override
  String get setupGuideStep3Title => '3. 呼号与显示名称';

  @override
  String get setupGuideStep3Body =>
      '呼号：你自己的业余无线电呼号，用于匹配你的电台。显示名称：任意名称，便于在本设备上识别该登录。';

  @override
  String get setupGuideContinueBtn => '开始设置';

  @override
  String get migrationTokenHint => 'wl2_…';

  @override
  String get migrationTokenLabel => 'API v2 令牌';

  @override
  String get migrationValidateBtn => '验证并继续';

  @override
  String get migrationValidating => '正在验证…';

  @override
  String get migrationTokenEmpty => '请粘贴你的 wl2_ 令牌。';

  @override
  String get migrationTokenInvalid => '令牌无效 — 请检查后重试。';

  @override
  String get patchNotInstalledTitle => '未检测到补丁';

  @override
  String get patchNotInstalledBody =>
      '服务器上似乎未安装 Wavelog Mobile 补丁。\n\n没有该补丁，API v2 令牌（wl2_…）无法使用。请先完成第 1 步。';

  @override
  String get patchInstallFirst => '安装补丁';

  @override
  String get appSubtitle => '业余无线电日志应用';

  @override
  String get switchToLightTheme => '切换到浅色主题';

  @override
  String get switchToDarkTheme => '切换到深色主题';

  @override
  String get deleteQsoTitle => '删除 QSO';

  @override
  String deleteQsoConfirm(String callsign, String date) {
    return '永久删除 $date 与 $callsign 的 QSO？';
  }

  @override
  String get editTooltip => '编辑';

  @override
  String get shareAdifTooltip => '分享 ADIF';

  @override
  String get localNotSynced => '本地记录 — 尚未同步';

  @override
  String get satellite => '卫星';

  @override
  String get satelliteMode => '卫星模式';

  @override
  String get antenna => '天线';

  @override
  String get nameLabel => '姓名';

  @override
  String get stateProvince => '省/州';

  @override
  String get county => '县';

  @override
  String get city => '城市';

  @override
  String get continentAF => '非洲';

  @override
  String get continentAN => '南极洲';

  @override
  String get continentAS => '亚洲';

  @override
  String get continentEU => '欧洲';

  @override
  String get continentNA => '北美洲';

  @override
  String get continentOC => '大洋洲';

  @override
  String get continentSA => '南美洲';

  @override
  String get qrzProfileLoading => '正在加载 QRZ 资料…';

  @override
  String viewOnQrz(String callsign) {
    return '在 QRZ.com 查看（$callsign）';
  }

  @override
  String get qslMethods => 'QSL 方式';

  @override
  String get bureau => '卡片局';

  @override
  String qslManagerPrefix(String manager) {
    return '管理者：$manager';
  }

  @override
  String get callsignCopied => '呼号已复制';

  @override
  String get uploadedStatus => '已上传';

  @override
  String get notUploadedStatus => '未上传';

  @override
  String get matchedStatus => '已匹配';

  @override
  String get toDeleteStatus => '待删除';

  @override
  String get yes => '是';

  @override
  String get requested => '已申请';

  @override
  String get no => '否';

  @override
  String get invalid => '无效';

  @override
  String get viaDirect => '直邮';

  @override
  String get viaElectronic => '电子方式';

  @override
  String get viaMail => '邮寄';

  @override
  String otherAdifFields(int count) {
    return '其他 ADIF 字段（$count）';
  }

  @override
  String get editQsoTitle => '编辑 QSO';

  @override
  String get qsoUpdated => 'QSO 已更新';

  @override
  String get qsoUpdatedLocal => 'QSO 已在本地更新';

  @override
  String get counterStationHint => '输入呼号后，QRZ\n资料和历史 QSO\n将显示在这里。';

  @override
  String previousQsosCount(int count) {
    return '历史 QSO（$count）';
  }

  @override
  String morePreviousQsos(int count) {
    return '+$count 更多…';
  }

  @override
  String previousQsosWithCallsign(String callsign) {
    return '与 $callsign 的历史 QSO';
  }

  @override
  String totalQsos(int count) {
    return '共 $count 条';
  }

  @override
  String get workedBefore => '曾通联过';

  @override
  String get lastQsoLabel => '上次 QSO';

  @override
  String get themeLabel => '主题';

  @override
  String get darkThemeActive => '深色主题已启用';

  @override
  String get lightThemeActive => '浅色主题已启用';

  @override
  String get lightThemeLabel => '浅色';

  @override
  String get darkThemeLabel => '深色';

  @override
  String get commentNotes => '备注 / 说明';

  @override
  String get commentLabel => '备注';

  @override
  String get exchangeReceived => '接收交换信息';

  @override
  String get exchangeSent => '发送交换信息';

  @override
  String get contestIdLabel => '竞赛';

  @override
  String get sigLabel => 'SIG';

  @override
  String get stationSetup => '电台设置';

  @override
  String get logbooks => '通联日志';

  @override
  String get locations => '地点';

  @override
  String get newLogbook => '新建通联日志';

  @override
  String get logbookName => '日志名称';

  @override
  String get renameLogbook => '重命名';

  @override
  String get deleteLogbook => '删除通联日志';

  @override
  String get editStation => '编辑';

  @override
  String get cloneStation => '克隆';

  @override
  String get deleteStation => '删除';

  @override
  String get deleteStationConfirm => '删除电台';

  @override
  String get deleteStationWarning => '该电台的所有 QSO 将被永久删除。是否继续？';

  @override
  String get stationDeleted => '电台已删除';

  @override
  String get stationUpdated => '电台已更新';

  @override
  String get stationCloned => '电台已克隆';

  @override
  String get linkLocation => '关联地点';

  @override
  String get unlinkLocation => '取消关联';

  @override
  String get linkedLocations => '已关联地点';

  @override
  String get newStationName => '新电台名称';

  @override
  String get deleteLogbookConfirm => '删除通联日志';

  @override
  String get deleteLogbookWarning => '该通联日志将被删除，已关联的地点会保留。是否继续？';

  @override
  String get logbookDeleted => '通联日志已删除';

  @override
  String get hrdlogCode => 'HRDLog 代码';

  @override
  String get webAdifApiKey => 'WebADIF API 密钥';

  @override
  String get webAdifApiUrl => 'WebADIF API 地址';

  @override
  String get basicInfo => '基本信息';

  @override
  String get locationSectionTitle => '位置';

  @override
  String get awardReferences => '奖状编号';

  @override
  String get integrationsSectionTitle => '第三方集成';

  @override
  String get stationSettingsSection => '电台设置';

  @override
  String get editStationTitle => '编辑电台';

  @override
  String get newStationTitle => '新建电台';

  @override
  String get saveChangesBtn => '保存修改';

  @override
  String get createStationBtn => '创建电台';

  @override
  String get stationCreated => '电台已创建';

  @override
  String get stationCreateFailed => '失败，同名配置可能已存在。';

  @override
  String get stationProfileNameLabel => '电台配置名称 *';

  @override
  String get stationProfileNameHint => '家庭电台';

  @override
  String get cityQth => '城市 / QTH';

  @override
  String get powerWatts => '功率（W）';

  @override
  String get dxccCountry => 'DXCC / 国家';

  @override
  String get selectLabel => '请选择…';

  @override
  String get dxccSearch => '搜索 DXCC / 国家';

  @override
  String get deletedDxcc => '已删除的 DXCC';

  @override
  String get eqslQthNicknameLabel => 'eQSL QTH 昵称';

  @override
  String get eqslDefaultMsgLabel => 'eQSL 默认留言';

  @override
  String get pending => '待处理';

  @override
  String get uploadDisabled => '已禁用';

  @override
  String get uploadEnabled => '已启用';

  @override
  String get uploadRealtime => '实时';

  @override
  String get qrzApiKeyLabel => 'QRZ.com 日志 API 密钥';

  @override
  String get qrzUploadLabel => 'QRZ.com 上传';

  @override
  String get clublogIgnoreTitle => '忽略 Clublog';

  @override
  String get clublogIgnoreSubtitle => '该电台不再上传至 Clublog';

  @override
  String get clublogRealtimeTitle => 'Clublog 实时上传';

  @override
  String get clublogRealtimeSubtitle => '实时将 QSO 上传至 Clublog';

  @override
  String get hrdlogUsernameLabel => 'HRDLog.net 用户名';

  @override
  String get hrdlogApiKeyLabel => 'HRDLog.net API 密钥';

  @override
  String get hrdlogUploadLabel => 'HRDLog.net 上传';

  @override
  String get qo100ApiKeyLabel => 'QO-100 DX Club API 密钥';

  @override
  String get qo100RealtimeTitle => 'QO-100 DX Club 实时上传';

  @override
  String get qo100RealtimeSubtitle => '实时将 QSO 上传至 QO-100 DX Club';

  @override
  String get oqrsSectionTitle => 'OQRS（在线 QSL）';

  @override
  String get oqrsEnabledTitle => '启用 OQRS';

  @override
  String get oqrsEnabledSubtitle => '启用在线 QSL 申请系统';

  @override
  String get oqrsTextLabel => 'OQRS 说明文字';

  @override
  String get oqrsEmailLabel => 'OQRS 邮箱';

  @override
  String get setAsActiveStationTitle => '设为当前电台';

  @override
  String get setAsActiveStationSubtitle => '在 Wavelog 中将该电台标记为当前电台';

  @override
  String get linkToActiveLogbookTitle => '关联到当前日志';

  @override
  String get linkToActiveLogbookSubtitle => '创建时自动关联到当前通联日志';

  @override
  String get active => '当前';

  @override
  String get loadDetailsFailed => '加载详情失败';

  @override
  String get cannotDeleteActiveStation => '无法删除当前电台。';

  @override
  String get navStats => '统计';

  @override
  String get statisticsTitle => '统计';

  @override
  String get uniqueCallsigns => '不同呼号数';

  @override
  String get currentStreak => '当前连续天数';

  @override
  String streakDays(int count) {
    return '$count 天';
  }

  @override
  String get bandDistribution => '波段分布';

  @override
  String get modeDistribution => '模式分布';

  @override
  String get perStation => '按电台';

  @override
  String get basedOnCache => '波段 / 模式 / 电台统计基于缓存的 QSO。';

  @override
  String get statsTab => '统计';

  @override
  String get propagationTab => '传播';

  @override
  String get bandConditions => '波段状况';

  @override
  String get dayTime => '白天';

  @override
  String get nightTime => '夜间';

  @override
  String get conditionGood => '良好';

  @override
  String get conditionFair => '一般';

  @override
  String get conditionPoor => '较差';

  @override
  String lastUpdated(String time) {
    return '更新于：$time';
  }

  @override
  String get noSolarData => '无法加载太阳活动数据';

  @override
  String get potaStats => 'POTA 统计';

  @override
  String get potaTotalQsos => 'POTA QSO';

  @override
  String get potaActivatedParks => '已激活公园';

  @override
  String get potaAllParks => '全部公园';

  @override
  String get potaActivatedBadge => '已激活';

  @override
  String get potaAttemptBadge => '尝试';

  @override
  String get potaNoStation => '未配置 POTA 电台';

  @override
  String get potaNoQsos => '缓存中没有 POTA QSO';

  @override
  String get navSpot => '通告';

  @override
  String get spotTitle => '通告';

  @override
  String get spotAdd => '发布通告';

  @override
  String get spotSend => '发送通告';

  @override
  String get spotSent => '通告已发送！';

  @override
  String get spotNoResults => '未找到通告';

  @override
  String get spotLoadError => '无法加载通告';

  @override
  String get spotActivator => '激活者呼号';

  @override
  String get spotSpotter => '发布者呼号';

  @override
  String get spotFrequency => '频率（kHz）';

  @override
  String get spotReference => '公园编号';

  @override
  String get spotComments => '评论';

  @override
  String get spotCommentsHint => 'QRZ、CQ POTA…';

  @override
  String get spotInvalidRef => '格式无效（例如 PL-0001）';

  @override
  String get sortNewest => '最新在前';

  @override
  String get sortOldest => '最早在前';

  @override
  String get filterBand => '波段';

  @override
  String get filterMode => '模式';

  @override
  String get filterCountry => '国家';

  @override
  String get filterAssociation => '协会';

  @override
  String get spotAddComingSoon => '发布通告 — 即将推出';

  @override
  String get filterClear => '清除筛选';

  @override
  String get mode => '模式';

  @override
  String get required => '必填';

  @override
  String get invalidNumber => '数字无效';

  @override
  String get potaAutoSpot => '自动通告';

  @override
  String get potaAutoSpotHint => '在 POTA 或 SOTA 电台记录 QSO 时自动发布自身通告（各 30 分钟冷却）';

  @override
  String get spotRefreshLabel => '通告刷新间隔';

  @override
  String get spotRefreshHint => '按此间隔自动刷新通告列表';

  @override
  String autoSpotSent(String ref) {
    return '自动通告已发送：$ref';
  }

  @override
  String get autoSpotWillFire => '该 QSO 将触发通告';

  @override
  String autoSpotCooldown(int min) {
    return '通告已发送 · $min 分钟后可再次发送';
  }

  @override
  String get autoSpotCooldownSoon => '通告已发送 · 即将可再次发送';

  @override
  String autoSpotKeyChanged(String fields) {
    return '$fields 已变更 · 将触发新通告';
  }

  @override
  String get autoSpotFieldFreq => '频率';

  @override
  String get autoSpotFieldMode => '模式';

  @override
  String get autoSpotFieldRef => '公园';

  @override
  String get logbookSummaryTitle => '最近 QSO';

  @override
  String todayQsoCount(int count) {
    return '今天：$count 条 QSO';
  }

  @override
  String get colDateTime => '日期/时间';

  @override
  String get colRstSent => 'RST(发)';

  @override
  String get colRstRcvd => 'RST(收)';

  @override
  String get submodeLabel => '子模式';

  @override
  String selectedCount(int count) {
    return '已选 $count 条';
  }

  @override
  String get selectAll => '全选';

  @override
  String get exportSelected => '导出';

  @override
  String get deleteSelected => '删除';

  @override
  String deleteSelectedConfirm(int count) {
    return '删除 $count 条 QSO？';
  }

  @override
  String get mapTitle => '地图';

  @override
  String get mapNoData => '未找到含网格信息的 QSO';

  @override
  String mapStationCount(int count) {
    return '$count 个电台';
  }

  @override
  String get dxccProgress => 'DXCC 进度';

  @override
  String get workedCountries => '已通联国家';

  @override
  String get dxccWorked => '已通联';

  @override
  String dxccUniqueEntities(int count) {
    return '$count 个独立实体';
  }

  @override
  String get dxccConfirmed => '已确认（LoTW / eQSL / QSL）';

  @override
  String get dxccRemaining => '剩余';

  @override
  String get dxccLegendConfirmed => '已确认';

  @override
  String get dxccLegendPending => '待确认';

  @override
  String get dxccLegendNotWorked => '未通联';

  @override
  String get spotSummitNotFound => '未找到山峰';

  @override
  String get spotParkNotFound => '未找到公园';

  @override
  String get qsoTypeTitle => '记录 QSO';

  @override
  String get normalQso => '普通 QSO';

  @override
  String get normalQsoDesc => '常规通联记录';

  @override
  String get contestQso => '竞赛 QSO';

  @override
  String get contestQsoDesc => '带交换信息的快速竞赛记录';

  @override
  String get contestLog => '竞赛记录';

  @override
  String get contestSetup => '竞赛设置';

  @override
  String get contestNameHint => '例如 CQ-WW-CW';

  @override
  String get ourExchange => '我方交换信息';

  @override
  String get serialStart => '起始序号';

  @override
  String get showExchangeFields => '交换字段';

  @override
  String get startContest => '开始记录';

  @override
  String get endContest => '结束场次';

  @override
  String get endContestConfirm => '结束本次竞赛场次？（序号计数器和设置将被重置）';

  @override
  String get serialSentLabel => '发序号';

  @override
  String get serialRcvdLabel => '收序号';

  @override
  String get exchangeSentLabel => '发交换';

  @override
  String get exchangeRcvdLabel => '收交换';

  @override
  String get gridSentLabel => '发网格';

  @override
  String get gridRcvdLabel => '收网格';

  @override
  String get logQso => '记录 QSO';

  @override
  String get qsoLogged => 'QSO 已记录';

  @override
  String get contestRecentQsos => '最近';

  @override
  String get contestSessions => '竞赛场次';

  @override
  String get newSession => '新建场次';

  @override
  String get noContestSessions => '暂无竞赛场次';

  @override
  String get noContestSessionsHint => '在网页端创建场次，或点击 + 在此开始。';

  @override
  String get contestSessionActive => '进行中';

  @override
  String get contestSessionEnded => '已结束';

  @override
  String qsoCount(int count) {
    return '$count 条 QSO';
  }

  @override
  String contestSessionDates(String start, String end) {
    return '$start – $end';
  }

  @override
  String get createContestSession => '创建竞赛场次';

  @override
  String get sessionName => '场次名称（可选）';

  @override
  String get sessionNameHint => '例如 家庭电台 — CW';

  @override
  String get selectContest => '选择竞赛 *';

  @override
  String get searchContest => '搜索竞赛…';

  @override
  String get serverContests => '来自服务器';

  @override
  String get builtinContests => '常见竞赛';

  @override
  String get startDateTime => '开始日期/时间 *';

  @override
  String get endDateTime => '结束日期/时间 *';

  @override
  String get durationShortcut4h => '+4h';

  @override
  String get durationShortcut12h => '+12h';

  @override
  String get durationShortcut24h => '+24h';

  @override
  String get durationShortcut48h => '+48h';

  @override
  String get exchangeType => '交换类型';

  @override
  String get exchangeTypeSerial => '序号';

  @override
  String get exchangeTypeExchange => '文本交换';

  @override
  String get exchangeTypeBoth => '序号 + 文本交换';

  @override
  String get createSession => '创建场次';

  @override
  String get sessionCreated => '竞赛场次已创建';

  @override
  String get sessionUpdated => '竞赛场次已更新';

  @override
  String get editContestSession => '编辑竞赛场次';

  @override
  String get saveChanges => '保存修改';

  @override
  String get deleteSession => '删除场次';

  @override
  String get deleteSessionConfirm => '删除该竞赛场次？本次记录的 QSO 将保留在通联日志中。';

  @override
  String get openSession => '开启记录';

  @override
  String get patchRequiredContest => '竞赛场次管理需要安装最新版 Wavelog Mobile 补丁。';

  @override
  String get contestCalendarTitle => '竞赛日历';

  @override
  String get contestCalendarNoContests => '未找到竞赛。';

  @override
  String get contestCalendarToday => '今天';

  @override
  String get contestCalendarThisWeek => '本周';

  @override
  String get contestCalendarUpcoming => '即将开始';

  @override
  String get contestCalendarRecentlyPast => '近期结束';

  @override
  String get contestCalendarLoadError => '无法加载竞赛日历';

  @override
  String get contestCalendarRefresh => '刷新';

  @override
  String get contestCalendarRetry => '重试';

  @override
  String get upcomingContestsTitle => '即将开始的竞赛';

  @override
  String get viewAll => '查看全部';

  @override
  String get noUpcomingContests => '未找到即将开始的竞赛。';

  @override
  String get contestTodayBadge => '今天';

  @override
  String get navStyleLabel => '导航样式';

  @override
  String get navStyleModern => '现代 — 悬浮按钮 + 侧边栏';

  @override
  String get navStyleClassic => '经典 — 6 标签栏';

  @override
  String get drawerMap => '地图';

  @override
  String get drawerContestCalendar => '竞赛日历';

  @override
  String get drawerContestSessions => '竞赛场次';

  @override
  String get drawerAdif => 'ADIF';

  @override
  String get drawerMenu => '菜单';

  @override
  String get antennaCompassTitle => '天线方向';

  @override
  String get targetGrid => '目标网格';

  @override
  String get calculate => '计算';

  @override
  String get shortPath => '短路径';

  @override
  String get longPath => '长路径';

  @override
  String get azimuth => '方位角';

  @override
  String get myHeading => '航向';

  @override
  String get invalidGrid => '网格无效';

  @override
  String get gpsLocating => '正在通过 GPS 定位…请稍候';

  @override
  String get gpsUnavailable => '无法获取 GPS 位置';

  @override
  String get drawerAntenna => '天线方向';

  @override
  String get achievementsTitle => '成就';

  @override
  String get achievementsEmpty => '记录第一个 QSO 即可开始获得徽章！';

  @override
  String get shareAchievement => '分享';

  @override
  String get achievementUnlocked => '成就已解锁！';

  @override
  String progressLabel(int done, int target) {
    return '$done / $target';
  }

  @override
  String get drawerAchievements => '成就';

  @override
  String get drawerCommunity => '社区';

  @override
  String get communityTitle => '社区';

  @override
  String get communityNoActivations => '暂无计划中的激活';

  @override
  String get communityBeFirst => '来第一个发布公告吧！';

  @override
  String get communityAnnounce => '发布激活公告';

  @override
  String get communityFollow => '关注';

  @override
  String get communityUnfollow => '取消关注';

  @override
  String communityFollowers(int count) {
    return '$count 位关注者';
  }

  @override
  String get communityTypeGeneral => '综合';

  @override
  String get communityCallsign => '呼号';

  @override
  String get communityReference => '编号';

  @override
  String get communitySotaRef => 'SOTA 编号（TA/AN-001）';

  @override
  String get communityPotaRef => 'POTA 编号（TA-0001）';

  @override
  String get communityScheduledTime => '计划时间';

  @override
  String get communityNote => '备注（可选）';

  @override
  String get communityNoteHint => '简要说明本次激活…';

  @override
  String get communityAnnounceButton => '发布';

  @override
  String get communityAnnounced => '激活公告已发布！';

  @override
  String get communityRateLimit => '你刚刚发布过内容，请等待几分钟。';

  @override
  String get communityCallsignRequired => '呼号为必填项';

  @override
  String get communityReferenceRequired => '编号为必填项';

  @override
  String get communityBandRequired => '请至少选择一个波段';

  @override
  String get communityActivations => '激活活动';

  @override
  String get communityChat => '聊天';

  @override
  String get communityEditActivation => '编辑激活公告';

  @override
  String get communityDeleteActivation => '删除激活公告';

  @override
  String get communityDeleteActivationConfirm => '删除该激活公告？此操作无法撤销。';

  @override
  String get communityUpdated => '激活公告已更新';

  @override
  String get chatRooms => '聊天室';

  @override
  String get chatGeneral => '综合';

  @override
  String get chatGeneralSubtitle => '通用语言：英语';

  @override
  String get chatMessageHint => '输入消息…';

  @override
  String get chatSend => '发送';

  @override
  String get chatEdit => '编辑';

  @override
  String get chatDelete => '删除';

  @override
  String get chatDeleteConfirm => '删除这条消息？';

  @override
  String get chatEdited => '已编辑';

  @override
  String get chatNoStation => '请先设置当前电台再聊天';

  @override
  String get chatToday => '今天';

  @override
  String get chatYesterday => '昨天';

  @override
  String get chatFollow => '关注';

  @override
  String get chatUnfollow => '取消关注';

  @override
  String get chatFollowing => '已关注该聊天室';

  @override
  String get chatAddReaction => '添加表情回应';

  @override
  String get gifPreparing => '正在准备视频…';

  @override
  String gifCapturing(int percent) {
    return '正在采集画面… $percent%';
  }

  @override
  String get gifEncoding => '正在编码视频…';

  @override
  String get comingSoon => '即将推出';

  @override
  String get noCompassSensor => '无指南针传感器';

  @override
  String get fillFromGps => '从 GPS 填充';

  @override
  String get locationPermissionDenied => '定位权限被拒绝';

  @override
  String gpsError(String error) {
    return 'GPS 错误：$error';
  }

  @override
  String get errParse => '解析服务器响应失败';

  @override
  String get errLocalStorage => '本地存储错误';

  @override
  String get errServer => '服务器错误';

  @override
  String get wpxPrefix => 'WPX 前缀';

  @override
  String get nowBtn => '现在';

  @override
  String get contestOtherCustom => '其他 / 自定义';

  @override
  String get sigInfo => 'SIG 信息';

  @override
  String get migrationTitle => '需要 API v2';

  @override
  String get migrationBody =>
      'Wavelog Mobile 现已使用 Wavelog 的新 API 系统，旧的 API 密钥已失效。按以下步骤即可在几分钟内完成迁移。';

  @override
  String get migrationStep1Title => '安装服务器补丁';

  @override
  String get migrationStep1Body =>
      '需要在你的 Wavelog 服务器上安装一个小更新文件。点击下方的「安装指南」按钮查看分步说明。';

  @override
  String get migrationInstallGuideBtn => '安装指南';

  @override
  String get migrationStep2Title => '创建新的 API 令牌';

  @override
  String get migrationStep2Body =>
      '在 Wavelog 网页端：\n  1. 打开右上角的设置菜单\n  2. 进入“API”→“API 令牌”\n  3. 点击“新建令牌”\n  4. 选择“Wavelog Mobile”预设\n  5. 确认并复制显示的代码\n  （令牌以“wl2_”开头）';

  @override
  String get migrationStep3Title => '更新你的配置';

  @override
  String get migrationStep3Body => '点击下方按钮。服务器地址会保留，只需把复制的新令牌粘贴到输入框。';

  @override
  String get migrationUpdateTokenBtn => '更新令牌';

  @override
  String get migrationHelpBtn => '帮助与安装指南';

  @override
  String get celebTitle => 'Wavelog v3.2.0';

  @override
  String get celebSubtitle => '不再需要服务器补丁！';

  @override
  String get celebBody =>
      '现在所有功能均可直接通过 Wavelog 官方 API v2 使用，你可以移除之前上传到服务器的旧补丁。\n\n本应用现在需要 Wavelog v3.2.0 或更高版本。';

  @override
  String get celebCreateToken => '创建 API 令牌';

  @override
  String get celebSkip => '跳过';

  @override
  String get celebScopesTitle => 'API v2 令牌权限域';

  @override
  String get celebScopesBody =>
      '在 Wavelog 界面中依次进入 个人资料 → API 令牌 → 新建令牌 创建新令牌时，请勾选以下权限域：';

  @override
  String get celebDone => '知道了';

  @override
  String get scopeQsoRead => '读取 QSO 记录';

  @override
  String get scopeQsoWrite => '添加 / 更新 QSO';

  @override
  String get scopeQsoDelete => '删除 QSO';

  @override
  String get scopeStationRead => '读取电台配置';

  @override
  String get scopeStationWrite => '创建 / 更新电台';

  @override
  String get scopeStationDelete => '删除电台';

  @override
  String get scopeLogbookRead => '读取通联日志';

  @override
  String get scopeLogbookWrite => '创建 / 更新通联日志';

  @override
  String get scopeLogbookDelete => '删除通联日志';

  @override
  String get scopeContestRead => '读取竞赛场次';

  @override
  String get scopeContestWrite => '创建 / 更新竞赛场次';

  @override
  String get scopeContestDelete => '删除竞赛场次';

  @override
  String get scopeCatalogRead => 'DXCC、行政区划与竞赛列表';

  @override
  String get scopeLookupRead => '呼号查询';

  @override
  String get scopeStatisticsRead => '读取统计数据';

  @override
  String get scopeConfirmationRead => '读取 LoTW / eQSL / QRZ.com 确认信息';

  @override
  String get scopeTestStation => '电台';

  @override
  String get scopeTestLogbook => '通联日志';

  @override
  String get scopeTestQso => 'QSO';

  @override
  String get scopeTestContest => '竞赛';

  @override
  String get scopeTestConfirmation => '确认信息';

  @override
  String get scopeTestStatistics => '统计';

  @override
  String get scopeTestLookup => '查询';

  @override
  String get scopeRadioWrite => '上报 CAT 电台的频率和模式';

  @override
  String get scopeTestRadio => '电台';

  @override
  String get apiScopeGuideBtn => 'API 权限域指南';

  @override
  String get apiScopeGuideTitle => 'API 令牌权限域指南';

  @override
  String get apiScopeGuideIntro =>
      '在 Wavelog（设置 → API 令牌）中创建新 API 令牌时，请勾选以下全部权限域以启用应用的完整功能。';

  @override
  String get apiTokenNoticeTitle => '创建新的 API 令牌';

  @override
  String get apiTokenNoticeBody =>
      'Wavelog v2 API 需要具有特定权限域的新令牌。请前往 Wavelog → 设置 → API 令牌，创建包含全部所需权限域的新令牌。点击下方的「API 权限域指南」按钮查看完整列表。';

  @override
  String get apiTokenNoticeDontShow => '不再显示';

  @override
  String get apiTokenNoticeIgnore => '忽略';

  @override
  String get apiTokenNoticeScopeGuide => 'API 权限域指南';

  @override
  String get communitySignInTitle => '验证你的呼号';

  @override
  String get communitySignInSubtitle =>
      '使用 Google 登录，将你的 Google 账号与呼号关联，以确保只有你能以该呼号发布内容。';

  @override
  String get communitySignInButton => '使用 Google 登录';

  @override
  String get communitySignInNoStation => '使用社区功能前，请先在设置中选择当前电台。';

  @override
  String get communityCallsignTaken => '该呼号已关联到其他 Google 账号。';

  @override
  String get communitySignOut => '退出并切换账号';

  @override
  String get syncTitle => '离线同步';

  @override
  String get syncStatusOnline => '在线';

  @override
  String get syncStatusOffline => '无网络连接';

  @override
  String get syncOfflineModeNote => '离线模式已开启，自动同步已暂停，仍可手动同步。';

  @override
  String get syncAllDone => '全部已同步';

  @override
  String syncRunning(int done, int total) {
    return '正在同步… $done / $total';
  }

  @override
  String get syncWaiting => '等待同步';

  @override
  String get syncWaitingDeletes => '等待删除';

  @override
  String get syncLastRun => '上次尝试';

  @override
  String get syncLastSuccess => '上次完整同步';

  @override
  String get syncNever => '从未';

  @override
  String get syncSyncedLast => '上次已发送';

  @override
  String get syncFailedLast => '上次失败';

  @override
  String get syncLastError => '最近错误';

  @override
  String get syncQueueTitle => '待同步 QSO';

  @override
  String get syncQueueEmpty => '没有待同步的 QSO';

  @override
  String get syncNoConnection => '无网络连接 — 恢复联网后会自动开始同步';

  @override
  String syncDone(int count) {
    return '已同步 $count 条 QSO';
  }

  @override
  String get syncNothing => '无需同步';

  @override
  String get openAddQsoOnStart => '启动即打开添加 QSO';

  @override
  String get openAddQsoOnStartHint => '应用启动后直接打开 QSO 表单；返回键回到首页';

  @override
  String get rigSection => '电台（CAT）';

  @override
  String get rigScreenTitle => '电台连接（CAT）';

  @override
  String get rigTileSubtitle => '通过 USB 线连接的电台实时读取频率';

  @override
  String get rigProtocolLabel => '协议';

  @override
  String get rigProtocolIcom => 'Icom CI-V';

  @override
  String get rigProtocolXiegu => '协谷 G90（CI-V）';

  @override
  String get rigProtocolKenwood => '建伍 / Elecraft / 八重洲（FA;）';

  @override
  String get rigProtocolYaesuLegacy => '八重洲 FT-817/818/857/897';

  @override
  String get rigBaudLabel => '波特率';

  @override
  String get rigCivAddressLabel => 'CI-V 地址';

  @override
  String get rigCivAddressHint =>
      '例如 94 对应 IC-7300，A4 对应 IC-705，98 对应 IC-7610，88 对应协谷 G90';

  @override
  String get rigAutoConnect => '自动连接';

  @override
  String get rigAutoConnectHint =>
      '电台 USB 线插入时，或应用启动时已插入。在 Android 弹窗中勾选“始终”可跳过下次询问。';

  @override
  String get rigDevicesLabel => 'USB 设备';

  @override
  String get rigNoDevices => '未找到 USB 串口设备。请使用 USB OTG 线连接电台。';

  @override
  String get rigRefresh => '刷新';

  @override
  String get rigConnect => '连接';

  @override
  String get rigDisconnect => '断开';

  @override
  String rigStatusConnected(String device) {
    return '已连接：$device';
  }

  @override
  String get rigStatusConnecting => '正在连接…';

  @override
  String get rigStatusDisconnected => '未连接';

  @override
  String get rigWaitingForData => '正在等待电台响应…请检查协议、波特率和 CI-V 地址。';

  @override
  String get rigErrorPermission => 'USB 权限被拒绝';

  @override
  String get rigErrorDetached => '电台已断开';

  @override
  String rigErrorConnection(String code) {
    return '连接错误（$code）';
  }

  @override
  String get workedNewCountry => '新国家';

  @override
  String workedNewBand(String band) {
    return '新波段（$band）';
  }

  @override
  String workedNewMode(String mode) {
    return '新模式（$mode）';
  }

  @override
  String workedDupe(String band, String mode) {
    return '重复：今天已在 $band $mode 通联过';
  }

  @override
  String get stationWebOnlySettingsHint =>
      'QRZ.com、HRDLog.net、QO-100（webADIF）、OQRS 以及 eQSL 默认留言需在 Wavelog 网页端设置，API 未向应用开放这些项。';

  @override
  String get qsoReferencesSection => 'POTA / SOTA / WWFF';

  @override
  String get potaRefHint => 'US-1234，可用回车或逗号添加多个';

  @override
  String get potaUnknownParkTitle => '未知公园';

  @override
  String potaUnknownParkBody(String refs) {
    return 'pota.app 中没有公园 $refs。仍要保存该 QSO？';
  }

  @override
  String get spotNewPark => '新公园';

  @override
  String potaActivationProgress(String park, int count, int needed) {
    return '$park：今日（UTC）已通联 $count/$needed 条 QSO';
  }

  @override
  String potaActivationDone(String park, int count) {
    return '$park：已激活（今日 $count 条 QSO）';
  }

  @override
  String get keepScreenOnWhileLogging => '记录时保持屏幕常亮';

  @override
  String get keepScreenOnWhileLoggingHint => '添加 QSO 或竞赛记录打开时屏幕保持常亮';

  @override
  String contestDupe(String band, String time) {
    return '重复：本次竞赛已在 $band（$time UTC）通联过';
  }

  @override
  String contestWorkedOn(String bands) {
    return '本次竞赛已通联的波段：$bands';
  }

  @override
  String get mapLayers => '地图图层';

  @override
  String get mapBaseAuto => '自动（浅色 / 深色）';

  @override
  String get mapBaseLight => '浅色';

  @override
  String get mapBaseDark => '深色';

  @override
  String get mapBaseTopo => '地形图';

  @override
  String get mapGreatCircles => '从我电台出发的大圆航线';

  @override
  String get mapGreyline => '灰线';

  @override
  String get mapGreylineHint => '当前夜半球与昼夜分界线';

  @override
  String get mapNorthUp => '北在上';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appTitle => 'Wavelog 移动端';

  @override
  String get splashConnecting => '正在连接';

  @override
  String get navHome => '首页';

  @override
  String get navLogbook => '通联日志';

  @override
  String get navLookup => '查询';

  @override
  String get navStation => '电台';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get refresh => '刷新';

  @override
  String get continueBtn => '继续';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get loading => '加载中…';

  @override
  String get error => '错误';

  @override
  String get success => '成功';

  @override
  String get change => '修改';

  @override
  String get goWeb => '前往 →';

  @override
  String get editOnWeb => '网页端编辑';

  @override
  String get openInBrowser => '在浏览器打开';

  @override
  String get serverSetupTitle => '服务器设置';

  @override
  String get serverSetupSubtitle => '配置你的 Wavelog 服务器';

  @override
  String get serverUrlLabel => 'Wavelog 服务器地址';

  @override
  String get serverUrlHint => 'https://log.example.com';

  @override
  String get testConnection => '测试连接';

  @override
  String get testingConnection => '正在测试…';

  @override
  String get sslIssueTitle => 'SSL 证书异常';

  @override
  String get sslIssueBody =>
      '无法验证该服务器 SSL 证书，可能是自签名证书或证书已过期。是否继续并跳过验证？（仅建议在你信任的服务器上使用）';

  @override
  String get sslIssueAllow => '跳过验证继续';

  @override
  String get scopeTestSectionTitle => '权限域检测';

  @override
  String get scopeTestRunning => '正在检测权限…';

  @override
  String get scopeTestAllPassed => '所需全部权限域已配置';

  @override
  String get scopeTestSomeFailed => '缺少部分权限域';

  @override
  String get scopeTestAddHint => '创建 API 令牌时添加该权限域';

  @override
  String get qsoSyncBigTitle => '哇，通联记录数量非常多！';

  @override
  String get qsoSyncBigBody => '正在同步你的通联记录，可能需要一两分钟。';

  @override
  String get qsoSyncSection => '通联记录同步';

  @override
  String get qsoSyncResetBtn => '重置同步';

  @override
  String get qsoSyncResetHint => '适用于修改通联记录或同步异常时';

  @override
  String get qsoSyncResetStarted => '后台已重新启动同步';

  @override
  String get qsoSyncIntervalLabel => '检查间隔';

  @override
  String get qsoSyncIntervalHint => '后台重新检查 QSO 内容的频率';

  @override
  String get connectionSuccess => '连接成功！';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get apiKeyCopied => 'API 密钥已复制';

  @override
  String get loginTitle => '登录';

  @override
  String get serverBtn => '服务器';

  @override
  String get addAccountBtn => '添加账号';

  @override
  String get signInBtn => '登录';

  @override
  String get deleteProfile => '删除';

  @override
  String get deleteProfileTitle => '删除账号';

  @override
  String deleteProfileConfirm(String name) {
    return '从本设备移除 $name？';
  }

  @override
  String get displayName => '显示名称';

  @override
  String get callsign => '呼号';

  @override
  String get apiKeyLabel => 'API 密钥';

  @override
  String get validating => '正在验证…';

  @override
  String get profileSaved => '账号已保存';

  @override
  String get loginFailed => '登录失败';

  @override
  String get noStationFound => '未找到匹配的电台，将使用呼号';

  @override
  String get homeTitle => '首页';

  @override
  String get addQso => '添加 QSO';

  @override
  String get recentQsos => '最近 QSO';

  @override
  String get statsToday => '今天';

  @override
  String get statsMonth => '本月';

  @override
  String get statsYear => '本年';

  @override
  String get statsTotal => '总计';

  @override
  String get noRecentQsos => '暂无 QSO';

  @override
  String get syncNow => '立即同步';

  @override
  String pendingSync(int count) {
    return '$count 条 QSO 待同步';
  }

  @override
  String get offlineBanner => '离线 — QSO 已保存在本地';

  @override
  String get activeStation => '当前电台';

  @override
  String get logbookTitle => '通联日志';

  @override
  String get filterAll => '全部';

  @override
  String get filterAllModes => '全部模式';

  @override
  String get searchHint => '搜索呼号…';

  @override
  String get noQsos => '未找到 QSO';

  @override
  String get qsoDetailTitle => 'QSO 详情';

  @override
  String get qsoNotFound => '未找到该 QSO';

  @override
  String get signal => '信号';

  @override
  String get rstSent => '发送 RST';

  @override
  String get rstReceived => '接收 RST';

  @override
  String get txPower => '发射功率';

  @override
  String get counterStation => '对方电台';

  @override
  String get country => '国家';

  @override
  String get continent => '大洲';

  @override
  String get dxcc => 'DXCC';

  @override
  String get cqZone => 'CQ 分区';

  @override
  String get ituZone => 'ITU 分区';

  @override
  String get gridSquare => '网格';

  @override
  String get propMode => '传播方式';

  @override
  String get distance => '距离';

  @override
  String get qslStatus => 'QSL 状态';

  @override
  String get paperQsl => '纸质';

  @override
  String get lotwQsl => 'LoTW';

  @override
  String get eqslQsl => 'eQSL';

  @override
  String get qrzQsl => 'QRZ.com';

  @override
  String get clublog => 'Club Log';

  @override
  String get hrdlog => 'HRDLog';

  @override
  String get qslSent => '已发送';

  @override
  String get qslRcvd => '已收到';

  @override
  String get qslReceived => '已收到';

  @override
  String get qslMethod => '方式';

  @override
  String get awards => '奖状编号';

  @override
  String get iota => 'IOTA';

  @override
  String get sota => 'SOTA';

  @override
  String get wwff => 'WWFF';

  @override
  String get pota => 'POTA';

  @override
  String get myStation => '我的电台';

  @override
  String get myCallsign => '我的呼号';

  @override
  String get contest => '竞赛';

  @override
  String get serialSent => '发送序号';

  @override
  String get serialReceived => '接收序号';

  @override
  String get solarConditions => '太阳活动状况';

  @override
  String get aIndex => 'A 指数';

  @override
  String get kIndex => 'K 指数';

  @override
  String get sfi => 'SFI';

  @override
  String get notesSection => '备注';

  @override
  String get rawAdif => '原始 ADIF';

  @override
  String get showAll => '显示全部';

  @override
  String get showLess => '收起';

  @override
  String get qrzProfile => 'QRZ 资料';

  @override
  String get addQsoTitle => '添加 QSO';

  @override
  String get liveQso => '实时 QSO';

  @override
  String get historicalQso => '补记 QSO';

  @override
  String get callsignField => '呼号 *';

  @override
  String get lookupSearch => 'QRZ 查询';

  @override
  String get liveDateTimeLabel => '日期/时间（UTC）— 实时';

  @override
  String get dateTimeLabel => '日期/时间（UTC）';

  @override
  String get bandField => '波段 *';

  @override
  String get modeField => '模式 *';

  @override
  String get frequencyField => '频率（MHz）';

  @override
  String get rstSentField => '发送 RST *';

  @override
  String get rstRcvdField => '接收 RST *';

  @override
  String get nameField => '姓名';

  @override
  String get qthField => 'QTH';

  @override
  String get gridField => '网格';

  @override
  String get commentField => '备注';

  @override
  String get stationProfileField => '电台配置';

  @override
  String get saveQsoBtn => '保存 QSO';

  @override
  String qsoSaved(String callsign) {
    return '✓  $callsign 已保存';
  }

  @override
  String qsoSavedLocal(String callsign) {
    return '✓  $callsign 已保存到本地';
  }

  @override
  String get noActiveStation => '未选择当前电台';

  @override
  String get lookupTitle => '呼号查询';

  @override
  String get lookupHint => '输入呼号…';

  @override
  String get lookupBtn => '搜索';

  @override
  String get recentSearches => '最近搜索';

  @override
  String get clearHistory => '清空历史';

  @override
  String get makeQso => '记录 QSO';

  @override
  String get notFound => '未找到';

  @override
  String get stationsTitle => '电台';

  @override
  String stationActivated(String callsign) {
    return '已将 $callsign 设为当前电台';
  }

  @override
  String get stationWebInfo => '请通过 Wavelog 网页端添加和编辑电台。';

  @override
  String get noStations => '暂无电台';

  @override
  String get noStationsHint => '请通过 Wavelog 网页端添加电台。';

  @override
  String get addStationOnWeb => '在 Wavelog 上添加电台';

  @override
  String get adifTitle => 'ADIF 导入 / 导出';

  @override
  String get importTab => '导入';

  @override
  String get exportTab => '导出';

  @override
  String get selectAdifFile => '选择 ADIF 文件';

  @override
  String get selectFileBtn => '选择文件（.adi / .adif）';

  @override
  String get stationRequired => '电台配置 *';

  @override
  String importing(int done, int total) {
    return '正在导入… $done/$total';
  }

  @override
  String get importBtn => '导入';

  @override
  String get fileReadError => '无法读取文件内容，请重试';

  @override
  String get invalidFileExtension => '请选择 .adi 或 .adif 扩展名的文件';

  @override
  String get exportFilters => '导出筛选';

  @override
  String get stationFilter => '电台';

  @override
  String get allStations => '全部电台';

  @override
  String get startDate => '开始';

  @override
  String get endDate => '结束';

  @override
  String get notSelected => '未选择';

  @override
  String get clearDates => '清除日期';

  @override
  String get exporting => '正在导出…';

  @override
  String get exportAndShare => '导出并分享';

  @override
  String get copyPath => '复制路径';

  @override
  String get reshare => '再次分享';

  @override
  String get pathCopied => '文件路径已复制';

  @override
  String qsoExported(int count) {
    return '已导出 $count 条 QSO';
  }

  @override
  String get noStationForExport => '未找到可导出的电台';

  @override
  String qsoImported(int imported, int total) {
    return '已导入 $imported / $total 条 QSO';
  }

  @override
  String get selectSaveLocation => '选择保存位置';

  @override
  String get copySuffix => '（副本）';

  @override
  String get errNetwork => '无网络连接 — 请检查网络';

  @override
  String get errTimeout => '连接超时';

  @override
  String get errLocalNetworkPermission => '需要本地网络权限，请在 Android 设置中为本应用开启';

  @override
  String get errUnauthorized => 'API 密钥无效';

  @override
  String get settingsTitle => '设置';

  @override
  String get connectionSection => '连接';

  @override
  String get sessionSection => '会话';

  @override
  String get loggedIn => '已登录';

  @override
  String get logoutBtn => '退出登录';

  @override
  String get logoutTitle => '退出登录';

  @override
  String get logoutConfirm => '确定要退出登录吗？';

  @override
  String get switchAccountBtn => '切换账号';

  @override
  String get activeStationSection => '当前电台';

  @override
  String get selectStationBtn => '选择电台';

  @override
  String get addStationWeb => '在网页端添加电台';

  @override
  String get defaultsSection => '默认值';

  @override
  String get defaultBand => '默认波段';

  @override
  String get defaultMode => '默认模式';

  @override
  String get appSection => '应用';

  @override
  String get darkTheme => '深色主题';

  @override
  String get darkThemeHint => '户外使用推荐';

  @override
  String get offlineMode => '离线模式';

  @override
  String get offlineModeHint => '先将 QSO 保存到本地，之后再同步';

  @override
  String get allowInsecureSsl => '允许未验证的 SSL 证书';

  @override
  String get allowInsecureSslHint => '信任自签名或私有 CA 证书（适用于自建服务器）。不建议在公共网络上使用。';

  @override
  String get languageLabel => '语言';

  @override
  String get infoSection => '信息';

  @override
  String get aboutAppBtn => '关于';

  @override
  String get aboutAppHint => '版本、开发者、许可协议';

  @override
  String get dataSection => '数据';

  @override
  String get clearCacheBtn => '清除 QSO 缓存';

  @override
  String get clearCacheHint => '删除本地 QSO 缓存';

  @override
  String get clearCacheTitle => '清除缓存';

  @override
  String get clearCacheConfirm => '本地 QSO 缓存将被删除，此操作无法撤销。';

  @override
  String get clearCacheAction => '清除';

  @override
  String get cacheCleared => '缓存已清除';

  @override
  String get langSystem => '跟随系统';

  @override
  String get langEnglish => 'English';

  @override
  String get langTurkish => 'Türkçe';

  @override
  String get langPolish => 'Polski';

  @override
  String get langGerman => 'Deutsch';

  @override
  String get langFrench => 'Français';

  @override
  String get langItalian => 'Italiano';

  @override
  String get langJapanese => '日本語';

  @override
  String get langKorean => '한국어';

  @override
  String get langRussian => 'Русский';

  @override
  String get langChinese => '简体中文';

  @override
  String get aboutTitle => '关于';

  @override
  String get appDescription => '面向 Wavelog 的开源 Android 日志应用';

  @override
  String versionLabel(String version, String build) {
    return '版本 $version（构建 $build）';
  }

  @override
  String get mobileDeveloperSection => '移动端应用开发者';

  @override
  String get wavelogProjectSection => 'Wavelog 项目';

  @override
  String get wavelogDescription => '基于网页的业余无线电日志系统';

  @override
  String get coreDevelopers => '核心开发者';

  @override
  String get mitLicense => 'MIT 许可证';

  @override
  String get mitDescription => '本应用与 Wavelog 项目均以 MIT 许可证发布。开源软件，不提供任何担保。';

  @override
  String get licenseSection => '许可证';

  @override
  String get dxccDataSection => 'DXCC 数据';

  @override
  String get dxccDataDescription =>
      'DXCC 实体与呼号前缀数据 © 1994– Jim Reisert, AD1C（country-files.com），依据 MIT 许可证使用。';

  @override
  String get errorNoConnection => '无网络连接';

  @override
  String get errorUnauthorized => '未授权 — 请检查 API 密钥';

  @override
  String get errorServer => '服务器错误';

  @override
  String get patchRequiredTitle => '需要安装服务器补丁';

  @override
  String get patchRequiredMessage =>
      '编辑与删除功能需要先在服务器上安装 Wavelog Mobile API 补丁。\n\n安装说明请访问 sp9aqg.pl/install.html。';

  @override
  String get patchRequiredBanner => '编辑与删除功能需要先在服务器上安装 Wavelog Mobile API 补丁。';

  @override
  String get patchViewGuide => '查看指南';

  @override
  String get setupGuideTitle => '设置指南';

  @override
  String get setupGuideIntro => '记录 QSO 之前，请先将应用连接到你的 Wavelog 服务器，按以下步骤操作。';

  @override
  String get setupGuideStep1Title => '1. 服务器地址';

  @override
  String get setupGuideStep1Body =>
      '填写你在浏览器中打开 Wavelog 所用的地址，例如 https://yourdomain.com，末尾不要带斜杠。';

  @override
  String get setupGuideStep2Title => '2. API v2 令牌';

  @override
  String get setupGuideStep2Body =>
      '在 Wavelog 中依次进入 设置 → API → API 令牌（v2）→ 新建令牌，勾选应用所需的权限域（粘贴令牌后应用会自动检测）。复制生成的令牌（以 wl2_ 开头）并粘贴到应用中。';

  @override
  String get setupGuideStep3Title => '3. 呼号与显示名称';

  @override
  String get setupGuideStep3Body =>
      '呼号：你自己的业余无线电呼号，用于匹配你的电台。显示名称：任意名称，便于在本设备上识别该登录。';

  @override
  String get setupGuideContinueBtn => '开始设置';

  @override
  String get migrationTokenHint => 'wl2_…';

  @override
  String get migrationTokenLabel => 'API v2 令牌';

  @override
  String get migrationValidateBtn => '验证并继续';

  @override
  String get migrationValidating => '正在验证…';

  @override
  String get migrationTokenEmpty => '请粘贴你的 wl2_ 令牌。';

  @override
  String get migrationTokenInvalid => '令牌无效 — 请检查后重试。';

  @override
  String get patchNotInstalledTitle => '未检测到补丁';

  @override
  String get patchNotInstalledBody =>
      '服务器上似乎未安装 Wavelog Mobile 补丁。\n\n没有该补丁，API v2 令牌（wl2_…）无法使用。请先完成第 1 步。';

  @override
  String get patchInstallFirst => '安装补丁';

  @override
  String get appSubtitle => '业余无线电日志应用';

  @override
  String get switchToLightTheme => '切换到浅色主题';

  @override
  String get switchToDarkTheme => '切换到深色主题';

  @override
  String get deleteQsoTitle => '删除 QSO';

  @override
  String deleteQsoConfirm(String callsign, String date) {
    return '永久删除 $date 与 $callsign 的 QSO？';
  }

  @override
  String get editTooltip => '编辑';

  @override
  String get shareAdifTooltip => '分享 ADIF';

  @override
  String get localNotSynced => '本地记录 — 尚未同步';

  @override
  String get satellite => '卫星';

  @override
  String get satelliteMode => '卫星模式';

  @override
  String get antenna => '天线';

  @override
  String get nameLabel => '姓名';

  @override
  String get stateProvince => '省/州';

  @override
  String get county => '县';

  @override
  String get city => '城市';

  @override
  String get continentAF => '非洲';

  @override
  String get continentAN => '南极洲';

  @override
  String get continentAS => '亚洲';

  @override
  String get continentEU => '欧洲';

  @override
  String get continentNA => '北美洲';

  @override
  String get continentOC => '大洋洲';

  @override
  String get continentSA => '南美洲';

  @override
  String get qrzProfileLoading => '正在加载 QRZ 资料…';

  @override
  String viewOnQrz(String callsign) {
    return '在 QRZ.com 查看（$callsign）';
  }

  @override
  String get qslMethods => 'QSL 方式';

  @override
  String get bureau => '卡片局';

  @override
  String qslManagerPrefix(String manager) {
    return '管理者：$manager';
  }

  @override
  String get callsignCopied => '呼号已复制';

  @override
  String get uploadedStatus => '已上传';

  @override
  String get notUploadedStatus => '未上传';

  @override
  String get matchedStatus => '已匹配';

  @override
  String get toDeleteStatus => '待删除';

  @override
  String get yes => '是';

  @override
  String get requested => '已申请';

  @override
  String get no => '否';

  @override
  String get invalid => '无效';

  @override
  String get viaDirect => '直邮';

  @override
  String get viaElectronic => '电子方式';

  @override
  String get viaMail => '邮寄';

  @override
  String otherAdifFields(int count) {
    return '其他 ADIF 字段（$count）';
  }

  @override
  String get editQsoTitle => '编辑 QSO';

  @override
  String get qsoUpdated => 'QSO 已更新';

  @override
  String get qsoUpdatedLocal => 'QSO 已在本地更新';

  @override
  String get counterStationHint => '输入呼号后，QRZ\n资料和历史 QSO\n将显示在这里。';

  @override
  String previousQsosCount(int count) {
    return '历史 QSO（$count）';
  }

  @override
  String morePreviousQsos(int count) {
    return '+$count 更多…';
  }

  @override
  String previousQsosWithCallsign(String callsign) {
    return '与 $callsign 的历史 QSO';
  }

  @override
  String totalQsos(int count) {
    return '共 $count 条';
  }

  @override
  String get workedBefore => '曾通联过';

  @override
  String get lastQsoLabel => '上次 QSO';

  @override
  String get themeLabel => '主题';

  @override
  String get darkThemeActive => '深色主题已启用';

  @override
  String get lightThemeActive => '浅色主题已启用';

  @override
  String get lightThemeLabel => '浅色';

  @override
  String get darkThemeLabel => '深色';

  @override
  String get commentNotes => '备注 / 说明';

  @override
  String get commentLabel => '备注';

  @override
  String get exchangeReceived => '接收交换信息';

  @override
  String get exchangeSent => '发送交换信息';

  @override
  String get contestIdLabel => '竞赛';

  @override
  String get sigLabel => 'SIG';

  @override
  String get stationSetup => '电台设置';

  @override
  String get logbooks => '通联日志';

  @override
  String get locations => '地点';

  @override
  String get newLogbook => '新建通联日志';

  @override
  String get logbookName => '日志名称';

  @override
  String get renameLogbook => '重命名';

  @override
  String get deleteLogbook => '删除通联日志';

  @override
  String get editStation => '编辑';

  @override
  String get cloneStation => '克隆';

  @override
  String get deleteStation => '删除';

  @override
  String get deleteStationConfirm => '删除电台';

  @override
  String get deleteStationWarning => '该电台的所有 QSO 将被永久删除。是否继续？';

  @override
  String get stationDeleted => '电台已删除';

  @override
  String get stationUpdated => '电台已更新';

  @override
  String get stationCloned => '电台已克隆';

  @override
  String get linkLocation => '关联地点';

  @override
  String get unlinkLocation => '取消关联';

  @override
  String get linkedLocations => '已关联地点';

  @override
  String get newStationName => '新电台名称';

  @override
  String get deleteLogbookConfirm => '删除通联日志';

  @override
  String get deleteLogbookWarning => '该通联日志将被删除，已关联的地点会保留。是否继续？';

  @override
  String get logbookDeleted => '通联日志已删除';

  @override
  String get hrdlogCode => 'HRDLog 代码';

  @override
  String get webAdifApiKey => 'WebADIF API 密钥';

  @override
  String get webAdifApiUrl => 'WebADIF API 地址';

  @override
  String get basicInfo => '基本信息';

  @override
  String get locationSectionTitle => '位置';

  @override
  String get awardReferences => '奖状编号';

  @override
  String get integrationsSectionTitle => '第三方集成';

  @override
  String get stationSettingsSection => '电台设置';

  @override
  String get editStationTitle => '编辑电台';

  @override
  String get newStationTitle => '新建电台';

  @override
  String get saveChangesBtn => '保存修改';

  @override
  String get createStationBtn => '创建电台';

  @override
  String get stationCreated => '电台已创建';

  @override
  String get stationCreateFailed => '失败，同名配置可能已存在。';

  @override
  String get stationProfileNameLabel => '电台配置名称 *';

  @override
  String get stationProfileNameHint => '家庭电台';

  @override
  String get cityQth => '城市 / QTH';

  @override
  String get powerWatts => '功率（W）';

  @override
  String get dxccCountry => 'DXCC / 国家';

  @override
  String get selectLabel => '请选择…';

  @override
  String get dxccSearch => '搜索 DXCC / 国家';

  @override
  String get deletedDxcc => '已删除的 DXCC';

  @override
  String get eqslQthNicknameLabel => 'eQSL QTH 昵称';

  @override
  String get eqslDefaultMsgLabel => 'eQSL 默认留言';

  @override
  String get pending => '待处理';

  @override
  String get uploadDisabled => '已禁用';

  @override
  String get uploadEnabled => '已启用';

  @override
  String get uploadRealtime => '实时';

  @override
  String get qrzApiKeyLabel => 'QRZ.com 日志 API 密钥';

  @override
  String get qrzUploadLabel => 'QRZ.com 上传';

  @override
  String get clublogIgnoreTitle => '忽略 Clublog';

  @override
  String get clublogIgnoreSubtitle => '该电台不再上传至 Clublog';

  @override
  String get clublogRealtimeTitle => 'Clublog 实时上传';

  @override
  String get clublogRealtimeSubtitle => '实时将 QSO 上传至 Clublog';

  @override
  String get hrdlogUsernameLabel => 'HRDLog.net 用户名';

  @override
  String get hrdlogApiKeyLabel => 'HRDLog.net API 密钥';

  @override
  String get hrdlogUploadLabel => 'HRDLog.net 上传';

  @override
  String get qo100ApiKeyLabel => 'QO-100 DX Club API 密钥';

  @override
  String get qo100RealtimeTitle => 'QO-100 DX Club 实时上传';

  @override
  String get qo100RealtimeSubtitle => '实时将 QSO 上传至 QO-100 DX Club';

  @override
  String get oqrsSectionTitle => 'OQRS（在线 QSL）';

  @override
  String get oqrsEnabledTitle => '启用 OQRS';

  @override
  String get oqrsEnabledSubtitle => '启用在线 QSL 申请系统';

  @override
  String get oqrsTextLabel => 'OQRS 说明文字';

  @override
  String get oqrsEmailLabel => 'OQRS 邮箱';

  @override
  String get setAsActiveStationTitle => '设为当前电台';

  @override
  String get setAsActiveStationSubtitle => '在 Wavelog 中将该电台标记为当前电台';

  @override
  String get linkToActiveLogbookTitle => '关联到当前日志';

  @override
  String get linkToActiveLogbookSubtitle => '创建时自动关联到当前通联日志';

  @override
  String get active => '当前';

  @override
  String get loadDetailsFailed => '加载详情失败';

  @override
  String get cannotDeleteActiveStation => '无法删除当前电台。';

  @override
  String get navStats => '统计';

  @override
  String get statisticsTitle => '统计';

  @override
  String get uniqueCallsigns => '不同呼号数';

  @override
  String get currentStreak => '当前连续天数';

  @override
  String streakDays(int count) {
    return '$count 天';
  }

  @override
  String get bandDistribution => '波段分布';

  @override
  String get modeDistribution => '模式分布';

  @override
  String get perStation => '按电台';

  @override
  String get basedOnCache => '波段 / 模式 / 电台统计基于缓存的 QSO。';

  @override
  String get statsTab => '统计';

  @override
  String get propagationTab => '传播';

  @override
  String get bandConditions => '波段状况';

  @override
  String get dayTime => '白天';

  @override
  String get nightTime => '夜间';

  @override
  String get conditionGood => '良好';

  @override
  String get conditionFair => '一般';

  @override
  String get conditionPoor => '较差';

  @override
  String lastUpdated(String time) {
    return '更新于：$time';
  }

  @override
  String get noSolarData => '无法加载太阳活动数据';

  @override
  String get potaStats => 'POTA 统计';

  @override
  String get potaTotalQsos => 'POTA QSO';

  @override
  String get potaActivatedParks => '已激活公园';

  @override
  String get potaAllParks => '全部公园';

  @override
  String get potaActivatedBadge => '已激活';

  @override
  String get potaAttemptBadge => '尝试';

  @override
  String get potaNoStation => '未配置 POTA 电台';

  @override
  String get potaNoQsos => '缓存中没有 POTA QSO';

  @override
  String get navSpot => '通告';

  @override
  String get spotTitle => '通告';

  @override
  String get spotAdd => '发布通告';

  @override
  String get spotSend => '发送通告';

  @override
  String get spotSent => '通告已发送！';

  @override
  String get spotNoResults => '未找到通告';

  @override
  String get spotLoadError => '无法加载通告';

  @override
  String get spotActivator => '激活者呼号';

  @override
  String get spotSpotter => '发布者呼号';

  @override
  String get spotFrequency => '频率（kHz）';

  @override
  String get spotReference => '公园编号';

  @override
  String get spotComments => '评论';

  @override
  String get spotCommentsHint => 'QRZ、CQ POTA…';

  @override
  String get spotInvalidRef => '格式无效（例如 PL-0001）';

  @override
  String get sortNewest => '最新在前';

  @override
  String get sortOldest => '最早在前';

  @override
  String get filterBand => '波段';

  @override
  String get filterMode => '模式';

  @override
  String get filterCountry => '国家';

  @override
  String get filterAssociation => '协会';

  @override
  String get spotAddComingSoon => '发布通告 — 即将推出';

  @override
  String get filterClear => '清除筛选';

  @override
  String get mode => '模式';

  @override
  String get required => '必填';

  @override
  String get invalidNumber => '数字无效';

  @override
  String get potaAutoSpot => '自动通告';

  @override
  String get potaAutoSpotHint => '在 POTA 或 SOTA 电台记录 QSO 时自动发布自身通告（各 30 分钟冷却）';

  @override
  String get spotRefreshLabel => '通告刷新间隔';

  @override
  String get spotRefreshHint => '按此间隔自动刷新通告列表';

  @override
  String autoSpotSent(String ref) {
    return '自动通告已发送：$ref';
  }

  @override
  String get autoSpotWillFire => '该 QSO 将触发通告';

  @override
  String autoSpotCooldown(int min) {
    return '通告已发送 · $min 分钟后可再次发送';
  }

  @override
  String get autoSpotCooldownSoon => '通告已发送 · 即将可再次发送';

  @override
  String autoSpotKeyChanged(String fields) {
    return '$fields 已变更 · 将触发新通告';
  }

  @override
  String get autoSpotFieldFreq => '频率';

  @override
  String get autoSpotFieldMode => '模式';

  @override
  String get autoSpotFieldRef => '公园';

  @override
  String get logbookSummaryTitle => '最近 QSO';

  @override
  String todayQsoCount(int count) {
    return '今天：$count 条 QSO';
  }

  @override
  String get colDateTime => '日期/时间';

  @override
  String get colRstSent => 'RST(发)';

  @override
  String get colRstRcvd => 'RST(收)';

  @override
  String get submodeLabel => '子模式';

  @override
  String selectedCount(int count) {
    return '已选 $count 条';
  }

  @override
  String get selectAll => '全选';

  @override
  String get exportSelected => '导出';

  @override
  String get deleteSelected => '删除';

  @override
  String deleteSelectedConfirm(int count) {
    return '删除 $count 条 QSO？';
  }

  @override
  String get mapTitle => '地图';

  @override
  String get mapNoData => '未找到含网格信息的 QSO';

  @override
  String mapStationCount(int count) {
    return '$count 个电台';
  }

  @override
  String get dxccProgress => 'DXCC 进度';

  @override
  String get workedCountries => '已通联国家';

  @override
  String get dxccWorked => '已通联';

  @override
  String dxccUniqueEntities(int count) {
    return '$count 个独立实体';
  }

  @override
  String get dxccConfirmed => '已确认（LoTW / eQSL / QSL）';

  @override
  String get dxccRemaining => '剩余';

  @override
  String get dxccLegendConfirmed => '已确认';

  @override
  String get dxccLegendPending => '待确认';

  @override
  String get dxccLegendNotWorked => '未通联';

  @override
  String get spotSummitNotFound => '未找到山峰';

  @override
  String get spotParkNotFound => '未找到公园';

  @override
  String get qsoTypeTitle => '记录 QSO';

  @override
  String get normalQso => '普通 QSO';

  @override
  String get normalQsoDesc => '常规通联记录';

  @override
  String get contestQso => '竞赛 QSO';

  @override
  String get contestQsoDesc => '带交换信息的快速竞赛记录';

  @override
  String get contestLog => '竞赛记录';

  @override
  String get contestSetup => '竞赛设置';

  @override
  String get contestNameHint => '例如 CQ-WW-CW';

  @override
  String get ourExchange => '我方交换信息';

  @override
  String get serialStart => '起始序号';

  @override
  String get showExchangeFields => '交换字段';

  @override
  String get startContest => '开始记录';

  @override
  String get endContest => '结束场次';

  @override
  String get endContestConfirm => '结束本次竞赛场次？（序号计数器和设置将被重置）';

  @override
  String get serialSentLabel => '发序号';

  @override
  String get serialRcvdLabel => '收序号';

  @override
  String get exchangeSentLabel => '发交换';

  @override
  String get exchangeRcvdLabel => '收交换';

  @override
  String get gridSentLabel => '发网格';

  @override
  String get gridRcvdLabel => '收网格';

  @override
  String get logQso => '记录 QSO';

  @override
  String get qsoLogged => 'QSO 已记录';

  @override
  String get contestRecentQsos => '最近';

  @override
  String get contestSessions => '竞赛场次';

  @override
  String get newSession => '新建场次';

  @override
  String get noContestSessions => '暂无竞赛场次';

  @override
  String get noContestSessionsHint => '在网页端创建场次，或点击 + 在此开始。';

  @override
  String get contestSessionActive => '进行中';

  @override
  String get contestSessionEnded => '已结束';

  @override
  String qsoCount(int count) {
    return '$count 条 QSO';
  }

  @override
  String contestSessionDates(String start, String end) {
    return '$start – $end';
  }

  @override
  String get createContestSession => '创建竞赛场次';

  @override
  String get sessionName => '场次名称（可选）';

  @override
  String get sessionNameHint => '例如 家庭电台 — CW';

  @override
  String get selectContest => '选择竞赛 *';

  @override
  String get searchContest => '搜索竞赛…';

  @override
  String get serverContests => '来自服务器';

  @override
  String get builtinContests => '常见竞赛';

  @override
  String get startDateTime => '开始日期/时间 *';

  @override
  String get endDateTime => '结束日期/时间 *';

  @override
  String get durationShortcut4h => '+4h';

  @override
  String get durationShortcut12h => '+12h';

  @override
  String get durationShortcut24h => '+24h';

  @override
  String get durationShortcut48h => '+48h';

  @override
  String get exchangeType => '交换类型';

  @override
  String get exchangeTypeSerial => '序号';

  @override
  String get exchangeTypeExchange => '文本交换';

  @override
  String get exchangeTypeBoth => '序号 + 文本交换';

  @override
  String get createSession => '创建场次';

  @override
  String get sessionCreated => '竞赛场次已创建';

  @override
  String get sessionUpdated => '竞赛场次已更新';

  @override
  String get editContestSession => '编辑竞赛场次';

  @override
  String get saveChanges => '保存修改';

  @override
  String get deleteSession => '删除场次';

  @override
  String get deleteSessionConfirm => '删除该竞赛场次？本次记录的 QSO 将保留在通联日志中。';

  @override
  String get openSession => '开启记录';

  @override
  String get patchRequiredContest => '竞赛场次管理需要安装最新版 Wavelog Mobile 补丁。';

  @override
  String get contestCalendarTitle => '竞赛日历';

  @override
  String get contestCalendarNoContests => '未找到竞赛。';

  @override
  String get contestCalendarToday => '今天';

  @override
  String get contestCalendarThisWeek => '本周';

  @override
  String get contestCalendarUpcoming => '即将开始';

  @override
  String get contestCalendarRecentlyPast => '近期结束';

  @override
  String get contestCalendarLoadError => '无法加载竞赛日历';

  @override
  String get contestCalendarRefresh => '刷新';

  @override
  String get contestCalendarRetry => '重试';

  @override
  String get upcomingContestsTitle => '即将开始的竞赛';

  @override
  String get viewAll => '查看全部';

  @override
  String get noUpcomingContests => '未找到即将开始的竞赛。';

  @override
  String get contestTodayBadge => '今天';

  @override
  String get navStyleLabel => '导航样式';

  @override
  String get navStyleModern => '现代 — 悬浮按钮 + 侧边栏';

  @override
  String get navStyleClassic => '经典 — 6 标签栏';

  @override
  String get drawerMap => '地图';

  @override
  String get drawerContestCalendar => '竞赛日历';

  @override
  String get drawerContestSessions => '竞赛场次';

  @override
  String get drawerAdif => 'ADIF';

  @override
  String get drawerMenu => '菜单';

  @override
  String get antennaCompassTitle => '天线方向';

  @override
  String get targetGrid => '目标网格';

  @override
  String get calculate => '计算';

  @override
  String get shortPath => '短路径';

  @override
  String get longPath => '长路径';

  @override
  String get azimuth => '方位角';

  @override
  String get myHeading => '航向';

  @override
  String get invalidGrid => '网格无效';

  @override
  String get gpsLocating => '正在通过 GPS 定位…请稍候';

  @override
  String get gpsUnavailable => '无法获取 GPS 位置';

  @override
  String get drawerAntenna => '天线方向';

  @override
  String get achievementsTitle => '成就';

  @override
  String get achievementsEmpty => '记录第一个 QSO 即可开始获得徽章！';

  @override
  String get shareAchievement => '分享';

  @override
  String get achievementUnlocked => '成就已解锁！';

  @override
  String progressLabel(int done, int target) {
    return '$done / $target';
  }

  @override
  String get drawerAchievements => '成就';

  @override
  String get drawerCommunity => '社区';

  @override
  String get communityTitle => '社区';

  @override
  String get communityNoActivations => '暂无计划中的激活';

  @override
  String get communityBeFirst => '来第一个发布公告吧！';

  @override
  String get communityAnnounce => '发布激活公告';

  @override
  String get communityFollow => '关注';

  @override
  String get communityUnfollow => '取消关注';

  @override
  String communityFollowers(int count) {
    return '$count 位关注者';
  }

  @override
  String get communityTypeGeneral => '综合';

  @override
  String get communityCallsign => '呼号';

  @override
  String get communityReference => '编号';

  @override
  String get communitySotaRef => 'SOTA 编号（TA/AN-001）';

  @override
  String get communityPotaRef => 'POTA 编号（TA-0001）';

  @override
  String get communityScheduledTime => '计划时间';

  @override
  String get communityNote => '备注（可选）';

  @override
  String get communityNoteHint => '简要说明本次激活…';

  @override
  String get communityAnnounceButton => '发布';

  @override
  String get communityAnnounced => '激活公告已发布！';

  @override
  String get communityRateLimit => '你刚刚发布过内容，请等待几分钟。';

  @override
  String get communityCallsignRequired => '呼号为必填项';

  @override
  String get communityReferenceRequired => '编号为必填项';

  @override
  String get communityBandRequired => '请至少选择一个波段';

  @override
  String get communityActivations => '激活活动';

  @override
  String get communityChat => '聊天';

  @override
  String get communityEditActivation => '编辑激活公告';

  @override
  String get communityDeleteActivation => '删除激活公告';

  @override
  String get communityDeleteActivationConfirm => '删除该激活公告？此操作无法撤销。';

  @override
  String get communityUpdated => '激活公告已更新';

  @override
  String get chatRooms => '聊天室';

  @override
  String get chatGeneral => '综合';

  @override
  String get chatGeneralSubtitle => '通用语言：英语';

  @override
  String get chatMessageHint => '输入消息…';

  @override
  String get chatSend => '发送';

  @override
  String get chatEdit => '编辑';

  @override
  String get chatDelete => '删除';

  @override
  String get chatDeleteConfirm => '删除这条消息？';

  @override
  String get chatEdited => '已编辑';

  @override
  String get chatNoStation => '请先设置当前电台再聊天';

  @override
  String get chatToday => '今天';

  @override
  String get chatYesterday => '昨天';

  @override
  String get chatFollow => '关注';

  @override
  String get chatUnfollow => '取消关注';

  @override
  String get chatFollowing => '已关注该聊天室';

  @override
  String get chatAddReaction => '添加表情回应';

  @override
  String get gifPreparing => '正在准备视频…';

  @override
  String gifCapturing(int percent) {
    return '正在采集画面… $percent%';
  }

  @override
  String get gifEncoding => '正在编码视频…';

  @override
  String get comingSoon => '即将推出';

  @override
  String get noCompassSensor => '无指南针传感器';

  @override
  String get fillFromGps => '从 GPS 填充';

  @override
  String get locationPermissionDenied => '定位权限被拒绝';

  @override
  String gpsError(String error) {
    return 'GPS 错误：$error';
  }

  @override
  String get errParse => '解析服务器响应失败';

  @override
  String get errLocalStorage => '本地存储错误';

  @override
  String get errServer => '服务器错误';

  @override
  String get wpxPrefix => 'WPX 前缀';

  @override
  String get nowBtn => '现在';

  @override
  String get contestOtherCustom => '其他 / 自定义';

  @override
  String get sigInfo => 'SIG 信息';

  @override
  String get migrationTitle => '需要 API v2';

  @override
  String get migrationBody =>
      'Wavelog Mobile 现已使用 Wavelog 的新 API 系统，旧的 API 密钥已失效。按以下步骤即可在几分钟内完成迁移。';

  @override
  String get migrationStep1Title => '安装服务器补丁';

  @override
  String get migrationStep1Body =>
      '需要在你的 Wavelog 服务器上安装一个小更新文件。点击下方的「安装指南」按钮查看分步说明。';

  @override
  String get migrationInstallGuideBtn => '安装指南';

  @override
  String get migrationStep2Title => '创建新的 API 令牌';

  @override
  String get migrationStep2Body =>
      '在 Wavelog 网页端：\n  1. 打开右上角的设置菜单\n  2. 进入“API”→“API 令牌”\n  3. 点击“新建令牌”\n  4. 选择“Wavelog Mobile”预设\n  5. 确认并复制显示的代码\n  （令牌以“wl2_”开头）';

  @override
  String get migrationStep3Title => '更新你的配置';

  @override
  String get migrationStep3Body => '点击下方按钮。服务器地址会保留，只需把复制的新令牌粘贴到输入框。';

  @override
  String get migrationUpdateTokenBtn => '更新令牌';

  @override
  String get migrationHelpBtn => '帮助与安装指南';

  @override
  String get celebTitle => 'Wavelog v3.2.0';

  @override
  String get celebSubtitle => '不再需要服务器补丁！';

  @override
  String get celebBody =>
      '现在所有功能均可直接通过 Wavelog 官方 API v2 使用，你可以移除之前上传到服务器的旧补丁。\n\n本应用现在需要 Wavelog v3.2.0 或更高版本。';

  @override
  String get celebCreateToken => '创建 API 令牌';

  @override
  String get celebSkip => '跳过';

  @override
  String get celebScopesTitle => 'API v2 令牌权限域';

  @override
  String get celebScopesBody =>
      '在 Wavelog 界面中依次进入 个人资料 → API 令牌 → 新建令牌 创建新令牌时，请勾选以下权限域：';

  @override
  String get celebDone => '知道了';

  @override
  String get scopeQsoRead => '读取 QSO 记录';

  @override
  String get scopeQsoWrite => '添加 / 更新 QSO';

  @override
  String get scopeQsoDelete => '删除 QSO';

  @override
  String get scopeStationRead => '读取电台配置';

  @override
  String get scopeStationWrite => '创建 / 更新电台';

  @override
  String get scopeStationDelete => '删除电台';

  @override
  String get scopeLogbookRead => '读取通联日志';

  @override
  String get scopeLogbookWrite => '创建 / 更新通联日志';

  @override
  String get scopeLogbookDelete => '删除通联日志';

  @override
  String get scopeContestRead => '读取竞赛场次';

  @override
  String get scopeContestWrite => '创建 / 更新竞赛场次';

  @override
  String get scopeContestDelete => '删除竞赛场次';

  @override
  String get scopeCatalogRead => 'DXCC、行政区划与竞赛列表';

  @override
  String get scopeLookupRead => '呼号查询';

  @override
  String get scopeStatisticsRead => '读取统计数据';

  @override
  String get scopeConfirmationRead => '读取 LoTW / eQSL / QRZ.com 确认信息';

  @override
  String get scopeTestStation => '电台';

  @override
  String get scopeTestLogbook => '通联日志';

  @override
  String get scopeTestQso => 'QSO';

  @override
  String get scopeTestContest => '竞赛';

  @override
  String get scopeTestConfirmation => '确认信息';

  @override
  String get scopeTestStatistics => '统计';

  @override
  String get scopeTestLookup => '查询';

  @override
  String get scopeRadioWrite => '上报 CAT 电台的频率和模式';

  @override
  String get scopeTestRadio => '电台';

  @override
  String get apiScopeGuideBtn => 'API 权限域指南';

  @override
  String get apiScopeGuideTitle => 'API 令牌权限域指南';

  @override
  String get apiScopeGuideIntro =>
      '在 Wavelog（设置 → API 令牌）中创建新 API 令牌时，请勾选以下全部权限域以启用应用的完整功能。';

  @override
  String get apiTokenNoticeTitle => '创建新的 API 令牌';

  @override
  String get apiTokenNoticeBody =>
      'Wavelog v2 API 需要具有特定权限域的新令牌。请前往 Wavelog → 设置 → API 令牌，创建包含全部所需权限域的新令牌。点击下方的「API 权限域指南」按钮查看完整列表。';

  @override
  String get apiTokenNoticeDontShow => '不再显示';

  @override
  String get apiTokenNoticeIgnore => '忽略';

  @override
  String get apiTokenNoticeScopeGuide => 'API 权限域指南';

  @override
  String get communitySignInTitle => '验证你的呼号';

  @override
  String get communitySignInSubtitle =>
      '使用 Google 登录，将你的 Google 账号与呼号关联，以确保只有你能以该呼号发布内容。';

  @override
  String get communitySignInButton => '使用 Google 登录';

  @override
  String get communitySignInNoStation => '使用社区功能前，请先在设置中选择当前电台。';

  @override
  String get communityCallsignTaken => '该呼号已关联到其他 Google 账号。';

  @override
  String get communitySignOut => '退出并切换账号';

  @override
  String get syncTitle => '离线同步';

  @override
  String get syncStatusOnline => '在线';

  @override
  String get syncStatusOffline => '无网络连接';

  @override
  String get syncOfflineModeNote => '离线模式已开启，自动同步已暂停，仍可手动同步。';

  @override
  String get syncAllDone => '全部已同步';

  @override
  String syncRunning(int done, int total) {
    return '正在同步… $done / $total';
  }

  @override
  String get syncWaiting => '等待同步';

  @override
  String get syncWaitingDeletes => '等待删除';

  @override
  String get syncLastRun => '上次尝试';

  @override
  String get syncLastSuccess => '上次完整同步';

  @override
  String get syncNever => '从未';

  @override
  String get syncSyncedLast => '上次已发送';

  @override
  String get syncFailedLast => '上次失败';

  @override
  String get syncLastError => '最近错误';

  @override
  String get syncQueueTitle => '待同步 QSO';

  @override
  String get syncQueueEmpty => '没有待同步的 QSO';

  @override
  String get syncNoConnection => '无网络连接 — 恢复联网后会自动开始同步';

  @override
  String syncDone(int count) {
    return '已同步 $count 条 QSO';
  }

  @override
  String get syncNothing => '无需同步';

  @override
  String get openAddQsoOnStart => '启动即打开添加 QSO';

  @override
  String get openAddQsoOnStartHint => '应用启动后直接打开 QSO 表单；返回键回到首页';

  @override
  String get rigSection => '电台（CAT）';

  @override
  String get rigScreenTitle => '电台连接（CAT）';

  @override
  String get rigTileSubtitle => '通过 USB 线连接的电台实时读取频率';

  @override
  String get rigProtocolLabel => '协议';

  @override
  String get rigProtocolIcom => 'Icom CI-V';

  @override
  String get rigProtocolXiegu => '协谷 G90（CI-V）';

  @override
  String get rigProtocolKenwood => '建伍 / Elecraft / 八重洲（FA;）';

  @override
  String get rigProtocolYaesuLegacy => '八重洲 FT-817/818/857/897';

  @override
  String get rigBaudLabel => '波特率';

  @override
  String get rigCivAddressLabel => 'CI-V 地址';

  @override
  String get rigCivAddressHint =>
      '例如 94 对应 IC-7300，A4 对应 IC-705，98 对应 IC-7610，88 对应协谷 G90';

  @override
  String get rigAutoConnect => '自动连接';

  @override
  String get rigAutoConnectHint =>
      '电台 USB 线插入时，或应用启动时已插入。在 Android 弹窗中勾选“始终”可跳过下次询问。';

  @override
  String get rigDevicesLabel => 'USB 设备';

  @override
  String get rigNoDevices => '未找到 USB 串口设备。请使用 USB OTG 线连接电台。';

  @override
  String get rigRefresh => '刷新';

  @override
  String get rigConnect => '连接';

  @override
  String get rigDisconnect => '断开';

  @override
  String rigStatusConnected(String device) {
    return '已连接：$device';
  }

  @override
  String get rigStatusConnecting => '正在连接…';

  @override
  String get rigStatusDisconnected => '未连接';

  @override
  String get rigWaitingForData => '正在等待电台响应…请检查协议、波特率和 CI-V 地址。';

  @override
  String get rigErrorPermission => 'USB 权限被拒绝';

  @override
  String get rigErrorDetached => '电台已断开';

  @override
  String rigErrorConnection(String code) {
    return '连接错误（$code）';
  }

  @override
  String get workedNewCountry => '新国家';

  @override
  String workedNewBand(String band) {
    return '新波段（$band）';
  }

  @override
  String workedNewMode(String mode) {
    return '新模式（$mode）';
  }

  @override
  String workedDupe(String band, String mode) {
    return '重复：今天已在 $band $mode 通联过';
  }

  @override
  String get stationWebOnlySettingsHint =>
      'QRZ.com、HRDLog.net、QO-100（webADIF）、OQRS 以及 eQSL 默认留言需在 Wavelog 网页端设置，API 未向应用开放这些项。';

  @override
  String get qsoReferencesSection => 'POTA / SOTA / WWFF';

  @override
  String get potaRefHint => 'US-1234，可用回车或逗号添加多个';

  @override
  String get potaUnknownParkTitle => '未知公园';

  @override
  String potaUnknownParkBody(String refs) {
    return 'pota.app 中没有公园 $refs。仍要保存该 QSO？';
  }

  @override
  String get spotNewPark => '新公园';

  @override
  String potaActivationProgress(String park, int count, int needed) {
    return '$park：今日（UTC）已通联 $count/$needed 条 QSO';
  }

  @override
  String potaActivationDone(String park, int count) {
    return '$park：已激活（今日 $count 条 QSO）';
  }

  @override
  String get keepScreenOnWhileLogging => '记录时保持屏幕常亮';

  @override
  String get keepScreenOnWhileLoggingHint => '添加 QSO 或竞赛记录打开时屏幕保持常亮';

  @override
  String contestDupe(String band, String time) {
    return '重复：本次竞赛已在 $band（$time UTC）通联过';
  }

  @override
  String contestWorkedOn(String bands) {
    return '本次竞赛已通联的波段：$bands';
  }

  @override
  String get mapLayers => '地图图层';

  @override
  String get mapBaseAuto => '自动（浅色 / 深色）';

  @override
  String get mapBaseLight => '浅色';

  @override
  String get mapBaseDark => '深色';

  @override
  String get mapBaseTopo => '地形图';

  @override
  String get mapGreatCircles => '从我电台出发的大圆航线';

  @override
  String get mapGreyline => '灰线';

  @override
  String get mapGreylineHint => '当前夜半球与昼夜分界线';

  @override
  String get mapNorthUp => '北在上';
}
