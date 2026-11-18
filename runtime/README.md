# 运行资源

`manifest.json`定义完整运行包中16个非编译文件的来源、发布路径和SHA-256。再加上本次构建的主DLL和启动器，共18个文件；不包含使用说明、MAP、DCU或调试符号。

资源基线来自用户指定的“Patrician III 现代版2.1/P3Insight”，于2026-11-18逐文件核对。构建只读取本仓库，不依赖该外部目录。

已有且内容相同的6个文件直接复用：

| 仓库来源 | 发布路径 |
|---|---|
| `maps/map.png` | `data/images/map.png` |
| `maps/blue-button.png` | `data/images/s-city-icon-blue.png` |
| `maps/red-blue-button.png` | `data/images/s-city-icon-red-blue.png` |
| `maps/red-button.png` | `data/images/s-city-icon-red.png` |
| `imgs/mod-star-10x10.bmp` | `data/images/star-10x10.bmp` |
| `sound/SYKOFONE.wav` | `data/sounds/SYKOFONE.wav` |

此前缺失的`InjLib.dll`、5个XML、3个城市图标存放在本目录；`examples/PI.ini`保留参考版的原始内容。`InjLib.dll`为现有运行依赖的二进制副本，本仓库不编译它。第三方文件仍按原始来源许可处理，见根目录`THIRD_PARTY_NOTICES.md`。

`.gitattributes`禁用这些资源的换行转换，避免Git的`autocrlf`设置改变XML/INI字节、导致克隆后的清单校验失败。

运行`python -B scripts/build.py app --bds "Delphi安装目录"`即可编译并校验完整的`build/p3-insight/`。更新资源时同时更新清单中的SHA-256。输出目录属于构建产物，重复构建会覆盖清单内文件；个人运行配置应保存在部署目录。输出中有清单外文件时脚本会停止，避免删除用户文件。
