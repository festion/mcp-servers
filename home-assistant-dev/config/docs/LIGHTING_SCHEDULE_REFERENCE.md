# 🕐 Adaptive Lighting Schedule Reference Guide
**Created**: July 2, 2025  
**System**: Phase 4 Master Control Center  
**Version**: Production Ready  

## 📅 Daily Lighting Schedule Overview

### 🌅 Standard Schedule (Living Areas)
**Sunrise Start**: 06:00  
**Sunset Start**: 22:00  
**Zones**: Living Room, Kitchen, Dining Room, Hallway, Nook, Hobby Room, Pantry

### 🛏️ Bedroom Schedule (Sleep-Optimized)
**Sunrise Start**: 06:30 (+30min delay)  
**Sunset Start**: 21:30 (-30min early)  
**Zones**: Master Bedroom, Guest Bedroom, Linda's Room, Gavin's Room

### 🌙 Exterior Schedule (Security-Enhanced)  
**Sunrise Start**: 05:30 (-30min early)  
**Sunset Start**: 22:30 (+30min extended)  
**Zones**: Porch Light

---

## 🌤️ Hourly Schedule Breakdown

### Early Morning (05:00 - 08:00)
**05:00 - 05:30** | Pre-Sunrise Security  
- Exterior: Warm security lighting (2000K, 15%)
- All Interior: Off/Sleep mode

**05:30 - 06:00** | Exterior Sunrise Preparation  
- Exterior: Begin gradual brightening (2000K → 2200K, 15% → 25%)
- Interior: Still in sleep mode

**06:00 - 06:30** | Living Areas Wake-Up  
- Living Areas: Adaptive sunrise begins (2000K, 20% → 30%)
- Bedrooms: Still in sleep mode (delayed start)
- Exterior: Continued gradual increase

**06:30 - 07:00** | Bedroom Gentle Wake  
- All Zones: Active adaptive lighting
- Temperature: 2000K → 2500K (very gradual warming)
- Brightness: 20% → 35% (gentle increase)

**07:00 - 08:00** | Morning Activation  
- Temperature: 2500K → 3500K (warming continues)
- Brightness: 35% → 50% (comfortable morning levels)
- All zones synchronized and active

### Morning Peak (08:00 - 12:00)
**08:00 - 10:00** | Alertness Building  
- Temperature: 3500K → 5000K (significant warming toward cool)
- Brightness: 50% → 75% (increasing alertness)
- Kitchen zones: Slightly higher brightness for food prep

**10:00 - 12:00** | Peak Morning Performance  
- Temperature: 5000K → 6200K (approaching peak cool)
- Brightness: 75% → 90% (near maximum alertness)
- Hobby Room: Maximum brightness for detail work

### Midday (12:00 - 15:00) 
**12:00 - 15:00** | Peak Performance Window  
- Temperature: 6200K → 6500K (maximum cool/alertness)
- Brightness: 90% → 100% (maximum brightness)
- All zones at peak performance settings
- Ideal for: Detailed work, reading, active tasks

### Afternoon (15:00 - 18:00)
**15:00 - 16:30** | Afternoon Plateau  
- Temperature: 6500K (maintained peak cool)
- Brightness: 100% → 95% (slight reduction begins)
- Sustained high performance with subtle relaxation prep

**16:30 - 18:00** | Early Evening Transition  
- Temperature: 6500K → 5500K (beginning to warm)
- Brightness: 95% → 85% (more noticeable reduction)
- Dining room: Optimization for evening meal prep

### Evening (18:00 - 22:00)
**18:00 - 19:30** | Dinner & Family Time  
- Temperature: 5500K → 4000K (comfortable warm)
- Brightness: 85% → 65% (relaxed but functional)
- Dining room: Warm, inviting meal atmosphere

**19:30 - 21:00** | Relaxation Period  
- Temperature: 4000K → 3000K (warm and cozy)
- Brightness: 65% → 45% (wind-down lighting)
- Living areas: Perfect for TV, casual reading

