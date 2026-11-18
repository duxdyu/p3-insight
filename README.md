# P3 Insight · 维护版

本文档由AI生成，可能有些地方不清楚，欢迎大家一起完善。项目也是借助AI完成的，如果有熟悉Pascal和Delphi 13的大佬，非常欢迎一起维护！

大航海家3（Patrician III）中文版的游戏内辅助工具，用于查看城镇、物产、船只、商人、船长和贸易路线等信息，并修改部分游戏数据。

本仓库在原作者公开源码基础上继续维护，现在已可在win10上成功编译，并且可以在xp和win10上顺利运行。原始项目介绍、开发背景与旧版配置说明完整保留在 **[README-ORIGIN.md](README-ORIGIN.md)**；原作者的MIT许可证见[LICENSE](LICENSE)。

## 当前版本

本次源码基线为 **2026-11-12**，包含PI主程序与独立启动器：

- 支持自定义游戏可执行文件名、窗口名。
  - 在`PI.ini`中分别设置`Target`（游戏EXE路径）和`WindowTitle`（游戏窗口标题），无需修改源码或重新编译。
  - 支持中文路径、相对路径和绝对路径，工具也可以放在游戏目录以外。
  - 窗口名配置用于匹配游戏已有的窗口标题，不会替游戏修改标题；EXE文件名与窗口标题可以不同。
- 修复Unicode/CP936文本、原生窗口消息、固定宽度数据结构及XP兼容问题。
- 保留当前物产、本地供给和鱼鲸联动逻辑，补充输入与边界检查。
- 改进原生全屏、多屏和P3Modern窗口模式下的定位。
- 修复事务所价格、数量列的编辑与焦点选项。
- 启动器按中文游戏ABI校验目标，等待游戏真正读档就绪后注入，避免XP慢读档时提前注入。

更新明细见[docs/CHANGES.md](docs/CHANGES.md)。

## 使用

运行时目录应保留完整的配套资源：

```text
P3Insight/
  PI模式启动游戏.exe
  p3insight.dll
  InjLib.dll
  PI.ini
  data/
```

`InjLib.dll`和配套`data/`是运行依赖，不由本次源码构建生成；请使用与你的PI版本配套、已获准使用的资源。仓库根目录的历史图片与配置不等同于一套完整的新运行目录。

1. 将`P3Insight`放在游戏目录内，或放在其他位置并设置目标路径。
2. 编辑UTF-8的`PI.ini`，示例见[examples/PI.ini](examples/PI.ini)：

   ```ini
   [Game]
   Target=../Patrician3.exe
   WindowTitle=大 航 海 家 3
   ```

   原生游戏名为`P3.exe`时，将`Target`改为`../P3.exe`。相对路径以启动器目录为准，也可使用绝对路径；不附带命令行参数。

   例如，游戏文件改名为`我的大航海家3.exe`，但窗口标题仍为`大 航 海 家 3`，则配置为：

   ```ini
   [Game]
   Target=../我的大航海家3.exe
   WindowTitle=大 航 海 家 3
   ```

   `WindowTitle`须与游戏实际窗口标题一致，包括标题中的空格；不要直接把EXE文件名当作窗口标题。若游戏版本使用其他标题，填写其实际标题即可。

3. 双击`PI模式启动游戏.exe`，正常进入游戏并读取存档。
4. 读档就绪、注入完成后，按 **F1** 呼出或隐藏PI。

更新已有安装时保留个人`PI.ini`和`data/`设置。启动日志写在工具目录，用于查看目标识别、等待就绪及注入结果。

## 支持范围

对应维护版本已在 **Windows XP SP3、Windows 10** 验证以下三种组合：

| 游戏组合 | 显示模式 |
|---|---|
| 原生中文版EXE，无P3Modern | 原生全屏 |
| 相同中文ABI的专用EXE，无P3Modern文件夹 | 原生全屏 |
| 专用EXE＋P3Modern | 窗口、无边框、全屏 |

P3Modern不是PI的必需依赖。目标识别不再要求整个EXE哈希一致，但仍要求符合已核对的中文内存布局；不表示所有语言版、发行版或任意修改过的EXE都受支持。

历史运行测试覆盖PI六个页面、热键循环、代表性物产修改恢复及自然退出。本次仓库重建验证另见[docs/BUILD-VERIFICATION.md](docs/BUILD-VERIFICATION.md)，不以历史测试替代新编译产物的游戏内验收。

## 从源码构建

**Delphi 13直接打开根目录的 `PI.groupproj`。** 这是当前产品组工程，包含PI DLL和独立启动器，不包含测试工程。

### 1. 首次准备依赖

已验证编译器：Windows上的 **Delphi 13 / RAD Studio 37.0 CE、Win32**。当前工程不是原Delphi 7工程的直接构建方式。

构建前需具备`vendor/`第三方组件源码及`sdk-overlay/Winapi.UIAutomation.pas`。**新克隆仓库后，执行下面一条命令即可从公开上游下载固定组件、应用兼容适配，并从本机Delphi 13 SDK生成overlay。** 已准备好的本机可以直接进入下一步。

各组件的**直接下载链接、固定版本、离线下载步骤，以及Delphi SDK的取得位置**均列在[依赖下载说明](dependencies/README.md)。Python 3.11只用于依赖准备和自动化辅助，Delphi IDE编译本身不依赖Python。

