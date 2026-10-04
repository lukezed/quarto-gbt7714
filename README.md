# quarto-gbt7714

面向中文学术写作的 Quarto 扩展：提供 **GB/T 7714—2025 引用与参考文献适配**，以及学生作业、投稿初稿和双栏文章模板，同一份源文件可以输出 Word、PDF 和 HTML。

## 为什么做这个项目

这个项目的灵感来自 [apaquarto](https://github.com/wjschne/apaquarto)。它把 APA 写作格式接入 Quarto，让作者可以在同一个写作流程中生成不同格式的文档。我也希望中文写作能有类似的体验：写正文、管理文献，再按需要输出文件。

在尝试把这个流程用于中文学术写作时，我没有找到能直接满足自己设想的组合：中文引用格式、多种输出，以及方便其他模板接入的 Quarto 接口。因此做了这个库，希望把 GB/T 7714 的引用规则接到 Quarto 的 Lua／CSL 工作流中，并提供几套可以直接开始写的模板。

引用实现参考了 [zepinglee/gbt7714-bibtex-style](https://github.com/zepinglee/gbt7714-bibtex-style)，CSL 源自 [zotero-chinese/styles](https://github.com/zotero-chinese/styles)。现有中文参考文献工具是这个项目的基础；本库重点处理它们在 Quarto 多格式写作中的衔接。

## 可以用来做什么

- **学生作业**：课程论文、读书报告等，填好姓名、学号、课程信息后即可开始写，最后提交 Word 或 PDF。
- **论文写作与投稿**：用单栏稿件与导师、合作者交流，也可以输出双栏 journal 风格的 PDF。考虑到投稿时可能需要 Word，而不能直接提交 PDF 或 LaTeX，本库同时保留可编辑的 Word 输出；实际版式仍需按目标期刊要求调整。
- **学校或期刊模板的引用适配**：例如 [ECNU 学位论文模板](https://github.com/sy5938/ecnu_thesis_markdown_template) 这样的项目，可以接入独立的 Lua filter 和 CSL，让引用处理沿用 Quarto 的 citeproc 流程。模板作者可以继续维护自己的封面、章节与页面布局，复用这里的中文引用功能。

仓库提供两部分：`gbt7714` 是可独立使用的引用扩展；`gbt7714-paper` 是调用它的写作排版扩展。学生、作者和模板维护者可以按需要选择。

## 当前状态与反馈

**目前处于 beta 阶段。** 现阶段的优化和 bug 排查，主要通过 AI loop 迭代完成：构造用例、渲染输出、与上游结果对照、审查问题，再修改并做回归检查。

这样做的主要原因是：**我暂时没有实际的中文学术写作需求**，还没有用它长期完成一篇中文论文。现有测试能覆盖不少格式和边界情况，但不能代替真实写作。

欢迎大家试用，并通过 [Issues](https://github.com/lukezed/quarto-gbt7714/issues) 告诉我遇到的问题。长文档、复杂文献库、不同模板和投稿流程中，很多问题只有真正重度使用后才会出现。反馈时最好附上最小可复现的 `.qmd`、相关 `.bib` 条目、输出格式、Quarto 版本，以及预期与实际结果的截图。

当前已在 Quarto 1.10.18／Pandoc 3.10 环境验证三套模板的 Word、PDF、HTML 渲染与匿名输出；引用结果也有逐条对照测试。[使用限制](docs/citations.md#适用范围与限制)与[已知差异](docs/development.md#已知差异todo)见文档。

## 示例与预览

以下截图来自仓库内模板的实际渲染。页面中的作者、机构、正文和数据用于演示，请在写作时替换。

| 模板 | 源文件 | 完整 PDF |
|---|---|---|
| 学生作业 | [student/paper.qmd](templates/student/paper.qmd) | [查看示例](docs/previews/student.pdf) |
| 投稿初稿 | [manuscript/paper.qmd](templates/manuscript/paper.qmd) | [查看示例](docs/previews/manuscript.pdf) |
| 双栏 journal | [journal/paper.qmd](templates/journal/paper.qmd) | [查看示例](docs/previews/journal.pdf) |
| 匿名 journal | [blind 配置](templates/journal/_quarto-blind.yml) | [查看示例](docs/previews/journal-blind.pdf) |

### 双栏 journal

标题、作者、机构和摘要跨栏，正文双栏；包含图、表、公式及 GB/T 引文示例。HTML 在宽屏上也使用双栏，Word 保持单栏便于修改。

![双栏 journal 模板首页](docs/images/journal.png)

<details>
<summary>学生作业预览</summary>

![学生作业模板首页，含姓名、学号、课程与教师信息](docs/images/student.png)

</details>

<details>
<summary>投稿初稿预览</summary>

投稿版借鉴 APA 稿件的页面组织：独立标题页 → 独立摘要与关键词页 → 正文新页（重复论文标题），参考文献也另起一页。正文 12pt；PDF 设为 `linestretch: 2`，Word 使用双倍行距。引用格式仍为 GB/T，完整排版参数见[写作指南](docs/writing.md#字号与行距)。

| 标题页 | 摘要页 | 正文首页 |
|---|---|---|
| ![投稿稿标题页](docs/images/manuscript.png) | ![投稿稿摘要页](docs/images/manuscript-abstract.png) | ![投稿稿正文首页](docs/images/manuscript-body.png) |

</details>

<details>
<summary>匿名 journal 预览</summary>

![匿名 journal 首页，隐藏作者与机构，保留摘要和正文引用](docs/images/journal-blind.png)

</details>

## 快速开始

安装 [Quarto](https://quarto.org/docs/get-started/) 与 Python 3。PDF 另需含 `ctex` 和 Fandol 字体的 TeX Live／TinyTeX。

```bash
git clone https://github.com/lukezed/quarto-gbt7714.git
cd quarto-gbt7714
python3 tools/new_project.py manuscript ../my-paper
cd ../my-paper
quarto render
```

将 `manuscript` 换成 `student` 或 `journal` 即可选择其他模板。修改 `paper.qmd` 和 `refs.bib` 后渲染，结果在 `_output/`；匿名版运行 `quarto render --profile blind`，结果在 `_output-blind/`。匿名开关隐藏作者元数据和标记区块，正文与图片里的身份线索仍需自行检查。

### 已有 Quarto 项目

运行 `quarto add lukezed/quarto-gbt7714`，再添加：

```yaml
lang: zh
bibliography: refs.bib
filters: [gbt7714]
gbt7714: authoryear  # 也支持 numeric、note
```

## 详细文档

- [写作指南](docs/writing.md)：模板配置、字号与行距、匿名稿。
- [引用与模板适配](docs/citations.md)：引文写法、Word／PDF、Quarto book、natbib 与限制。
- [开发与测试](docs/development.md)：实现原理、回归检查、已知差异。

## License

见 `LICENSE`：代码 MIT；CSL 文件 CC BY-SA 3.0（派生自 [zotero-chinese/styles](https://github.com/zotero-chinese/styles)，原作者 Zeping Lee）；`test/upstream/` 为 LPPL 1.3c（[zepinglee/gbt7714-bibtex-style](https://github.com/zepinglee/gbt7714-bibtex-style)）。
