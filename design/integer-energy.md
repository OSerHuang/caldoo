# 整数热量（Integer energy）

一切**热量/能量（kcal）**在卡嘟里都是**整数**，从 AI/标签输入到存储、算术、
界面显示全程不出现小数。本文档记录这条契约的边界与迁移方式，避免后续改动再把
小数带回能量字段。

## 契约

- 能量字段一律 `int`，单位 **kcal**：
  - `Food.kcal`（每 100 g，`int?`，空白仍是 `null`，绝不变成 0）
  - `MealItem.kcal`
  - `DailyExercise.kcal`
  - `DayRollup.intakeKcal` / `DayRollup.exerciseKcal`
  - `UserProfile.bmrKcalOverride`（`int?`）
  - `EnergyBudget.bmrKcal / baseBudgetKcal / exerciseKcal / budgetKcal /
    intakeKcal`，以及其派生的 `energyBalanceKcal` / `deficitKcal`
  - `MealTotals.kcal`、周汇总的 `baseBudgetKcal / totalIntakeKcal /
    totalBurnKcal / totalBalanceKcal`、`SignedBalance.valueKcal`
  - AI wire model：`MealAnalysisItem.kcal`；标签 model 的
    `LabelParseItem.energyKcal`
- 宏量营养素（碳水/蛋白/脂肪，克）与钠（毫克）仍然是 `double`：只有**热量**
  是整数。
- 盐（克）仍是 show-only 的 `double`。

## 取整规则（唯一一处）

`lib/core/units/nutrition_units.dart` 的 `roundKcal(double)`：四舍五入到最接近的
整数（`.5` 远离 0，即 Dart `num.round()`）。所有小数热量都只在跨入领域模型的
那一刻取整一次：

| 边界 | 规则 |
| --- | --- |
| 标签 kJ → kcal | `kJToKcal(kJ)` = `roundKcal(kJ / 4.184)` |
| AI 返回的 kcal | `MealAnalysisItem.kcal` 的 `@JsonKey(fromJson: kcalFromJson)` 取整 |
| 每 100 g 标签值 × 克数 | `resolveNutrients` 内 `roundKcal(food.kcal * grams / 100)` |
| 仅改克数（AI 估算按比例缩放） | `roundKcal(aiItem.kcal * factor)` |
| Mifflin-St Jeor BMR | `mifflinStJeorBmr` 内部 `roundKcal(...)` |
| 宏量折算热量 `macroKcal` | `roundKcal(4c + 4p + 9f)` |
| 旧备份/旧行的小数热量 | 模型 `fromJson` 的 `kcalFromJson` 取整，不拒绝旧数据 |

## 存储与迁移

- Drift schema **v10**：`foods.kcal`、`meal_items.kcal`、
  `daily_exercises.kcal`、`user_profile.bmr_kcal_override` 由 REAL 改为
  INTEGER。SQLite 不能原地改类型，四张表在 v9→v10 迁移中重建，旧值用
  `CAST(ROUND(x) AS INTEGER)` 取整；`NULL` 营养值仍为 `NULL`。
- 备份格式 **schemaVersion 4**：能量写整数；v2/v3 旧文件仍可导入（小数由
  `fromJson` 取整），旧版本 App 读到 v4 会整份拒绝而不是半解析。

## 界面

- 所有 kcal 展示用 `AppFormat.integer` / `AppFormat.number(int)`；不再有
  `1935.75` 这类小数。
- kcal 输入框只接受数字（`FilteringTextInputFormatter.digitsOnly`），解析为
  `int`；运动消耗、复盘里的能量、BMR 覆盖值都是整数字段。
- 宏量/盐/重量继续按原有小数规则格式化。
