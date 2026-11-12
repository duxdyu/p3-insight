# 2026-11-12 维护更新

## PI主程序

- 移植当前维护版的Unicode/CP936文本处理、固定宽度ABI与原生窗口消息兼容。
- 保留20种物产、本地供给和鱼鲸三态联动逻辑，覆盖无效输入及越界边界。
- 支持独立原生全屏定位、P3Modern窗口对齐及多屏可见区域处理。
- 恢复事务所价格、数量列的编辑/焦点选项，保留玩家与事务所权限判定。
- 配置和资源按PI自身目录定位。

## 独立启动器

- 读取相邻`PI.ini`，支持相对路径、绝对路径和中文路径。
- 按既有中文游戏的ABI合同核对目标，不再绑定整个EXE的哈希。
- 等待有效游戏页、world对象和主循环推进后注入，修复XP慢读档时过早注入。
- 保留PID/窗口核对、固定DLL路径、回绕安全计时和日志。

## 工程与验证

- 保持根目录PI业务源码布局，独立启动器在`launcher/`、共用规则在`shared/`。
- 离线测试集中到`tests/pi/`和`tests/launcher/`，Python脚本集中到`scripts/`，构建日志写到`build/logs/`。
- Delphi 13 Win32工程采用仓库相对路径；产品统一打开根目录`PI.groupproj`，测试单独打开`tests/Tests.groupproj`。
- 第三方组件外置并记录来源与文件锁，SDK overlay在本机生成。
- 原始README原样保存为`README-ORIGIN.md`；历史附属工具及原许可证保留。

验证范围与本次仓库重建记录见[BUILD-VERIFICATION.md](BUILD-VERIFICATION.md)。

## 2026-11-13 公开依赖准备

- 补齐8个固定上游ZIP的直接下载地址、缓存命名及解压映射。
- 公开5项最小兼容处理配方，自动生成当前文件锁对应的依赖。
- `scripts/prepare_dependencies.py --download`支持联网准备；`--offline --cache`支持浏览器下载后离线处理。
- 明确SDK来自用户安装的Delphi 13，overlay只在本地生成。
- 空目录联网重建14004项vendor身份通过，8项脚本边界测试通过；本轮未启动Delphi或游戏。
