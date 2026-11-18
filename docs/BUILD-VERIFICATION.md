# 当前仓库重建验证

## 2026-11-18：完整运行目录构建

使用Delphi 13 CE / RAD Studio 37.0执行：

```powershell
python -B scripts/build.py app --bds 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
```

主DLL和启动器编译成功，脚本自动生成`build/p3-insight/`。与用户指定的现代版2.1运行目录逐文件核对：除可省略的`使用说明.txt`外，18个文件的相对路径完全一致。16个非编译文件SHA-256完全一致；两个新编译二进制仅PE时间戳字段不同，归零这些字段后逐字节一致。未修改二进制来匹配参考哈希。

资源审计确认6个配套文件在原仓库中已有相同内容，现通过清单映射复用；缺少的5个XML、3个城市图标及`InjLib.dll`已补入`runtime/`。构建不再读取外部游戏目录。资源清单为`runtime/manifest.json`，本机验证收据为`build/logs/PI-build-result.json`、`package-result.json`和`reference-comparison.json`。

打包的4项自动测试通过，覆盖重复组装、缺失资源、编译产物变更和额外用户文件保护。本轮未启动游戏，未修改参考目录，也未重新执行下方历史游戏功能验证。

## 2026-11-12：原构建与离线测试记录

2026-11-12，使用Delphi 13 / RAD Studio 37.0 CE、Win32、Python 3.11，在当前仓库根目录运行：

```powershell
python scripts/build.py all --allow-existing-ide
```

## 结果

- 产品组`PI.groupproj`：`p3insight.dll`及独立启动器实际编译成功。
- 测试组`tests/Tests.groupproj`：`XMLHelperTests.exe`、`ABILayoutTests.exe`、`ReadinessTests.exe`和只读`ProfileProbe.exe`实际编译成功。
- XML测试：必填/默认/空值、兄弟节点、布尔/整数/字节及UTF-8往返通过。
- ABI与PI测试：布局/字符串边界、原生ANSI消息、20种物产、本地供给、220项原生边界、历史路线/城市结构、窗口定位、配置路径及324对象DFM加载通过。
- 启动器：142项生产就绪检查通过。

目录重排后已重新构建以上两组并运行离线测试，路径迁移通过验证。构建在自有私有桌面进行，没有切换桌面；自有IDE出现保存确认时选择不保存。未操作用户已打开的IDE。完整输出身份和测试文本见`BUILD-VERIFICATION.json`，本机详细收据在`build/logs/`，由Git忽略。

本轮只在该仓库重建和执行离线测试，未启动游戏或部署这些新编译产物。历史XP SP3/Win10三场景验收属于对应发布版本，不作为此次新编译文件的运行验收，也不声明重建与历史发布文件逐字节一致。

最新产品源码取自2026-11-12已整理基线；合入仓库时仅调整项目布局、SDK/测试资源路径及两处行尾空白。后续目录重排只迁移测试和脚本并调整引用，未改业务逻辑。来源记录见`SOURCE-BASELINE.json`。原README内容逐字节保留为根目录`README-ORIGIN.md`，原LICENSE保持不变。
