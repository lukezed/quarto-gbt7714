# quarto-gbt7714

**为中文学术写作的 Quarto 模板提供可复用的 GB/T 7714—2025 引用与参考文献接口。** 如果你正在维护某个学校的学位论文模板，或将现有 LaTeX 模板接入 Quarto，可以复用这里的 Lua filter 和 CSL，在自己的封面、章节与排版配置中加入中文引用支持。

在你的模板项目根目录安装：

```bash
quarto add lukezed/quarto-gbt7714
```

在 `_quarto.yml` 中加入：

```yaml
lang: zh
bibliography: references.bib
filters: [gbt7714]
gbt7714: authoryear  # 也支持 numeric、note
```

现有封面、章节和排版配置继续由你的模板管理。[完整接入说明](docs/citations.md)

## 为什么使用这个扩展

[Zeping Lee 的 gbt7714-bibtex-style](https://github.com/zepinglee/gbt7714-bibtex-style) 提供 LaTeX／BibTeX 引用方案。如果模板只输出 LaTeX PDF，已经使用它就可以继续沿用。

本库面向 **Quarto 模板需要复用原生引用流程，或同时输出 Word、HTML、PDF** 的场景：

- 通过 `quarto add` 安装，以 Lua filter 和 CSL 接入 Pandoc citeproc。
- 同一套 `.qmd` 引文和文献库可用于多种输出，无需分别维护 BibTeX 与 Word／HTML 的引用配置。
- 默认引用流程不调用上游 `.bst` 或 BibTeX；Word、HTML 不需要 TeX 环境，PDF 排版仍需要。

本库的规则和测试参考上游 BibTeX 实现，CSL 派生自 [zotero-chinese/styles](https://github.com/zotero-chinese/styles)。它们是这个项目的基础；这里补的是 Quarto 接口与多格式适配。已有 `natbib`／`biblatex` 配置需切换到 citeproc 才会使用本扩展，详见[适配指南](docs/citations.md)。

灵感来自 [apaquarto](https://github.com/wjschne/apaquarto)：希望中文学术写作也能方便地接入 Quarto。本库还附带可直接使用的单栏稿件、双栏文章和课程作业模板，作为写作起点与接入示例。

## 当前状态与反馈

**当前版本：[v0.1.0-beta.1](https://github.com/lukezed/quarto-gbt7714/releases/tag/v0.1.0-beta.1)，供试用的预发布版本。** 现阶段的优化和 bug 排查，主要通过 AI loop 迭代完成：构造用例、渲染输出、与上游结果对照、审查问题，再修改并做回归检查。

这样做的主要原因是：**我暂时没有实际的中文学术写作需求**，还没有用它长期完成一篇中文论文。现有测试能覆盖不少格式和边界情况，但不能代替真实写作。

欢迎大家试用，并通过 [Issues](https://github.com/lukezed/quarto-gbt7714/issues) 告诉我遇到的问题。长文档、复杂文献库、不同模板和投稿流程中，很多问题只有真正重度使用后才会出现。反馈时最好附上最小可复现的 `.qmd`、相关 `.bib` 条目、输出格式、Quarto 版本，以及预期与实际结果的截图。

当前已在 Quarto 1.10.18／Pandoc 3.10 环境验证三套模板的 Word、PDF、HTML 渲染与匿名输出；引用结果也有逐条对照测试。[使用限制](docs/citations.md#适用范围与限制)与[已知差异](docs/development.md#已知差异)见文档。

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

投稿版借鉴 APA 稿件的页面组织：独立标题页 → 独立摘要与关键词页 → 正文新页（重复论文标题），参考文献也另起一页。正文 12pt，PDF 与 Word 使用 25pt 正文行距。引用格式仍为 GB/T，完整排版参数见[写作指南](docs/writing.md#字号与行距)。

| 标题页 | 摘要页 | 正文首页 |
|---|---|---|
| ![投稿稿标题页](docs/images/manuscript.png) | ![投稿稿摘要页](docs/images/manuscript-abstract.png) | ![投稿稿正文首页](docs/images/manuscript-body.png) |

</details>

<details>
<summary>匿名 journal 预览</summary>

![匿名 journal 首页，隐藏作者与机构，保留摘要和正文引用](docs/images/journal-blind.png)

</details>

## 直接使用写作模板

安装 [Quarto](https://quarto.org/docs/get-started/) 与 Python 3。PDF 另需含 `ctex` 和 Fandol 字体的 TeX Live／TinyTeX。

```bash
git clone https://github.com/lukezed/quarto-gbt7714.git
cd quarto-gbt7714
python3 tools/new_project.py manuscript ../my-paper
cd ../my-paper
quarto render
```

将 `manuscript` 换成 `student` 或 `journal` 即可选择其他模板。修改 `paper.qmd` 和 `refs.bib` 后渲染，结果在 `_output/`；匿名版运行 `quarto render --profile blind`，结果在 `_output-blind/`。匿名开关隐藏作者元数据和标记区块，正文与图片里的身份线索仍需自行检查。

## 详细文档

- [写作指南](docs/writing.md)：模板配置、字号与行距、匿名稿。
- [引用与模板适配](docs/citations.md)：引文写法、Word／PDF、Quarto book、natbib 与限制。
- [开发与测试](docs/development.md)：实现原理、回归检查、已知差异。

## License

见 `LICENSE`：代码 MIT；CSL 文件 CC BY-SA 3.0（派生自 [zotero-chinese/styles](https://github.com/zotero-chinese/styles)，原作者 Zeping Lee）；`test/upstream/` 为 LPPL 1.3c（[zepinglee/gbt7714-bibtex-style](https://github.com/zepinglee/gbt7714-bibtex-style)）。
