# l4d2-aim-down-sight

添加更多activity可用在V模中

### ConVars
> ads_holding_key "0"  // Enable in ads by holding the zoom key.  
> ads_pellet_scatter_modifier "0.5"  // Pellet scatter modifier while in ads.  
> ads_recoil_modifier "0.5"  // Recoil modifier while in ads.  
> ads_spread_modifier "0.1"  // Spread modifier while in ads.

### Activities list:
- ACT_VM_RELOAD				193 // 正常换弹夹  
- ACT_VM_RELOAD_EMPTY			180 // 空膛换弹夹  
- ACT_VM_DEPLOY				179 // 正常拔出武器  
- ACT_VM_DRAW					181 // 空膛拔出武器上膛（一般为捡起后的动画）  
- ACT_VM_HOLSTER				182 // 收起武器  
- ACT_VM_FIDGET				184 // 检视  
- ACT_VM_IDLE						183  // 正常待机  
- ACT_VM_DRYFIRE					194  // 最后一发子弹打掉时转空仓挂机的动画  
- ACT_VM_IDLE_LOWERED				212  // 空仓挂机  
- ACT_VM_PRIMARYATTACK_LAYER		1252 // 开火  
### Aim down sight activities list:  
- ACT_PRIMARY_VM_IDLE_TO_LOWERED		1879 // 进入机瞄  
- ACT_PRIMARY_VM_IDLE					1873 // 机瞄-正常待机  
- ACT_PRIMARY_VM_DRYFIRE				1878 // 机瞄-最后一发子弹打掉时转空仓待机的动画  
- ACT_PRIMARY_VM_IDLE_LOWERED			1880 // 机瞄-空仓待机  
- ACT_PRIMARY_VM_PRIMARYATTACK		1875 // 机瞄-开火
- ACT_PRIMARY_VM_SECONDARYATTACK		1876 // 机瞄-推
- ACT_PRIMARY_VM_RELOAD				1877 // 机瞄-换弹
- ACT_PRIMARY_VM_LOWERED_TO_IDLE		1881 // 退出机瞄  

致MOD作者关于机瞄的制作说明：  
需要在正常开火动画中（ACT_VM_PRIMARYATTACK_LAYER）使用delta
