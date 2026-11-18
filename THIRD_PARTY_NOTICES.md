# 第三方来源与许可

根目录`LICENSE`保留原作者`Copyright (c) 2024 KKY`的MIT许可证。本次未修改原许可证或添加其他作者署名。第三方组件、SDK和游戏素材按各自声明处理，不因位于PI仓库而统一改为MIT。

| 依赖 | 原声明 / 处理方式 |
|---|---|
| Virtual TreeView 5.5.3 | MPL1.1 / LGPL2.1-or-later |
| Graphics32 1.9.1 fixes | MPL1.1 / LGPL2.1及链接例外，以逐文件声明为准 |
| GR32 Lines | MPL1.1 |
| OmniXML及其辅助单元 | 按逐文件MPL1.1或多重许可声明 |
| JCL / JVCL | 主要MPL1.1，附属组件另有各自许可 |
| BarMenus Delphi 10.2 port | Bluecave Public License 1.1，含限制性再分发条款，依赖源不随本次更新提交 |
| Winapi.UIAutomation | Embarcadero SDK，兼容副本仅在本机生成，不提交 |
| InjLib.dll | 原README指向《Windows核心编程》配套程序；`runtime/InjLib.dll`由用户指定的现代版2.1运行目录补入，仅作为二进制运行依赖保留，不改署名或许可 |

版本、直接下载URL和文件锁见`dependencies/`。本仓库提供最小兼容处理配方，保留原文件版权/许可，具体范围见`dependencies/COMPATIBILITY.md`；BarMenus无本地补丁，按固定上游版本取得。

原仓库中的历史编辑器、Catchy32、HookApi、LDE32等文件保留原样；当前PI组工程不引用这些历史组件，也不为其补写或变更许可。原有图片、音效和其他资源的权利归属仍按各自来源处理。

2026-11-18补入的运行资源来自用户指定的“Patrician III 现代版2.1/P3Insight”目录：`InjLib.dll`、5个XML和3个城市图标。另6个资源直接复用仓库已有图片和音效。`runtime/manifest.json`记录来源路径、发布路径和逐文件SHA-256；这些文件不因加入仓库而取得新的许可或作者归属。
