---
name: infographic-cards
description: >-
  把一份 Markdown 文档做成一套"素净版"信息图卡片（每节一张 PNG）并生成配图汇总页。
  触发词：出信息图、做配图、把文档做成图、信息图卡片、生成图片、出一套图、
  可视化文档、渲染 html 成 png、素净版信息图。
  典型场景：任何"一份 md 内容 → 一页页风格统一的图卡 + 一页汇总"的需求。
  说明：本 skill 是日常工作中总结沉淀的通用出图流程，示例均为占位内容。
---

# 信息图卡片流水线（md → HTML → PNG）

把一份 md 文档，做成一套风格统一、可单张交付的信息图卡片。核心是**三段式**：

```
NN-名.md   （唯一可编辑的内容源，改这里）
  └─ 中间产物/NN-*.html   （每节一张卡，套用共享 CSS）
       └─ 图片/NN-*.png   （Chrome headless 渲染，交付件）
            └─ 图片/_配图汇总.html   （一页浏览全部 PNG）
```

## 铁律（先读，全都踩过坑）

1. **md 是唯一内容源**。文案永远先改 md，再让 HTML/PNG 跟上。不要在图里塞 md 没有的话，也不要让图和 md 说的不一样。
2. **视口宽 = 卡片宽 = 900px**。CSS 里 `.sheet{width:900px}`，渲染脚本默认 `-Width 900`。两者一旦不等，右侧 padding 会被裁掉（正文右边界贴框）。改了卡片宽就同步改渲染宽。
3. **风格素净**（这是刻意约束，勿回退）：
   - **不要 emoji / 图标字符**当装饰（一律不用）。
   - **不要多色色块 / 彩色端口**。整套只有一个强调色：红 `--red:#c02a2f`。
   - **不要块左侧红竖条**。要强调就把**标题标红**或**块内关键词标红**（`<b>`）。
   - **正文居中**（PPT 式），**标题保持左上角**（`.hd` 不动）。
4. **图别做复杂**。结构/关系图只要把关系讲清楚就行，别堆装饰元素、别叠一堆标签块。做过头了就删到只剩骨架 + 红字标注关键点。
5. **红字标点，不用装饰块标点**。要点出来的关键信息，用红色文字标，不要专门做个彩色小方块。

## 操作步骤

### 1. 建目录（每套图一个文件夹）

```
NN-名称/
  NN-名称.md        # 内容源
  中间产物/          # HTML + 共享 CSS
    _信息图样式.css
    01-xxx.html …
  图片/              # 渲染出的 PNG + 汇总页
    _配图汇总.html
  归档/
```

新建时把 `assets/_信息图样式.css` 复制进 `中间产物/`，把 `assets/渲染图片.ps1` 复制到该目录的上一级（多套图可共用一份）。

### 2. 写 HTML（一节一张卡）

每张卡 = 一个 `.sheet`，`<head>` 里 `<link rel="stylesheet" href="_信息图样式.css">`，卡内特有布局写在页面内的 `<style>`。骨架：

```html
<!DOCTYPE html><html lang="zh-CN"><head>
<meta charset="UTF-8"><title>…</title>
<link rel="stylesheet" href="_信息图样式.css">
</head><body>
<div class="sheet">
  <div class="hd">
    <div class="kk">SECTION KEY</div>
    <div class="tt"><h1>标题</h1><p class="sub">副标题</p></div>
  </div>
  <p class="lede">导语，正文居中，关键词用 <b>红字</b>。</p>
  <div class="cols">
    <div class="box"><div class="bh">小标题(红)</div><p>正文居中</p></div>
    …
  </div>
  <div class="note"><b>标注：</b>底部说明。</div>
</div>
</body></html>
```

现成组件（都在 CSS 里，直接用）：`.hd` 卡头 · `.lede` 居中导语 · `.axis`+`.chip` 标签行 · `.cols`+`.box`(`.bh` 红标题) 多栏 · `.bands`+`.band` 分层条 · `.chain` 箭头流程链 · `.note` 底部标注。参考 `assets/示例-基础卡.html`（卡头 + 导语 + 多栏 + 标注）和 `assets/示例-流程图.html`（主线 + 分支的复杂流程图，分支用淡背景色区分而非硬边框）。

### 3. 渲染 PNG

```powershell
Set-Location "…\NN-名称"
& "..\渲染图片.ps1" -Inputs "中间产物\*.html"     # 批量，输出到 图片\同名.png
# 单张：& "..\渲染图片.ps1" -Inputs "中间产物\03-流程.html"
```

脚本细节：Chrome `--headless=new`、`--force-device-scale-factor=2`、透明背景，从底部往上找非透明像素自动裁高。输出宽 = 900×2 = 1800px。`-Inputs` 是必填参数名，别省。找不到 Chrome 回退 Edge。

### 4. 生成 / 更新配图汇总页

`图片/_配图汇总.html`：一页按序展示全部 PNG，每张带编号 + 标题 + 对应 md 章节。参考 `assets/_配图汇总示例.html`。**关键**：图片 `width:calc(100% - 48px);margin:20px 24px 24px` —— 用 `100%` 会把图挤到卡片边缘无留白（踩过）。汇总页是独立 HTML、不套共享 CSS，改图数量时增删 `.fig` 块即可。
