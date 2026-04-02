# Figma 到 LVGL 映射参考

本参考文件用于把 Figma 标注和设计 token 转换成 LVGL 中可维护的页面模板与样式代码。

## 1. 页面与布局映射

| Figma 概念 | LVGL 建议实现 | 说明 |
| --- | --- | --- |
| Frame / Page | `lv_obj_t * screen` 或页面根 container | 顶层页面优先单独封装创建函数 |
| Auto Layout Vertical | `LV_FLEX_FLOW_COLUMN` | 适合列表、表单、卡片堆叠 |
| Auto Layout Horizontal | `LV_FLEX_FLOW_ROW` | 适合工具栏、标签栏、横向信息区 |
| Absolute Position | 手工 `lv_obj_set_pos` / `lv_obj_align` | 仅用于装饰元素或固定布局 |
| Group / Section | container + 局部样式 | 用于分区卡片、面板、弹层 |

## 2. 组件映射

| Figma 组件 | LVGL 建议组件 | 备注 |
| --- | --- | --- |
| Button | `lv_btn` + `lv_label` | 文字按钮、图标按钮都适用 |
| Text | `lv_label` | 多段样式时考虑拆分多个 label |
| Input | `lv_textarea` | 结合 placeholder 和状态样式 |
| Image / Icon | `lv_img` | 位图要控制尺寸和色深 |
| Switch | `lv_switch` | 需要补 `checked` 状态样式 |
| List Item | container + label + img | 常比直接用 `lv_list` 更可控 |
| Tab | `lv_tabview` 或自定义 tabs | 看设计复杂度决定 |
| Modal | overlay container + panel | 透明遮罩单独一层 |
| Badge | 小型 container + label | 背景色和圆角集中管理 |
| Progress | `lv_bar` | 若设计复杂可做自定义样式 |

## 3. Token 映射

建议统一抽成主题常量或样式初始化函数。

| 设计 token | LVGL 落点 |
| --- | --- |
| 主色 / 辅助色 / 警告色 | `lv_color_hex()` 常量或 theme palette |
| 字号 / 字重 | 字体对象，如 `lv_font_montserrat_16` 或自定义字体 |
| 圆角 | `lv_style_set_radius` |
| 边框宽度 / 颜色 | `lv_style_set_border_width` / `lv_style_set_border_color` |
| 间距 / 内边距 | `lv_style_set_pad_*` |
| 阴影 | `lv_style_set_shadow_*`，但需评估性能 |
| 透明度 / 蒙层 | `lv_style_set_bg_opa` |

## 4. 状态样式

必须显式映射状态：

- default
- pressed
- focused
- disabled
- checked

建议为按钮、输入框、开关和标签页单独定义状态样式函数，避免页面内散写。

## 5. 推荐代码组织

```text
ui/
├── ui_home.c
├── ui_home.h
├── ui_theme.c
├── ui_theme.h
└── ui_assets.md
```

建议函数分层：

- `ui_home_create()`：创建页面结构
- `ui_home_apply_theme()`：应用页面局部样式
- `ui_home_bind_events()`：绑定事件

## 6. 降级实现原则

下列效果需要优先评估后再决定是否实现：

- 大面积模糊
- 多层渐变
- 高频阴影
- 复杂遮罩
- 大图透明叠加
- 长时连续动画

若成本过高，应在交付中标注为：

- 视觉近似实现
- 工程降级实现

并说明替代方式，例如静态背景、减少阴影层数、取消模糊。
