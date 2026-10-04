# quarto-gbt7714

GB/T 7714—2025 参考文献格式的 Quarto 版本（顺序编码制 / 著者-出版年制 / 注释），html、docx、pdf 通用。

目标：输出与 upstream [zepinglee/gbt7714-bibtex-style](https://github.com/zepinglee/gbt7714-bibtex-style) 一致，只是换成 Quarto 原生的 CSL 实现，所以不依赖 LaTeX。

## 用法

```bash
quarto add lukezed/quarto-gbt7714          # 发布到 GitHub 后可用
quarto add /path/to/quarto-gbt7714         # 目前：从本地克隆安装
```

```yaml
bibliography: refs.bib
filters: [gbt7714]
gbt7714: authoryear   # authoryear（默认）| numeric | note
```

- 文献条目不依赖 `lang`：中文条目的"等""佚名"等在任何文档语言下都正确。但 Quarto 自己生成的标题（"References""Footnotes"、图表标签）跟随 `lang`，中文文档请设 `lang: zh`。
- 中文条目要按拼音排序，需在 bib 中提供 `key` 字段（如 `key = {wang2 ming2}`），与 upstream bst 相同；没有 `key` 的中文条目按码位排在其后。
- 注释体例（`note`）：重复引用写"同N"（指向第 N 条注释）；注码放在标点前（"研究¹。"），可用 `notes-after-punctuation: true` 改回；文末同时输出参考文献表，不需要时设 `suppress-bibliography: true`。
  - "同N"按全书统一编号。book 类 PDF（`scrreprt`、`ctexbook` 等）默认每章重置脚注编号，会让"同N"指错，需让脚注全书连续：

    ```yaml
    format:
      pdf:
        include-in-header:
          text: \counterwithout{footnote}{chapter}
    ```

    HTML book 每章单独渲染，章与章之间不会出现"同N"，各章首次引用都给出完整条目。
- Word：pandoc 生成 docx 时不读 CSL 的悬挂缩进，文献表格式取决于 reference doc 的 `Bibliography` 样式。可直接用附带的模板（文献表悬挂缩进 2 字；正文宋体、标题黑体，西文 Times New Roman）：

  ```yaml
  format:
    docx:
      reference-doc: _extensions/gbt7714/gbt7714-reference.docx
  ```

  路径相对于写这一行的文件：写在项目根的 `_quarto.yml` 里如上；写在子目录 qmd 的 front matter 里要相应加 `../`。已有自己模板的，在 Word 里把 `Bibliography` 样式设为悬挂缩进即可。模板由 `tools/make_reference_docx.py` 生成。
- 正文页码写 `[@key, 42]`、`[@key, p. 42]` 或 `[@key, 第42页]`，输出为上标页码（`[1]⁴²`、`（Boobier，2020）⁴²`）。

## 适用范围与限制

- **只作用于 citeproc**。`cite-method: natbib` / `biblatex` 时 filter 不做任何事，PDF 交给 LaTeX（可直接用 upstream 的 `gbt7714` 宏包）。
- **Typst**：Quarto 的 typst 默认用 Typst 原生引用，不经过 CSL filter；要用本格式，在 `format: typst` 下设 `citeproc: true`（filter 会给出提示）。
- **Quarto book（HTML）**：Quarto 每章单独跑 citeproc，references 页由 Quarto 另起一个不带 filter 的 pandoc 生成，extension 无法介入。因此：
  - book 的 **PDF / docx** 完全正常（全书一次 citeproc，numeric 编号跨章连续）；
  - book 的 **HTML** 请不要放 `::: {#refs}` 参考文献页，改为每章末尾显示本章文献（格式正确；numeric 编号章内连续）；
  - 单文档、website 不受影响。
- 只扫描 `.bib` 文件补字段；CSL-JSON / YAML 文献库可用，但 bib 专有字段（`key`、`langid` 等）自然没有。

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
| 正文引文 authoryear（`cite-authoryear`） | 22/23 |

## 纯 pandoc 用法

filter 自己调用 citeproc，不要再加 `--citeproc`（否则 pandoc 会先用默认样式跑一遍）：

```bash
pandoc paper.md --bibliography refs.bib -M gbt7714=numeric -L _extensions/gbt7714/gbt7714.lua -o paper.docx
```

## 已知差异（TODO）

- [x] numeric 连续编号压缩为 `[7-8]`、`[1-2,5]`（filter 在 citeproc 之后处理）
- [ ] authoryear 中文前缀后多一个空格：`（见 博伯尔，2023）`，upstream 为 `（见博伯尔，2023）`
- [ ] authoryear 消歧后缀：bst 把"[2025]"（无出版年）与"2025"分开计，citeproc 合并计（4 条）
- [ ] 丛书名 + 卷 + 书名的片段示例 `中国科学技术史：第二卷 科学思想史`（1 条）
- [ ] 注释体例：只有日期的片段示例 `[1936]` 首次引用脚注为空（1 条）
- [ ] 同姓不同名作者的正文引文消歧（filter 自拼的作者名）

## 数据规范

与 upstream bst 相同，以下写法不会被纠正，请在 bib 中改好：

- 多位作者只能用 ` and ` 分隔：`author = {张三 and 李四}`。知网等导出的 `张三,李四`、`王五;赵六` 会被当成一个作者。
- 页码范围用 `-` 或 `--`：`pages = {45--67}`。`45~67` 中的 `~` 是 TeX 的不换行空格，会输出成"45 67"。
- 语言优先看 `langid`/`language`（`chinese`、`zh`、`zh-CN` 等均视为中文；`zh-CN` 这类代码 upstream 视为其他语言，此处按中文处理），没有时按第一个非空字段的文字判断。

## License

见 `LICENSE`：代码 MIT；CSL 文件 CC BY-SA 3.0（派生自 [zotero-chinese/styles](https://github.com/zotero-chinese/styles)，原作者 Zeping Lee）；`test/upstream/` 为 LPPL 1.3c（[zepinglee/gbt7714-bibtex-style](https://github.com/zepinglee/gbt7714-bibtex-style)）。
