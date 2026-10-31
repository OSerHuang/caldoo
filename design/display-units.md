# 显示单位：大卡 / 千焦、盐 / 钠（2026-10-30）

## 结论

设置页拆成两个互不影响的区块：**模型设置**（BYOK 的 API Key / Base URL / 模型，保留显式「保存 / 测试连接」）与**数据显示**（立即生效的显示偏好）：

- **热量单位**：大卡（kcal，默认）或千焦（kJ）；
- **盐 / 钠显示**：盐（g，默认）或钠（mg）。

两条偏好**只影响显示**，不改写任何已记录数据，也不改变手动录入的单位。手动录入仍然两种数据都接受：营养成分表按 **kJ / mg** 输入，餐食/食物编辑按 **kcal / g** 输入。

## 为什么存储不变

领域层（`lib/core/units/nutrition_units.dart`）的契约不变：

- 能量一律**整 kcal（int）**存储与运算，kJ 只在输入边界（GB 28050 标签）用 `kJToKcal` 换算一次；
- 钠一律**mg**存储（`Food.sodiumMg`），盐克数只是显示派生值（`sodiumMgToSaltG`，1 g 盐 = 400 mg 钠）；
- 盐目标固定为 5 g/天 = 2000 mg 钠。

若为了显示而改动存储，会让历史数据、备份、AI 提示词和两次显示切换之间的往返产生舍入漂移。因此显示层只做**单向换算**：

- `显示 kJ = round(存储 kcal × 4.184)`；
- `显示钠 mg = 盐 g × 400`，`显示盐 g = 钠 mg / 400`；
- 目标值随基准显示：`5`（g）或 `2000`（mg）。

## 实现结构

- `lib/core/units/display_units.dart`
  - `EnergyDisplay { kcal, kj }`、`SaltDisplay { salt, sodium }`；
  - `DisplayUnits`：换算与格式化助手（`energyValue/energyValueText/energyUnit/energyText`、`saltLabel/saltUnit/saltValueFromSaltG/saltProgressFromSaltG/saltTargetText` 等），换算规则只在这里出现一次；
  - `DisplayScope`（InheritedWidget）+ `DisplayUnits.of(context)`：无 scope 时回退到**默认 kcal + 盐**，所以既有测试与 golden 完全不受影响。
- `lib/features/settings/display_settings.dart`：`DisplaySettings` 模型 + `DisplaySettingsRepository`，非敏感偏好写入 Drift `app_settings` 键值表（`display_energy_unit` = `kcal|kj`，`display_salt_basis` = `salt|sodium`），不落安全存储、不进 AI 配置投影。
- `lib/features/settings/display_settings_providers.dart`：`AsyncNotifier` 控制器，切换即持久化（数据显示区块没有保存按钮）。
- `lib/main.dart`：根 `HaohaochifanApp` 监听偏好，把解析后的 `DisplayUnits` 作为 `DisplayScope` 包在 `MaterialApp.router` 外层；加载完成或切换时整棵显示树自动重建。
- 设置页：`模型设置` / `数据显示` 两个标题分块，分段按钮选择单位与盐/钠基准，并附一句「只影响显示，手动录入仍按原单位」的说明。

## 应用范围（只读显示）

- 今日 / 日汇总：热量、今日额度、运动消耗、环形中心缺口/盈余、盐或钠指标（含 5 g ↔ 2000 mg 目标与进度）；
- 周 / 月汇总：总摄入 / 总消耗 / 差值、盐达标或钠达标、图表 Y 轴刻度、虚线与长按气泡里的摄入/消耗/差值；
- 今日记录行、餐食详情条目行、本餐合计 / 今日累计、复核页合计；
- 食物详情（每 100 g/ml 的营养表）与「选择已存食物」后的只读数值行；
- 资料页的两处只读派生值：每日基础额度（热量单位）与每日盐/钠目标（5 g ↔ 2000 mg）。

**不切换的录入字段**（有意为之）：营养标签采集（能量 kJ、钠 mg、每 100 g/ml）、复核条目编辑（kcal、盐 g、克数）、食物编辑的克数输入、运动消耗 kcal、资料页基础代谢 kcal、宏量营养素 g。它们属于「录入」，按原始数据单位工作，两种单位的数据都能被接受。

## 持久化与数据边界

- 偏好保存在 `app_settings`，与 AI 的 `baseUrl/model` 同表但不同键；「删除全部数据」会清空该表，从而回到默认值。
- 自动备份 / 导出**不包含**显示偏好：它是本机显示习惯，不是记录数据；恢复备份不会把另一台设备的单位偏好带过来。
- 不改 schema、不迁移数据库、不触碰任何记录表。

## 测试

- `test/core/units/display_units_test.dart`：换算（含负值差值）、盐/钠映射、`DisplayScope` 回退与变更通知；
- `test/features/settings/display_settings_test.dart`：默认值、键值 round-trip、未知值回退、控制器即时持久化；
- `test/features/settings/settings_screen_test.dart`：两个分区块、默认选中项、切换立即落库且不触发模型保存、重启后仍选中；
- 各显示面（日/周/月汇总、餐食合计、食物详情等）新增 `DisplayScope(kJ + 钠)` 用例；默认 kcal/盐 的既有断言保持不变。