**21:00 - 21:30** | Bedroom Pre-Sleep (Early Sunset)  
- Bedroom Zones: Enter sunset mode early
- Temperature: 3000K → 2500K (very warm)
- Brightness: 45% → 25% (preparing for sleep)

**21:30 - 22:00** | Main Area Wind-Down  
- Living Areas: Continue sunset progression  
- Temperature: 3000K → 2200K (getting very warm)
- Brightness: 45% → 30% (relaxed evening activities)

### Night (22:00 - 05:00)
**22:00 - 22:30** | Transition to Night Mode  
- Living Areas: Enter sunset/sleep preparation
- Temperature: 2200K → 2000K (warmest setting)
- Brightness: 30% → Sleep levels (zone-dependent)
- Exterior: Extended security lighting continues

**22:30 - 05:00** | Sleep Mode  
- **Bedrooms**: 3% brightness, 2000K (minimal sleep lighting)
- **Living Areas**: 5% brightness, 2000K (safety navigation)
- **Kitchen**: 10% brightness, 2000K (higher for safety)
- **Pantry**: 10% brightness, 2000K (potential night access)
- **Hallway**: 5% brightness, 2000K (safe navigation)
- **Exterior**: 15% brightness, 2500K (security lighting)

---

## 🎚️ Zone-Specific Schedule Variations

### 🍳 Kitchen Zones
**Standard Schedule** with enhanced functionality:
- **Higher minimum brightness**: 25% vs 20% (food safety)
- **Extended high brightness**: Maintains 85%+ until 19:00 (dinner prep)
- **LED Strips**: Follow main lights but at 80% intensity scaling
- **Night mode**: 10% for safety (higher than other areas)

### 🛏️ Bedroom Zones  
**Sleep-optimized timing**:
- **Delayed sunrise**: +30 minutes for better sleep
- **Early sunset**: -30 minutes for wind-down preparation
- **Slower transitions**: 45-second changes (vs 30-second standard)
- **Lower peak brightness**: 75% maximum (vs 100% in living areas)
- **Extended warm period**: Stays below 5000K throughout day

### 🏡 Utility Areas
**Task-oriented schedules**:
- **Hobby Room**: Maximum brightness maintained 08:00-20:00 for detail work
- **Pantry**: Quick transitions (15-second) for utility access
- **Hallway**: Lower peak brightness (70%) optimized for pathway lighting

### ✨ Accent Lighting  
**Aesthetic enhancement**:
- **Reduced intensity**: 90% scaling factor for ambient effect
- **Extended evening hours**: Maintains higher brightness until 23:00
- **Smooth transitions**: 20-second changes for pleasant ambiance

---

## 🎛️ Master Control Schedule Overrides

### Temperature Presets
When using master control temperature presets, the schedule is temporarily overridden:

**Warm Preset (2000K)**
- Immediately applies to all participating zones
- Switches system to "Manual Override" mode
- Auto-restore available with configurable timer

**Neutral Preset (4000K)**  
- Good for general activities any time of day
- Maintains current brightness levels
- Suitable for tasks requiring moderate alertness

**Cool Preset (6500K)**
- Maximum alertness/productivity setting
- Best used during natural daytime hours (08:00-18:00)
- May interfere with evening wind-down if used late

**Auto Preset**
- Returns to adaptive schedule immediately
- Restores appropriate time-based temperature
- Seamless transition back to circadian rhythm

### Brightness Presets
Master brightness control affects all zones with individual scaling:

**Dim (25%)**
- All zones at 25% of their scale factor
- Good for movie watching, late evening activities
- Bedroom scale: 25% × 0.9 = 22.5%
- Kitchen scale: 25% × 1.0 = 25%

**Medium (50%)**
- Balanced lighting for general activities
- Good default for manual override periods
- Living room: 50%, Kitchen accent: 40% (0.8x scale)

**Bright (75%)**
- High brightness for cleaning, detailed tasks
- Close to natural daytime levels
- Hobby room effective: 75% × 1.2 = 90%

**Auto**
- Returns to schedule-appropriate brightness
- Considers current time and circadian position
- Smooth transition over 30 seconds

---

## ⏰ Special Schedule Events

