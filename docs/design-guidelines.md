# Musaic 设计规范

## 颜色

Musaic 的桃红色强调色是 `#C20040`，以 [`AppColors.settingsAccent`](../lib/ui/theme/app_colors.dart) 为准。

- Flutter 界面需要使用桃红色强调时，直接引用 `AppColors.settingsAccent`。
- Musaic 的网页和独立静态页面使用同一色值，将其定义为 CSS 变量并复用。
