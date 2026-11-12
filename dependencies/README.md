# 去哪里取得编译依赖

`vendor/`来自公开第三方组件，`sdk-overlay/`来自你本机安装的Delphi 13 SDK。**两个目录都可以按下面的步骤重新生成，不需要维护者电脑上的文件。**

## 推荐：下载并自动准备

安装Python 3.11及Delphi 13后，在仓库根目录执行：

```powershell
python scripts/prepare_dependencies.py --download --bds 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
```

将`--bds`改为你实际的RAD Studio安装目录，也可设置环境变量`BDS`后省略此参数。脚本只使用Python标准库，无需`pip install`。

脚本会依次：

1. 检查本机SDK源文件是否存在。
2. 从下表8个固定地址下载ZIP，并核对每个压缩包的SHA-256。
3. 按项目布局取出需要的文件，应用仓库内公开的5项兼容处理。
4. 逐项核对`vendor-lock.json`的14004个文件，全部通过后生成`vendor/`。
5. 从本机SDK生成`sdk-overlay/Winapi.UIAutomation.pas`，不修改SDK原件。

成功后直接用Delphi 13打开根目录 **`PI.groupproj`**，Win32 / Release → Build All。

下载缓存位于`build/dependency-cache/`；中间文件仅在输出目录下生成。网络失败可再次执行，已校验的下载会复用。已有`vendor/`若与锁不符，脚本会停止，不覆盖个人修改。

## vendor：固定版本与直接下载地址

下载链接也是自动脚本实际使用的地址，完整修订及SHA-256记录在[upstream-sources.json](upstream-sources.json)。请使用这些固定版本，而非各项目最新版本。

| 组件 / 版本 | 下载 | ZIP内取用位置 → vendor目录 |
|---|---|---|
| Virtual TreeView 5.5.3 | [GitHub Release ZIP](https://github.com/JAM-Software/Virtual-TreeView/releases/download/V5.5.3/VirtualTreeViewV5.5.3.zip) | ZIP根 → `vt/` |
| Graphics32 1.9.1 Fixes，`b154583e` | [固定提交ZIP](https://codeload.github.com/graphics32/graphics32/zip/b154583e2859280fed665e6399f9a72ff8feadb4) | `graphics32-<提交>/` → `gr/` |
| GR32 Lines，源码版本3.93 | [作者网站ZIP](https://www.angusj.com/delphi/gr32_lines.zip) | ZIP根 → `lines/`；作者网页标签为3.92，以压缩包哈希为准 |
| OmniXML，`243ba566` | [固定提交ZIP](https://codeload.github.com/mremec/omnixml/zip/243ba5664b55ae74e886c4d7fc35e473b31d479c) | `omnixml-<提交>/` → `xml/` |
| JCL 2.8 Build9330，`1e0df25b` | [固定提交ZIP](https://codeload.github.com/project-jedi/jcl/zip/1e0df25bbe8e41e9f4704635d35777d235f98a97) | `jcl-<提交>/jcl/` → `jcl/` |
| JEDI include，`b33dc0f7` | [固定提交ZIP](https://codeload.github.com/project-jedi/jedi/zip/b33dc0f7b4c3d776d31a391bc34bb2e283e08033) | `jedi-<提交>/` → `jcl/source/include/jedi/` |
| JVCL 3.50，`a8796c9b` | [固定提交ZIP](https://codeload.github.com/project-jedi/jvcl/zip/a8796c9b5948389cbd0acff548c0f7cae689bc9f) | `jvcl-<提交>/jvcl/` → `jvcl/` |
| BarMenus Delphi 10.2 port，`5ca9d1fe` | [固定提交ZIP](https://codeload.github.com/lynxnake/BarMenus/zip/5ca9d1fef5267ee2c779b612e2fd2499a4be76dd) | `BarMenus-<提交>/` → `bm/` |

**只手动解压还不够**：Virtual TreeView、Graphics32、GR32 Lines需要当前项目的兼容适配，JCL需要生成版本配置。脚本会自动完成，具体修改见[COMPATIBILITY.md](COMPATIBILITY.md)和[compatibility.json](compatibility.json)。这些步骤已验证能还原当前完整文件锁。

## 网络受限：浏览器下载后离线准备

在能访问上表链接的机器下载ZIP，然后放入同一目录，按以下名称保存；不要重新打包或改动ZIP内容：

```text
virtual-treeview-5.5.3.zip
graphics32-1.9.1-fixes.zip
gr32-lines-3.92.zip
omnixml-243ba566.zip
jcl-2.8-9330.zip
jedi-include-for-jcl-2.8.zip
jvcl-3.50.zip
barmenus-delphi10.2-port.zip
```

执行：

```powershell
python scripts/prepare_dependencies.py --download --offline --cache '存放上述ZIP的目录' --bds '你的RAD Studio安装目录'
```

离线模式同样执行哈希校验和兼容处理，不需要手工移动ZIP内目录。若网站版本变化导致哈希不符，不要跳过校验或随意更新锁，应先核对上游变更。

## sdk-overlay：从哪里取得Winapi.UIAutomation.pas

它是**Delphi自带的RTL源文件**，不是需要另找的第三方下载。

1. 从[Embarcadero Delphi官网](https://www.embarcadero.com/products/delphi)或你的[Embarcadero授权账户](https://my.embarcadero.com/)取得并安装Delphi 13。安装内容需要包含RTL源代码；本项目不提供编译器或SDK再分发包。
2. 确认安装目录下存在：`source/rtl/win/Winapi.UIAutomation.pas`。标准安装位置通常是：

   ```text
   C:\Program Files (x86)\Embarcadero\Studio\37.0\source\rtl\win\Winapi.UIAutomation.pas
   ```

3. 上述准备命令会复制它，并仅为`UiaReturnRawElementProvider`的external声明增加`delayed`，输出到仓库的`sdk-overlay/`，用于XP兼容。SDK安装目录保持不变。

只想生成SDK overlay时：

```powershell
python scripts/prepare_dependencies.py --sdk-only --bds '你的RAD Studio安装目录'
```

如果提示找不到SDK源，需先检查`--bds`是否指向正确安装根目录，以及安装内容是否包含RTL源码。不要用网上来历不明或不同版本的单元替代。

## 其他用法与许可

已有符合锁的组件目录时，仍可运行`python scripts/prepare_dependencies.py --vendor '已有目录' --bds '安装目录'`。

`--output '另一个空目录'`可将vendor、overlay及缓存完整生成到指定位置，适合隔离验证；默认输出到本仓库。它不是更改Delphi全局Library Path或安装设计期组件的操作。

组件按各自许可使用。尤其BarMenus采用Bluecave Public License 1.1，并非MIT；脚本从固定上游获取，不在本仓库重新托管其完整源码。详见[第三方说明](../THIRD_PARTY_NOTICES.md)。`vendor/`、`sdk-overlay/`及下载缓存都被Git忽略。