```powershell
$env:BDS = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
python scripts/prepare_dependencies.py --download
```

### 2. 用Delphi 13打开并编译

1. 打开Delphi 13，选择 **File → Open Project**，选择仓库根目录的 **`PI.groupproj`**。
2. 在Project Manager中确认有`p3insight`和`PIProductionLauncher`两个项目，平台为 **Win32**，配置为 **Release**。
3. 在Project Manager对项目组选择 **Build All**，编译两个项目。不要对DLL工程按F9启动调试；编译不需要启动游戏。
4. 在`build/P3Insight/`取得`p3insight.dll`和`PIProductionLauncher.exe`。
5. 手动编译时，将`PIProductionLauncher.exe`复制或改名为`PI模式启动游戏.exe`，并复制`examples/PI.ini`到输出目录；补齐前述`InjLib.dll`和`data/`后才能运行。

只编译PI DLL可单独打开根目录的`p3insight.dproj`；只编译启动器可打开`launcher/PIProductionLauncher.dproj`。根目录其他`.bdsproj`、`.bdsgroup`及附属工具工程属于原仓库历史内容，不是当前产品组入口。

组件无需安装进IDE设计器。手动打开DFM遇到缺类提示时请取消，不要忽略后保存，以免丢失控件。

### 3. 可选：脚本构建与测试

从仓库根目录运行：

```powershell
python scripts/build.py app    # 编译PI DLL和启动器，不运行测试
python scripts/build.py tests  # 编译测试组并运行离线测试
python scripts/build.py all    # 编译产品与测试，再运行离线测试（默认）
```

脚本使用同一套Delphi组工程，在独立且不切换的桌面调用IDE。已打开的IDE确定空闲时，可显式加`--allow-existing-ide`；默认检测到已有编译器会停止。脚本会生成中文命名的启动器及`PI.ini`示例，详细构建日志和收据放在`build/logs/`。

测试也可在IDE中单独打开 **`tests/Tests.groupproj`** 后Build All，输出到`build/tests/`。`XMLHelperTests.exe`、`ABILayoutTests.exe`、`ReadinessTests.exe`验证XML读写、数据布局、物产规则、窗口/配置和注入就绪判断，测试通过会输出`PASS`，不需要游戏进程。`ProfileProbe.exe`是另一个只读诊断工具，需要提供游戏EXE路径参数，不属于无参数自动测试。

依赖准备脚本的独立测试在`tests/scripts/`，运行`python -B -m unittest discover -s tests/scripts -v`；不启动Delphi或游戏。

## 目录为什么这样划分

根目录继续保留PI业务源码和产品工程；**本次新增的测试源码集中在`tests/`，Python脚本集中在`scripts/`**。各目录按用途划分，不是每个目录都要打开或编译。

| 路径 | 内容 |
|---|---|
| 根目录`PI.groupproj` | 日常打开的产品组：PI DLL＋启动器 |
| 根目录`p3insight.dpr/.dproj`及相关单元、DFM | PI DLL业务源码与窗体 |
| `launcher/` | 单独的启动器EXE，与DLL的编译入口分开 |
| `shared/` | 工具共用的物产与本地供给规则，是业务源码 |
| `tests/pi/` | ABI、物产、窗口、配置、DFM和XML离线测试源码 |
| `tests/launcher/` | 就绪判断测试和只读目标检查工具源码 |
| `tests/scripts/` | 依赖下载校验、离线准备及文件保护测试 |
| `scripts/` | 依赖准备与自动构建工具，见下表 |
| `dependencies/` | 第三方来源、版本、文件锁和准备说明，不是组件源码 |
| `docs/` | 更新说明、来源记录与构建验证摘要 |
| `examples/` | 可复制使用的`PI.ini`配置示例 |
| `vendor/`、`sdk-overlay/` | 本机依赖源码，由准备脚本生成，Git忽略 |
| `build/` | 编译结果、测试输出和构建日志，Git忽略 |

| Python脚本 | 用途 |
|---|---|
| `scripts/prepare_dependencies.py` | 从固定上游下载组件、自动应用兼容配方并校验文件锁，从本机Delphi SDK生成XP兼容单元；支持离线ZIP和已有组件目录 |
| `scripts/build.py` | 可选的一键编译、离线测试及产物命名入口 |
| `scripts/build_ide.py` | 供`build.py`调用的IDE驱动，处理本次自有IDE窗口及检查编译结果，不需要单独运行 |

`imgs/`、`maps/`、`sound/`和历史附属工程是原仓库已有内容；`.idea/`、`.xcodemap/`属于本机工具配置。原有`p3insight_test.pas/.dfm`虽然名字含test，但它是主DLL明确引用的历史窗体单元，并非本次新增的离线测试，仍随产品源码保留。

## 许可与第三方依赖

原[MIT许可证](LICENSE)及作者署名保持不变。第三方库、Delphi SDK和游戏资源遵循各自许可，详见[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

`vendor/`、`sdk-overlay/`、`build/`以及本机IDE文件均被Git忽略。SDK兼容单元由脚本从本机安装生成，不修改SDK原件，也不提交其源码。固定上游组件加仓库内的公开兼容配方，已验证可从空目录还原全部14004个依赖文件；仍需用户自己安装Delphi 13。验证记录见[dependencies/COMPATIBILITY.md](dependencies/COMPATIBILITY.md)。
