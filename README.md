# 东晋十六国

《欧陆风云 IV》历史向大型模组，目标是表现东晋与十六国并立时期的政权竞争、人口迁徙、族群整合、门阀政治与南北秩序重建。

项目目前处于工程骨架阶段，尚未提供可玩的历史开局。年代范围、首个开局日期和首个垂直切片将在史料与玩法边界确认后冻结。

## 开发基线

- 工作名称：东晋十六国
- 当前版本：0.1.0
- 游戏基线：EU4 1.37.x（暂沿用参考项目，升级前需单独验证）
- 本地化：仅简体中文
- 首要目标：冻结历史范围、地图方案与第一个可玩场景

设计入口见 [docs/README.md](docs/README.md)，实施进度与验收标准见 [ROADMAP.md](ROADMAP.md)。

## 目录约定

```text
common/                  国家、文化、宗教、政体、机制与通用脚本
decisions/               决议
docs/                    世界观、地区、国家、机制与开发文档
events/                  事件
gfx/flags/               国家旗帜
history/                 国家、省份、外交与战争历史
localisation_source/     可读的 UTF-8 BOM 简体中文本地化源码
localisation/            游戏运行时本地化
missions/                任务树
tools/                   开发辅助脚本
vanilla/                 指向本机 EU4 原版的可选开发链接（Git 忽略）
reference/               本地史料与参考素材（Git 忽略）
descriptor.mod           模组内描述文件
ROADMAP.md               当前阶段、优先级与验收标准
```

玩家可见文本必须使用本地化键。中文源码使用汉化模组占用的 `l_english` 语言槽；`*_l_english.yml` 是引擎文件名，不代表维护英文文本。

## 开发命令

生成运行时本地化并执行静态检查：

```powershell
pwsh -NoProfile -File .\tools\build-localisation.ps1
pwsh -NoProfile -File .\tools\validate-mod.ps1
```

将仓库以目录联接安装到 Paradox Launcher：

```powershell
pwsh -NoProfile -File .\tools\install-dev-link.ps1
```

安装脚本会创建 `mod\sixteen_kingdoms_dev` 目录联接和对应的外部 `.mod` 描述文件，不会复制开发文件。
