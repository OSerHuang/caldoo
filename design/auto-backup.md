# 自动备份（off-app auto backup）

> 事故背景：2026-10-30，安装新版时用了会「先卸载再安装」的命令，卸载删掉了
> `/data/data/com.caldoo`（drift/SQLite 数据库），而这个 App 的清单里是
> `android:allowBackup="false"`，系统也没有任何备份。全部饮食记录一次性丢失，
> 设备、`/sdcard`、Mac、vivo 互传缓存都找不到可恢复的副本。这个设计是对那次
> 事故的直接回应：**在 App 私有目录之外，留一份随时可恢复的全量快照。**

## 失败模式

| 失败模式 | 旧状态 | 现在 |
| --- | --- | --- |
| 卸载 / 覆盖安装失败导致卸载 | 私有数据库全丢，无副本 | 「Download/caldoo」里的快照仍存在 |
| 清空 App 数据 | 全丢 | 同上 |
| 升级迁移写坏数据库 | 全丢 | 每次启动 / 退到后台都会先留快照 |
| 用户在 App 里误删记录 | 只能靠手动导出 | 最近 10 份快照可选其一恢复 |
| 换手机 / 重装 | 只有手动导出过 `data.json` 才能恢复 | 从文件导入（SAF）任选 JSON |

## 机制

1. **触发**：`AutoBackupLifecycle`（挂在 `MaterialApp.builder` 里）在首帧后与
   `AppLifecycleState.paused/detached` 时调用 `AutoBackupService.maybeRun()`。
   5 分钟内不重复抓取；用户可在数据备份页关掉开关（默认开）。
2. **抓取**：复用 task-28 的 `BackupService.capture()`，得到与「导出」完全一致
   的 `BackupData`（个人资料、食物、餐食+条目、每日运动、非机密设置）。
   **空数据库不写**，避免新装的空快照把真实备份挤出保留窗口。
3. **落盘**：`Android 10+` 用 `MediaStore.Downloads` 写
   `Download/caldoo/data-yyyyMMdd-HHmmss.json`（无需权限、卸载后保留；旧版本写在
   `Download/卡嘟备份/`，改名后旧快照仍留在原目录，可手动移动或从文件导入）；
   `Android 9-` 没有免权限的公共目录，退化到 App 专属外部下载目录（会随卸载
   删除，界面上如实说明）。文件名按本地时间精确到秒，不覆盖旧文件。
4. **保留**：最多 10 份，按修改时间删旧。删除失败（例如是上一次安装留下的
   文件，MediaStore 不允许当前安装删除）直接忽略——那仍是一份可恢复的副本。
5. **恢复**：数据备份页列出快照，确认后走 `BackupService.importFromJson`
   （按 id 只增不改，已存在的行胜出）。重装后旧文件不再归当前应用所有，
   MediaStore 可能读不到，此时用「从文件导入」（SAF）手动选同一份 JSON。

## 安全与隐私

- 快照内容与手动导出同源，**不含 API Key**（Key 只在 `flutter_secure_storage`）。
- 自动备份写在本机公共目录，不上传任何服务器；但也意味着任何有存储访问权限
  的文件管理器都能读到它——与「导出到微信」是同一个暴露面，界面上写明了位置。
- `auto_backup_enabled` 属于设备偏好，列在 `backupExcludedSettingsKeys` 里，
  不会进 `data.json`（新机恢复后保持「开」）。

## 安装规则

`tool/install_android.sh` 是唯一推荐的安装途径：先 `flutter build apk --release`
构出新包，再要求设备上存在 24 小时内的自动备份（`ALLOW_NO_BACKUP=1` 可跳过），
最后 `adb install -r` 覆盖安装。脚本禁止 `adb uninstall` / `pm clear`，也禁止
任何会先卸载的安装命令；`test/android/install_script_test.dart` 把这些约束钉死。

## 测试缝

- `AutoBackupStorage` 是平台边界；`InMemoryAutoBackupStorage` 让服务与界面测试
  完全不碰 MethodChannel。
- `autoBackupLifecycleEnabledProvider` 让 golden 渲染不依赖异步抓取的完成时机。
- `AutoBackupService` 注入 `Clock`，文件名、保留顺序、5 分钟节流都可复现。
