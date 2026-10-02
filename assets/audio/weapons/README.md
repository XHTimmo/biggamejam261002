# 四元素武器音效

12 个原创程序生成 WAV，44.1 kHz、16-bit、单声道。生成器：`python tools/generate_weapon_audio.py`。这些是机械/气流质感的游戏音效原型，未使用外部录音或采样。

| 文件 | 声音设计 |
| --- | --- |
| hydrogen_normal / hydrogen_charged | 轻盈喷气与短促脆响，蓄力气流更长 |
| oxygen_normal / oxygen_charged | 较厚的气压冲击与空气尾音 |
| carbon_normal / carbon_charged | 干燥发射短响与细颗粒抖动 |
| iron_normal / iron_charged | 低沉机械撞击与快速衰减的金属共振 |
| gas_reload | 1.2 秒，机械咔哒、换瓶卡扣、轻微压力泄放 |
| solid_reload | 0.8 秒，卡壳般的拉栓、弹匣插入和棘轮短响 |
| gas_reload_complete / solid_reload_complete | 装填完成的双段锁定声 |

换弹音效采用单独播放器，随当前武器的真实换弹进度播放。切换会停下收起武器的声音，返回后从已完成的位置继续；暂停会冻结音效，BGM 保持播放。射击采用独立四声部，多发技能只触发一次发射声音。

在 `lab_audio.gd` 调整音量：气体射击 −12 dB，固体射击 −10 dB，蓄力增加 1 dB；换弹 −12 dB，完成声 −13 dB。所有素材峰值保留约 3 dB 余量，结尾做短淡出。
