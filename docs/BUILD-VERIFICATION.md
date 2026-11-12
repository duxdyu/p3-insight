# 当前仓库重建验证

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
