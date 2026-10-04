# 实现、测试与已知差异

[返回首页](../README.md)

以下命令在仓库根目录运行。

## 工作原理

- `_extensions/gbt7714/gbt7714-*.csl`：最初由 [zotero-chinese/styles](https://github.com/zotero-chinese/styles) 的 2025 双语 CSL-M 样式经 `tools/provenance/cslm2csl.py` 转换（仅作出处记录，**不要重跑**），此后 CSL 文件本身就是源码，按 golden test 修正。
- `gbt7714.lua`：补上 CSL 和 pandoc 做不到的部分，按上游 bst 行为适配：
  - 语言判断（`set.entry.lang`）、中英文分支、排序 key（`presort`）；
  - 英文标题 sentence case、全角标点、姓名格式（拼音名不缩写等）、版次与卷；
  - 补回 pandoc 读 bib 时丢失的类型与字段（`@standard`、`@map`、`@preprint`、专利权人、比例尺、CSTR、`\quad` 等）；
  - 正文引文：叙述式 `@key`、上标页码。

## Golden test

```bash
python3 test/compare.py            # 全部模式；也可指定 authoryear / numeric / note / note-cite / cite-authoryear / cite-numeric
python3 test/compare.py numeric -v # 显示逐条差异
python3 test/compare.py --check    # 与 test/baseline.json 比，任何原本一致的条目或排序退步即 exit 1
python3 test/compare.py --update   # 确认是真修好后，重写 baseline
python3 test/test_bib_scan.py      # bib 原文扫描的边界情况
python3 test/test_citation_errors.py # 省略作者、自定义 CSL 提示与错误诊断
python3 test/test_multi_narrative.py # 多条叙述式引文与脚注
python3 test/test_name_disambiguation.py # 叙述式与括号引文共享消歧结果
python3 test/test_inferred_year.py # 推定年份与出版年份的独立消歧
python3 test/test_fragment_entries.py # 丛书卷册与日期片段
python3 test/test_bibliography_heading.py # 自动标题与显式文献表标题
python3 test/test_blind.py --pdf --manuscript # 投稿稿分页与匿名检查
python3 test/test_blind.py --pdf  # HTML/Word/PDF 匿名与署名输出
sh example/arch-cases/run.sh      # Quarto 集成（标题、交叉引用、margin、GFM）
```

用 upstream bst（`test/upstream/`）与本 CSL 分别渲染 GB/T 7714—2025 标准原文的 344 条示例（`gbt7714-examples.bib`），逐条比对。pandoc 侧用 Quarto 自带的 pandoc、用户默认设置（不设 `lang`）。注释体例 upstream 没有，`note`（文献表）与 `note-cite`（每条文献的首次引用脚注）对照 bst numeric 文献表。upstream 更新时，替换 `test/upstream/` 后跑 `--check`。

当前（严格比对）：

| 对比 | 一致 |
|---|---|
| 文献表 numeric | 344/344 |
| 文献表 authoryear | 344/344 |
| 注释体例文献表（`note`） | 344/344 |
| 注释体例首次引用（`note-cite`） | 344/344 |
| 正文引文 numeric（`cite-numeric`） | 23/23 |
| 正文引文 authoryear（`cite-authoryear`） | 23/23 |

## 已知差异

此前列出的四项问题均已处理，当前测试集内无剩余差异：

- 推定年份 `[2025]` 与明确出版年份 `2025` 独立分配消歧后缀，正文与文献表一致。
- 丛书名、卷号、分卷书名按正确顺序输出。
- 叙述式引用复用 citeproc 的作者选择与消歧结果，同姓作者在正文和括号引文中保持一致。
- 日期片段 `[1936]` 的脚注原本正常；修正了对照脚本把日期误删作文献编号的问题。

这些结果覆盖仓库内的标准示例与回归用例，不代表所有文献库和 Quarto 配置都已验证。Quarto book、natbib、Typst 等集成限制见[适用范围与限制](citations.md#适用范围与限制)。
