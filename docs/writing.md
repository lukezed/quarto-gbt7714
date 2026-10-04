# 写作模板使用指南

[返回首页](../README.md)

## 环境准备

- 安装 [Quarto](https://quarto.org/docs/get-started/)。HTML 和 Word 输出不依赖 LaTeX。
- PDF 输出需要 XeLaTeX 与含 `ctex`、Fandol 字体的 TeX Live／TinyTeX；写作模板默认使用 Fandol，避免依赖特定操作系统字体。
- Word 模板使用宋体、黑体与 Times New Roman；本机缺少字体时，显示效果取决于编辑器的字体替代。
- 使用下面的项目创建脚本需要 Python 3；直接安装扩展并手写 `.qmd` 不需要 Python。

## 写作起步模板

除了可独立使用的引用 filter，本仓库还提供可编辑的学生作业、投稿初稿与双栏文章模板。排版由独立的 `gbt7714-paper` 扩展提供；它调用同一套 GB/T 引用实现。模板中的页面、字体和章节设置是通用起点，学校或期刊有明确要求时请据其调整。

| 模板 | 使用场景 | PDF / HTML | Word |
|---|---|---|---|
| `student` | 课程论文、读书报告、学生作业 | 单栏，包含学号、课程、指导教师 | 可编辑单栏 |
| `manuscript` | 投稿初稿、导师审阅 | 独立标题页、摘要页、正文；HTML 分区，打印时分页 | 同样分页，正文 25pt 行距 |
| `journal` | 期刊风格文章、成稿展示 | PDF 双栏；HTML 宽屏双栏、窄屏单栏 | 可编辑单栏 |

源文件分别在 [student](../templates/student/paper.qmd)、[manuscript](../templates/manuscript/paper.qmd)、[journal](../templates/journal/paper.qmd)。先克隆或下载仓库：

```bash
git clone https://github.com/lukezed/quarto-gbt7714.git
cd quarto-gbt7714
```

从仓库根目录选择一种模板，创建带全部扩展文件的独立项目。此步骤只需 Python 3 标准库，不会改动已有目录：

```bash
python3 tools/new_project.py student /path/to/my-assignment
python3 tools/new_project.py manuscript /path/to/my-manuscript
python3 tools/new_project.py journal /path/to/my-journal-paper
```

进入新项目，修改 `paper.qmd` 的题目、作者和正文，将 `refs.bib` 换成实际使用的文献，然后运行：

```bash
quarto render                       # HTML、PDF、Word，位于 _output/
quarto render --to gbt7714-paper-pdf # 只输出 PDF
quarto render --profile blind       # 匿名版，位于 _output-blind/
```

PDF 需要 XeLaTeX 与 `ctex`。每个模板都保留正文引文、页码和表格交叉引用示例；投稿稿与双栏稿还包含图示和公式示例。示例数据仅用于排版演示，请替换后使用。Word 使用相同正文与参考文献，采用单栏便于审阅。双栏 PDF 的表格按单栏宽度排版并浮动，需能放入一页；跨页长表请使用 `manuscript` 单栏版。

若已有 Quarto 项目，只需安装本仓库的扩展并选择格式：

```yaml
format:
  gbt7714-paper-html: default
  gbt7714-paper-pdf: default
  gbt7714-paper-docx: default
paper-style: journal  # student | manuscript | journal
bibliography: refs.bib
gbt7714: authoryear   # numeric | note 也可
```

这些写作格式已经加载引用 filter，无需再添加 `filters: [gbt7714]`。只需要引用适配的项目，继续使用下文的 `filters: [gbt7714]` 即可。

### 投稿稿的页面结构

选择 `paper-style: manuscript` 后，PDF 和 Word 会自动生成标题页、摘要页和正文分页，无需在 `.qmd` 正文中手写分页符。摘要页包含 `abstract` 和 `keywords`；不提供二者时直接进入正文，不生成空摘要页。匿名稿保留标题页及分页结构，隐藏作者和机构。HTML 按相同顺序分区，浏览器打印时分页。

### 匿名稿

在项目配置中设 `blind: true`，或使用模板附带的 `--profile blind`，即可隐藏结构化作者、机构、邮箱、ORCID、学号及课程信息。致谢、资助或其他需要在匿名版隐藏的内容放进 `.nonblind` 区块：

```markdown
::: {.nonblind}
# 致谢 {.unnumbered}

这里填写作者致谢和资助信息。
:::
```

也支持 `.author-only` 区块。`blind: false` 或不设置时，正常显示这些信息。此开关处理作者元数据和显式标记的区块，保留参考文献与自引；正文叙述、图片、文件名及外部链接中的身份线索仍需作者自行检查。


## 字号与行距

以下是随附写作模板的默认排版参数，可按学校或期刊要求调整。

| 模板 | PDF 正文字号 | PDF 行距配置 | Word 正文 |
|---|---|---|---|
| student | 12pt | `linestretch: 1.5` | 12pt、1.5 倍 |
| manuscript | 12pt | 固定 25pt | 12pt、25pt（最小值） |
| journal | 10pt | `linestretch: 1.05` | 12pt、1.5 倍、单栏 |

投稿稿正文采用 12pt、25pt（最小值） 行距、段间距 0；HTML 使用接近的屏幕阅读行高。不同输出格式的字体和分页仍可能略有差异。

当前 `paper-style` 会设置 PDF 的 `fontsize` 与 `linestretch`；仅在 YAML 覆盖这两项不会生效。需要精确版式时，应修改项目内 `_extensions/gbt7714-paper/layout.lua` 与 `paper.tex`，Word 则修改 `paper-reference.docx` 的对应样式；已有学校模板可以只接入引用扩展。

