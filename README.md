# 卡嘟 (CalDoo)

[English](README.en.md) | 简体中文

离线优先的 **Android** 饮食与营养记录应用:拍照或中文文本记一餐(打字,或用
键盘自带的麦克风语音),拍摄营养成分表自动建档,手抄一个每日运动消耗,查看
每餐 / 日 / 周 / 月的热量与盐分——分析由自带 API Key(BYOK)的 AI 完成。

除 AI 分析外完全离线;数据只存本地 SQLite(热量端到端为整数 kcal,见
[design/integer-energy.md](design/integer-energy.md);显示单位可切换,见
[design/display-units.md](design/display-units.md));AI 失败绝不阻塞记录。

## 功能

- **概览**:一屏三视图(日 / 周 / 月),左右滑动翻看历史,一键回到今天。
  今日记录是按时间排列的扁平列表(每行一个食物),不是餐次分桶;记录全部
  在概览页完成,没有单独的记录页。
- **食物库**:已录入食物的实时检索目录(营养标签 / AI 估算 / 手动录入)。
  添加食物二选一:拍照识别营养标签(AI)或手动录入(离线)。一张照片可含
  多个标签;每个食物可附带包装规格、别名、备注等补充信息。
- **设置**:两个子页——**模型设置**(BYOK API Key / Base URL / 模型,带
  保存与测试连接)和**数据显示**(大卡↔千焦、盐↔钠)。显示偏好只改显示、
  不改存储值,也不影响手动录入。
- **语音输入**:刻意不做应用内语音识别(部分国产 ROM 的 `SpeechRecognizer`
  对第三方应用不可用)。描述框的语音按钮只负责聚焦输入框并指向键盘的麦克风
  键;应用不申请麦克风权限。

## 配置 AI(BYOK)

API Key 只写不读:存入 `flutter_secure_storage`(Android Keystore 加密),
不落数据库、不进日志、不进导出文件。

1. 打开 **我的 → 设置**
2. 在 **API Key** 粘贴 DeepSeek Key(`sk-...`)并**保存**
3. 可选:**测试连接** 验证配置

默认端点(设置里可覆盖,任何 OpenAI 兼容端点均可):`https://api.deepseek.com`
+ `deepseek-flash`,路径 `POST {baseUrl}/chat/completions`。

## 备份与安装规则(重要)

全部记录存在应用私有 SQLite 里,且 `android:allowBackup="false"`——**卸载即
清空,系统层面无法恢复**。两层防护:

- **自动备份**:启动和退到后台时,把全量数据(与导出相同的 JSON)写入公共
  目录 `下载/卡嘟备份/`,保留最近 10 份,卸载后仍在。在 **我的 → 数据备份**
  恢复,或用 **从文件导入** 选任意 `data.json`。备份永不包含 API Key。
- **安全安装**:用 `tool/install_android.sh` 安装——它自己构建 release APK、
  确认设备有近期自动备份、然后 `adb install -r` 原地覆盖。**永远不要用先
  卸载再安装的命令**。

```bash
tool/install_android.sh                     # 构建 + 检查备份 + 原地覆盖安装
ALLOW_NO_BACKUP=1 tool/install_android.sh   # 跳过备份检查
SKIP_BUILD=1 tool/install_android.sh        # 复用已有 release APK
```

## 开发

```bash
flutter pub get
flutter run          # Android 真机或模拟器

dart run build_runner build   # 改动模型后重新生成 Drift / Riverpod / json_serializable

flutter test         # 单元 + Widget 全量
flutter analyze      # 必须为 0 issues
```

## CI/CD

GitHub Actions,工具链固定 stable 3.47.5(本地升级 Flutter 时同步改两个
workflow):

- **CI**(`ci.yml`,push master / PR):build_runner 生成代码一致性检查、
  `dart format`、`flutter analyze`、全量测试。`test/ui_renders` 的 golden
  截图是 macOS 评审产物(打 `ui-renders` tag,声明见 `dart_test.yaml`),CI
  用 `--exclude-tags=ui-renders` 排除;在 Mac 上用
  `flutter test --update-goldens test/ui_renders` 重新生成。
- **Release**(`release.yml`,打 tag 触发):tag `vX.Y.Z` 必须与
  `pubspec.yaml` 的版本一致,先改版本再打 tag;构建正式签名 APK 并发布到
  GitHub Releases。

  ```bash
  git tag v1.2.3 && git push origin v1.2.3
  ```

签名读取 gitignore 的 `android/key.properties` + `android/app/caldoo-release.jks`;
CI 从 4 个 Secrets 恢复(`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD`
/ `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`);没有 key.properties 的检出
回落 debug 签名,`flutter run --release` 不受影响。

> ⚠️ **务必备份 keystore 和密码**(密码管理器等)。丢失即永久:换签名后
> Android 拒绝升级安装。

## 明确不做

- 后端 / 账号 / 云同步——纯本地。
- Health Connect / 厂商运动 SDK——运动就是手抄一个每日消耗数。
- 条码扫描 UI、端侧 OCR、端侧食物模型——标签靠 AI 解析(BYOK,在线)或手动录入。
- 应用内语音识别——用键盘麦克风(见上)。
- 儿童模式 / 活动水平系数——单成人档案,基线就是 BMR(由性别 / 生日 / 身高 /
  体重按 Mifflin-St Jeor 推导,年龄随生日自动更新),运动另加,不可能重复计算。
- 可配置的周 / 月——固定周一 00:00 → 周日 24:00 与自然月。
- 横屏布局——锁定竖屏(Android 16+ 的大屏设备上旋转由系统决定)。
- 仅 Android——无 iOS / macOS / Web / Windows / Linux。
