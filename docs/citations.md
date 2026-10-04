# 引用扩展与模板适配

[返回首页](../README.md)

## 在已有项目中使用引用扩展

```bash
quarto add lukezed/quarto-gbt7714
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

## 中文 PDF

中文文章可用 `ctexart` 和 XeLaTeX；需安装含 `ctex` 的 TeX Live（或 TinyTeX）和可用的中文字体：

```yaml
lang: zh
bibliography: refs.bib
filters: [gbt7714]
gbt7714: authoryear
format:
  pdf:
    documentclass: ctexart
    pdf-engine: xelatex
```

`lang: zh` 控制 Quarto 的语言，`ctexart` 负责中文排版。若系统默认字体不可用，可在 `pdf` 下添加 `CJKmainfont: Songti SC`（macOS 示例），或换成已安装的中文字体。

## 从其他引用体例切换

在普通 Quarto 项目中，删除原有的 `csl: apa.csl`，再添加 `filters: [gbt7714]` 和所需的 `gbt7714` 体例。保留外部 `csl:` 会继续使用该 CSL，扩展会给出提示，并只修正文献数据。

如果使用的是 apaquarto 等带完整排版和引用流程的扩展，还需要调整对应的 `format:` 与 filters；仅替换一个 CSL 并不等于完成整套模板迁移。

正文仍使用 Pandoc 引文语法：

| 写法 | 用途（以 `authoryear` 为例） |
|---|---|
| `[@boobier2020]` | 括号引文，如 `（Boobier，2020）` |
| `@boobier2020` | 叙述式，如 `Boobier（2020）` |
| `Boobier [-@boobier2020]` | 作者已写在正文，只输出年份；按 GB/T 连写为 `Boobier（2020）` |
| `[见 @boobier2023]` | 中文前缀与中文作者连写，如 `（见博伯尔，2023）` |
| `[see @boobier2020]` | 英文前缀保留空格，如 `（see Boobier，2020）` |
| `[@boobier2020, p. 42]` | 页码移到右括号后，输出 `（Boobier，2020）⁴²` |

`-@` 表示省略作者，不是省略整条引文；`note` 体例为了让脚注条目完整，仍会保留脚注里的作者。英文前缀使用 `[see @key]`，无需手工删除 `see` 后的空格。

locator（页码或章节定位）写在逗号后。页码可写 `42`、`p. 42`、`pp. 42–45`、`第42页`；`authoryear` / `numeric` 去掉页码标签并置于括号后上标。章节定位写 `[@key, chap. 3]` 或 `[@key, 第3章]`，会保留文字并同样置于上标。`note` 体例把定位信息保留在脚注中。

## Quarto book 同时输出 HTML / PDF

共享章节时，使用以下 `_quarto.yml`。`index.qmd`、正文文件和 `refs.bib` 均相对于项目根目录：

```yaml
project:
  type: book
book:
  title: "中文书稿"
  chapters:
    - index.qmd
    - chapters/chapter01.qmd
    - chapters/chapter02.qmd
lang: zh
bibliography: refs.bib
filters: [gbt7714]
gbt7714: authoryear
reference-section-title: "参考文献"
format:
  html: default
  pdf:
    documentclass: ctexbook
    pdf-engine: xelatex
