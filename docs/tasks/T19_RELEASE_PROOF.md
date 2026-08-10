# T19 发布检查与运行证明

## 目标

完成发布配置、干净环境回归、导出 smoke test 和 15-20 秒真实运行证明，交付一个可以继续开发和实际游玩的 Godot/GDScript 项目。

## 依赖

- T18 completed。

## 交付范围

- `export_presets.cfg`：至少目标 PC/Windows preset；当前开发机可运行 preset 按已安装模板配置。
- 最终 README：运行、控制、功能、架构入口、存档位置、已知限制、资源许可。
- `screenshots/final/` 关键截图和最终证明视频/帧序列；该目录可有 `.gdignore`，不得把 `.gdignore` 放到 assets。
- 最终测试/日志/导出报告与完整 STATUS。

## 实现要求

1. 从干净导入缓存验证项目；不删除用户数据，测试使用全新临时 user data 位置/测试槽。
2. 运行 full unit/integration/E2E，完成 Test Plan 所有门和性能检查。
3. 检查 project settings、主场景、InputMap、Autoload、bus layout、export include/exclude、窗口缩放和 debug feature。
4. 导出包不含 docs 参考仓库、本机绝对路径、测试存档、临时帧、godot-ai server 或开发插件运行产物。
5. 在导出包或等价 release run 中 smoke：启动、移动、一次农事、save/load、退出；不能只验证编辑器运行。
6. 最终证明使用固定 seed/起始状态，仅用键盘真实连续展示移动、Toolbar/Itembar 选择与头顶高亮、翻地/播种/浇水、采集/拾取、方向焦点背包交换和次日成长/转场中的至少一个。
7. 录制帧率固定、全窗内容可见；录制后回看并确认非空、不卡死、非单帧循环、无 debug overlay 和严重音画问题。
8. README 明确本项目是基于机制参考的原创 Godot 重建，并标明核心参考提交；不声称复制/官方移植。

## 自动化验收

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --quit
godot --headless --path . --export-release "Windows Desktop" build/my_farm.exe
```

实际可执行文件名和 host smoke 命令写入 STATUS。若缺导出模板，安装正确模板后再验收，不能用空文件代替成功导出。

## godot-ai 验收

- editor_state/scene hierarchy/project settings 最终快照正确。
- 主场景完整流程 game_status `live`，editor/game logs 零错误。
- 使用 input_sequence 驱动证明场景；截图/视频由运行中 game framebuffer 获得。
- 结束后 stop，再读一次日志确认退出干净。

## 发布清单

- [ ] 全测试通过，无未解释 skip。
- [ ] 三地图、两 NPC、6 工具、Toolbar/Itembar、纯键盘背包、唯一手持、作物闭环、时间、存档可用。
- [ ] 两视口无模糊、遮挡、越界和错误文字。
- [ ] 20 次转场/10 次保存/100 Item 稳定。
- [ ] `assets/licenses/ASSETS.md` 完整。
- [ ] 导出包可启动并完成 smoke。
- [ ] 最终视频已回看，路径可访问。
- [ ] STATUS 没有未披露 blocker。

## 完成记录

STATUS 写 Godot/version、export preset/产物、全测试摘要、最终 run_id、日志、截图/视频绝对路径和残余风险；总表 T19 completed，项目里程碑 M4 达成。