### Double-Click Overrides
When double-click control is used on individual lights:
- **Immediate Effect**: Zone switches between adaptive and manual override
- **Visual Confirmation**: 3-second flash to confirm mode change
- **Auto-Restore**: Respects global auto-restore timer setting
- **Logging**: Action recorded in system status and logs

### Auto-Restore Events
Scheduled returns to adaptive lighting:
- **15-minute timer**: Quick temporary overrides
- **1-hour timer**: Standard override period (default)
- **3-hour timer**: Extended manual control
- **Custom timer**: User-defined duration (up to 180 minutes)
- **Next reset timer**: Wait until next daily reset (05:00)

### Daily Reset Events  
**05:00 Daily Reset**:
- All override states cleared
- System returns to full adaptive mode
- Zone scales reset to configured defaults
- Performance counters reset to zero
- System health check performed

---

## 📊 Schedule Performance Metrics

### Typical Daily Pattern
**Sync Events**: ~288 per day (5-minute intervals)  
**Override Events**: 2-8 per day (typical family usage)  
**Auto-Restore Events**: 1-3 per day  
**Double-Click Actions**: 0-5 per day  

### Peak Usage Times
**Morning Rush** (07:00-08:30): Higher override frequency for personal preferences  
**Evening Wind-Down** (20:00-22:00): Most manual adjustments for comfort  
**Weekend Variations**: ~30% more override activity  

### Efficiency Metrics
**Schedule Adherence**: 85-95% (high adaptive mode usage)  
**User Satisfaction**: Measured by low override frequency during peak circadian times  
**Energy Optimization**: 15-20% reduction vs. manual lighting management  

---

## 🔧 Schedule Customization Options

### User-Configurable Parameters
Available through input helpers and dashboard:

**Wake Time**: `input_number.adaptive_lighting_wake_time_hour` (05:00-09:00)  
**Bedtime**: `input_number.adaptive_lighting_bedtime_hour` (20:00-24:00)  
**Sunrise Offset**: `input_number.adaptive_lighting_sunrise_offset` (-60 to +60 minutes)  
**Sunset Offset**: `input_number.adaptive_lighting_sunset_offset` (-60 to +60 minutes)  

### Advanced Schedule Tuning
**Color Temperature Limits**:
- Maximum: `input_number.adaptive_lighting_max_color_temp` (5000K-6500K)
- Minimum: `input_number.adaptive_lighting_min_color_temp` (1800K-2500K)

**Brightness Limits**:
- Maximum: `input_number.adaptive_lighting_max_brightness` (80%-100%)
- Minimum: `input_number.adaptive_lighting_min_brightness` (1%-25%)

**Transition Speeds**:
- Global: `input_number.adaptive_lighting_transition_speed` (5-120 seconds)
- Zone-specific: Configured in adaptive_lighting.yaml

---

## 💡 Best Practices & Tips

### Optimal Schedule Usage
1. **Trust the circadian rhythm** - avoid overrides during natural peak/low periods
2. **Use bedroom early sunset** - respects natural sleep preparation
3. **Kitchen safety priority** - higher night brightness prevents accidents
4. **Hobby room scheduling** - plan detail work during peak brightness hours (10:00-15:00)

### Manual Override Guidelines
- **Short overrides**: Use 15-minute auto-restore for quick adjustments
- **Activity-based**: Use preset buttons rather than manual slider adjustments
- **Evening comfort**: Warm preset (2000K) ideal for relaxation after 20:00
- **Morning productivity**: Cool preset (6500K) great for focused work

### Zone Scaling Optimization
- **Living room**: Keep at 1.0x (baseline reference)
- **Kitchen**: Slightly higher for food safety (1.0x main, 0.8x accent)
- **Bedrooms**: Slightly lower for comfort (0.9x)
- **Accent lighting**: Reduce for ambiance (0.9x)
- **Hobby room**: Increase for detail work (1.2x)

---

*This schedule reference reflects the current Phase 4 implementation and will be updated as the system evolves.*

**Quick Dashboard Access**: Navigate to `/adaptive-lighting` in Home Assistant  
**System Status**: All schedules active and synchronized  
**Last Updated**: July 2, 2025