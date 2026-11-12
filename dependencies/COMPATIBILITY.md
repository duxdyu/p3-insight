# 公开依赖的兼容处理

`compatibility.json`记录当前构建基线相对上游的最小处理配方，由`scripts/prepare_dependencies.py`应用。原始ZIP按`upstream-sources.json`中的SHA-256校验；修改前后按配方和`vendor-lock.json`再次校验。

| 文件 | 处理 |
|---|---|
| `gr/Source/GR32_Compiler.inc` | 新版Delphi沿用XE3功能宏基线 |
| `lines/GR32_Lines.pas` | `Clear`允许派生类覆盖，并明确数学/矩形函数所属单元 |
| `lines/GR32_Misc.pas` | 明确数学/矩形函数所属单元，避免新版RTL重名 |
| `vt/Source/VirtualTrees.pas` | 兼容历史DFM的`hsXPStyle`及PI逐单元格绘制事件；保留已验证基线的UTF-8 BOM与历史换行形式 |
| `jcl/source/include/jcld37win32.inc` | 直接复制上游`jcl.template.inc`，生成Delphi 13 Win32默认配置 |

其余13999个文件与对应上游ZIP内容完全相同。BarMenus没有本地兼容补丁，按固定上游版本下载。

配方中的`old`/`new`是按Latin-1可逆表示的字节片段，用来准确保留已有文件编码和换行，并非重新发布整个库。Virtual TreeView先按标明的编码步骤转换，再应用片段。输入哈希、唯一匹配上下文或输出哈希不符时停止，不猜测替换。

Virtual TreeView原版权属于digital publishing AG、Mike Lischke及其他贡献者，原声明为MPL1.1 / LGPL2.1-or-later；Graphics32按原MPL1.1 / LGPL2.1及链接例外声明；GR32 Lines原作者Angus Johnson，按原MPL1.1声明。生成文件保留其原版权与许可头，兼容改动沿用相应文件原许可，不将第三方代码统一改为PI的MIT。许可原文见各上游包与[MPL 1.1](https://www.mozilla.org/MPL/1.1/)。

## 验证

2026-11-13，从8个公开地址重新下载ZIP，在空目录中完成布局、兼容处理和SDK overlay生成。生成的全部14004个vendor文件与此前实际通过Delphi 13编译的依赖文件锁逐字节一致，SDK overlay也与已验证版本一致。

本轮验证的是公开依赖取得链和文件身份，未再次启动Delphi或游戏。脚本边界测试另外覆盖错误下载/缓存哈希、补丁上下文不符、路径越界、失败时不发布半成品、已有用户修改保护、离线重建和SDK原件不变。详情见`../docs/DEPENDENCY-VERIFICATION.json`。
