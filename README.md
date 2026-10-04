# quarto-gbt7714

GB/T 7714—2025 参考文献格式的 Quarto 版本（顺序编码制 / 著者-出版年制 / 注释），html、docx、pdf 通用。

目标：输出与 upstream [zepinglee/gbt7714-bibtex-style](https://github.com/zepinglee/gbt7714-bibtex-style) 一致，只是换成 Quarto 原生的 CSL 实现，所以不依赖 LaTeX。

## 用法

```bash
quarto add lukezed/quarto-gbt7714
```

```yaml
bibliography: refs.bib
filters: [gbt7714]
gbt7714: authoryear   # authoryear（默认）| numeric | note
```

## 工作原理

- `_extensions/gbt7714/gbt7714-*.csl`：由 [zotero-chinese/styles](https://github.com/zotero-chinese/styles) 的 2025 双语 CSL-M 样式经 `tools/cslm2csl.py` 转成 pandoc 可用的 CSL 1.0，再按 golden test 修正。
- `gbt7714.lua`：
  - 按选项设置 `csl`；
  - 给含 CJK 的条目设置 `language`，CSL 据此分中英文分支（"等" / "et al."）；
  - 英文标题按 bst `change.case$ "t"` 转成 sentence case；
  - 修正 pandoc 丢失的 biblatex 类型（`@standard`、`@map`、`@preprint`、`@archive` 等）。

## Golden test

```bash
python3 test/compare.py authoryear   # 或 numeric；加 -v 显示逐条差异
```

用 upstream bst（`test/upstream/`）与本 CSL 分别渲染 GB/T 7714—2025 标准原文的 344 条示例（`gbt7714-examples.bib`），逐条比对。upstream 更新时，替换 `test/upstream/` 后重跑。

当前：numeric 138/344，authoryear 116/344 条一致。

## 已知差异（TODO）

- [ ] authoryear 排序：upstream 中文在前，CSL 目前英文在前
- [ ] 引文中的页码：GB/T 7714 用上标（`[2]⁴²`、`(Smith et al., 2020)⁴²`），目前是 `[2, p. 42]`
- [ ] authoryear 引文标点（全角/半角）需要对照 `gbt7714.sty` 的 natbib 设置；golden test 目前只比对文献表，不比对正文引文
- [ ] 标准 `[S]`：2025 版改为"编号 + 标题"、不著录责任者
- [ ] 有 URL 时 bst 不输出 DOI；CSL 两者都输出
- [ ] 版本：`2 版` / `5th ed.`（CSL 输出 `Second` / `Fifth`）
- [ ] 卷：`第 4 卷`（CSL-M 的 `第%s卷` term 需改写）
- [ ] 会议录 `@proceedings`、档案、舆图的著录细节
- [ ] `{TeX}book` 这类词内括号保护被 pandoc 丢失
- [ ] 中文按拼音排序：需要 `lang: zh-u-co-pinyin`，但这样 Quarto 会报 translations warning
- [ ] 只有作者等局部元素的"片段"示例（标准第 7 章）CSL 会多输出 `[M]`
- [ ] 注释体例：没有 upstream bst 可以对照，要按标准原文核对（同上、重复引用、`notes-after-punctuation`）

## License

- CSL 文件：CC BY-SA 3.0（派生自 zotero-chinese/styles）
- `test/upstream/`：LPPL 1.3c（zepinglee/gbt7714-bibtex-style）
- 其余代码：MIT
