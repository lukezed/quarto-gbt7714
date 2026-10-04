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

- 不需要设置 `lang`：中文条目的"等""佚名"等不依赖文档语言。
- 中文条目要按拼音排序，需在 bib 中提供 `key` 字段（如 `key = {wang2 ming2}`），与 upstream bst 相同；没有 `key` 的中文条目按码位排在其后。
- 注释体例（`note`）：重复引用写"同N"（指向第 N 条注释）；注码放在标点前（"研究¹。"），可用 `notes-after-punctuation: true` 改回；文末同时输出参考文献表，不需要时设 `suppress-bibliography: true`。
- 正文页码写 `[@key, 42]` 或 `[@key, p. 42]`，输出为上标页码（`[1]⁴²`、`（Boobier，2020）⁴²`）。

## 工作原理

- `_extensions/gbt7714/gbt7714-*.csl`：最初由 [zotero-chinese/styles](https://github.com/zotero-chinese/styles) 的 2025 双语 CSL-M 样式经 `tools/cslm2csl.py` 转换（仅作出处记录，**不要重跑**），此后 CSL 文件本身就是源码，按 golden test 修正。
- `gbt7714.lua`：补上 CSL 和 pandoc 做不到的部分，规则都照搬 bst：
  - 语言判断（`set.entry.lang`）、中英文分支、排序 key（`presort`）；
  - 英文标题 sentence case、全角标点、姓名格式（拼音名不缩写等）、版次与卷；
  - 补回 pandoc 读 bib 时丢失的类型与字段（`@standard`、`@map`、`@preprint`、专利权人、比例尺、CSTR、`\quad` 等）；
  - 正文引文：叙述式 `@key`、上标页码。

## Golden test

```bash
python3 test/compare.py authoryear   # 或 numeric / cite-authoryear / cite-numeric；加 -v 显示逐条差异
```

用 upstream bst（`test/upstream/`）与本 CSL 分别渲染 GB/T 7714—2025 标准原文的 344 条示例（`gbt7714-examples.bib`），逐条比对。upstream 更新时，替换 `test/upstream/` 后重跑。

当前（严格比对）：

| 对比 | 一致 |
|---|---|
| 文献表 numeric | 343/344 |
| 文献表 authoryear | 339/344 |
| 正文引文 numeric（`cite-numeric`） | 14/16 |
| 正文引文 authoryear（`cite-authoryear`） | 16/16 |

## 已知差异（TODO）

- [ ] numeric 连续编号：pandoc citeproc 输出 `[7,8]`、`[1–3]`，upstream 是 `[7-8]`、`[1-3]`（需在 citeproc 之后加 post filter）
- [ ] authoryear 消歧后缀：bst 把"[2025]"（无出版年）与"2025"分开计，citeproc 合并计（4 条）
- [ ] 丛书名 + 卷 + 书名的片段示例 `中国科学技术史：第二卷 科学思想史`（1 条）
- [ ] 同姓不同名作者的正文引文消歧（filter 自拼的作者名）

## License

- CSL 文件：CC BY-SA 3.0（派生自 zotero-chinese/styles）
- `test/upstream/`：LPPL 1.3c（zepinglee/gbt7714-bibtex-style）
- 其余代码：MIT
