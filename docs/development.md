# 实现、测试与已知差异

[返回首页](../README.md)

以下命令在仓库根目录运行。

## 工作原理

- `_extensions/gbt7714/gbt7714-*.csl`：最初由 [zotero-chinese/styles](https://github.com/zotero-chinese/styles) 的 2025 双语 CSL-M 样式经 `tools/provenance/cslm2csl.py` 转换（仅作出处记录，**不要重跑**），此后 CSL 文件本身就是源码，按 golden test 修正。
- `gbt7714.lua`：补上 CSL 和 pandoc 做不到的部分，规则都照搬 bst：
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
python3 test/test_bibliography_heading.py # 自动标题与显式文献表标题
python3 test/test_blind.py --pdf --manuscript # 投稿稿分页与匿名检查
python3 test/test_blind.py --pdf  # HTML/Word/PDF 匿名与署名输出
sh example/arch-cases/run.sh      # Quarto 集成（标题、交叉引用、margin、GFM）
```

用 upstream bst（`test/upstream/`）与本 CSL 分别渲染 GB/T 7714—2025 标准原文的 344 条示例（`gbt7714-examples.bib`），逐条比对。pandoc 侧用 Quarto 自带的 pandoc、用户默认设置（不设 `lang`）。注释体例 upstream 没有，`note`（文献表）与 `note-cite`（每条文献的首次引用脚注）对照 bst numeric 文献表。upstream 更新时，替换 `test/upstream/` 后跑 `--check`。

当前（严格比对）：

| 对比 | 一致 |
|---|---|
| 文献表 numeric | 343/344 |
| 文献表 authoryear | 339/344 |
| 注释体例文献表（`note`） | 343/344 |
| 注释体例首次引用（`note-cite`） | 342/344 |
| 正文引文 numeric（`cite-numeric`） | 23/23 |
| 正文引文 authoryear（`cite-authoryear`） | 23/23 |

## 已知差异（TODO）

- [x] numeric 连续编号压缩为 `[7-8]`、`[1-2,5]`（filter 自行调用 citeproc 后压缩）
- [x] authoryear 中文前缀连写：`（见博伯尔，2023）`；英文前缀保留空格
- [ ] authoryear 消歧后缀：bst 把"[2025]"（无出版年）与"2025"分开计，citeproc 合并计（4 条）
- [ ] 丛书名 + 卷 + 书名的片段示例 `中国科学技术史：第二卷 科学思想史`（1 条）
- [ ] 注释体例：只有日期的片段示例 `[1936]` 首次引用脚注为空（1 条）
- [ ] 同姓不同名作者的正文引文消歧（filter 自拼的作者名）