```

执行 `quarto render` 输出两种格式。各章节中不要放 `::: {#refs}`，也不要在章节清单中添加含 `#refs` 的独立参考文献页：HTML 每章末尾列出本章文献；PDF 全书合并处理，末尾列出全书文献。`numeric` 在 HTML 中各章重新编号，在 PDF 中全书连续编号。

HTML book 的独立 `#refs` 页由 Quarto 另起一个不加载扩展的 Pandoc 进程生成，无法保证 GB/T 的数据修正与排序。仅输出 PDF / docx 的 book 可以使用独立参考文献页；需要指定位置时，在专用配置的 `book.chapters` 中加入 `references.qmd`，内容如下：

```markdown
# 参考文献 {.unnumbered}

::: {#refs}
:::
```

## 文献表标题

自动放在文末的文献表可用 `reference-section-title: "参考文献"` 设置标题。需要自己安排标题和位置时，在单篇文档或仅输出 PDF / docx 的 book 中使用上面的标题与 `#refs` 块。两种方式选一种，避免重复标题；HTML book 请使用 `reference-section-title`。

## PDF 使用 natbib，与 HTML 共存

同一份正文可让 HTML 由本扩展处理，PDF 交给 upstream 的 LaTeX 宏包。以下配置需要 TeX 环境中已安装 upstream `gbt7714` 宏包及对应的 `.bst`：

```yaml
lang: zh
bibliography: refs.bib
filters: [gbt7714]
gbt7714: authoryear
reference-section-title: "参考文献"
format:
  html: default
  pdf:
    documentclass: ctexart
    pdf-engine: xelatex
    cite-method: natbib
    biblio-style: gbt7714-authoryear
    include-in-header:
      text: |
        \usepackage{gbt7714}
```

此时 `gbt7714: authoryear` 选择 HTML 的 CSL，`biblio-style: gbt7714-authoryear` 选择 PDF 的 bst。切换顺序编码制时，两项分别改为 `numeric` 和 `gbt7714-numeric`。PDF 不经过本扩展的数据修正或引文改写，效果由 upstream 宏包决定；`note` 没有对应的 upstream bst。

## 适用范围与限制

- **只作用于 citeproc**。`cite-method: natbib` / `biblatex` 时 filter 不做任何事，PDF 交给 LaTeX（可直接用 upstream 的 `gbt7714` 宏包）。
- **Typst**：Quarto 的 typst 默认用 Typst 原生引用，不经过 CSL filter；要用本格式，在 `format: typst` 下设 `citeproc: true`（filter 会给出提示）。
- **Quarto book（HTML）**：Quarto 每章单独跑 citeproc，references 页由 Quarto 另起一个不带 filter 的 pandoc 生成，extension 无法介入。因此：
  - book 的 **PDF / docx** 支持全书合并渲染（全书一次 citeproc，numeric 编号跨章连续）；
  - book 的 **HTML** 请不要放 `::: {#refs}` 参考文献页，改为每章末尾显示本章文献（格式正确；numeric 编号章内连续；完整配置见上文）；
  - 单文档、website 不受影响。
- **numeric 编号压缩**（`[1-3]`、`[7-8]`）要在 citeproc 之后处理，而 Quarto 的 filter 都在 citeproc 之前运行，所以 numeric 下 filter 先自己跑一次 citeproc 渲染正文引文，文献表仍由 Quarto 照常生成（标题、appendix、悬停预览不受影响）。`citation-location: margin` 时跳过这一步，编号不压缩（`[1–3]`）。
- **自带 `csl:`**：指向非本扩展的 CSL（如 APA）时，filter 给出提示并只做数据修正（类型、姓名、标题大小写等），不做 GB/T 专属的引文改写（叙述式、上标页码、编号压缩）。
- **`appendix-cite-as`**（文章自身的"引用格式"）由 Quarto 在 filter 之前生成，只认 YAML 里的 `csl:`；要让它也用 GB/T 格式，显式写 `csl: _extensions/gbt7714/gbt7714-authoryear.csl`（或对应体例）。
- 只扫描 `.bib` 文件补字段；CSL-JSON / YAML 文献库可用，但 bib 专有字段（`key`、`langid` 等）自然没有。

## 纯 pandoc 用法

`-L` 必须写在 `--citeproc` **之前**（与 Quarto 相同：先跑 filter，再由 citeproc 生成文献表）：

```bash
pandoc paper.md --bibliography refs.bib -M gbt7714=numeric \
  -L _extensions/gbt7714/gbt7714.lua --citeproc -o paper.docx
```

## 数据规范

与 upstream bst 相同，以下写法不会被纠正，请在 bib 中改好：

- 多位作者只能用 ` and ` 分隔：`author = {张三 and 李四}`。知网等导出的 `张三,李四`、`王五;赵六` 会被当成一个作者。
- 页码范围用 `-` 或 `--`：`pages = {45--67}`。`45~67` 中的 `~` 是 TeX 的不换行空格，会输出成"45 67"。
- 英文文献的标题按 sentence case 转换（与 upstream 相同）。专有名词和缩写要用额外的 `{}` 保护，例如 `title = {A Study of {Python} and {NASA}}`，输出保留 `Python`、`NASA`；包住整个字段值的最外层 `{}` 不算大小写保护。英文 `booktitle` 也遵循这一规则，期刊名保留原有大小写。
- 语言优先看 `langid`/`language`（`chinese`、`zh`、`zh-CN` 等均视为中文；`zh-CN` 这类代码 upstream 视为其他语言，此处按中文处理），没有时按第一个非空字段的文字判断。

