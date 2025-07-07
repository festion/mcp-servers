# Adaptive Lighting Configuration Guide

## Overview

Adaptive Lighting is a Home Assistant integration that dynamically adjusts your lights' color temperature and brightness throughout the day to match natural sunlight patterns and support circadian rhythms. This document outlines our implementation and configuration choices.

## Features

### Core Functionality
- **Dynamic Color Temperature**: Automatically shifts from warm evening light (2200K) to cool daylight (5500K)
- **Brightness Control**: Adjusts light intensity based on time of day 
- **Circadian Rhythm Support**: Follows natural human biological patterns
- **Sleep Mode**: Reduces blue light before bedtime for better sleep quality
- **Customizable Settings**: Per-room configurations for different use cases

### Key Benefits
- Better alignment with natural circadian rhythms
- Improved sleep quality through reduced blue light in evenings
- Enhanced productivity with brighter, cooler light during work hours
- Energy efficiency by dimming lights at appropriate times
- Seamless automation requiring no manual adjustments

## Room Configurations

Each room has specific configuration tailored to its use case and lighting needs:

### Living Room
- **Purpose**: General living space, relaxation, and entertainment
- **Hours**: 6:00 AM to 10:30 PM
- **Color Temperature Range**: 2200K (warm) to 5500K (cool)
- **Brightness Range**: 20% to 100%
- **Sleep Settings**: 10% brightness, 2000K after 10:30 PM
- **Transitions**: 30 seconds for smooth changes

### Bedroom
- **Purpose**: Sleep preparation, rest, and morning wake-up
- **Hours**: 6:30 AM to 9:00 PM
- **Color Temperature Range**: 2000K (very warm) to 4500K (neutral)
- **Brightness Range**: 10% to 80%
- **Sleep Settings**: 5% brightness, 1800K after 9:00 PM
- **Transitions**: 45 seconds for extra-gentle changes

### Office
- **Purpose**: Work focus, productivity, and video conferences
- **Hours**: 7:00 AM to 8:00 PM
- **Color Temperature Range**: 2700K (warm) to 5500K (cool)
- **Brightness Range**: 30% to 100%
- **Sleep Settings**: 15% brightness, 2200K after 8:00 PM
- **Transitions**: 20 seconds for responsive changes

### Kitchen
- **Purpose**: Food preparation, dining, and family gatherings
- **Hours**: 6:00 AM to 8:00 PM
- **Color Temperature Range**: 2700K (warm) to 5000K (neutral-cool)
- **Brightness Range**: 25% to 100%
- **Sleep Settings**: 15% brightness, 2200K after 8:00 PM
- **Transitions**: 20 seconds for responsive changes

## Daily Light Pattern

The system creates the following light experience throughout the day:

1. **Early Morning (5-7 AM)**: Gentle, warm light to ease waking
2. **Morning (7-10 AM)**: Gradually cooling light to increase alertness
3. **Midday (10 AM-2 PM)**: Bright, cool light for maximum productivity
4. **Afternoon (2-5 PM)**: Slowly warming light as day progresses
5. **Evening (5-8 PM)**: Warmer light to start relaxation
6. **Late Evening (8-10 PM)**: Very warm, dimming light for sleep preparation
7. **Night (10 PM-5 AM)**: Minimal, ultra-warm light for any nighttime activity

## Manual Controls and Overrides

The system respects user manual adjustments:

- **Manual Overrides**: When you manually adjust a light, the system will respect your setting until the next major transition point
- **Switch Controls**: Regular light switches still function normally
- **Voice Commands**: You can request specific scenes via voice assistants

## Future Enhancements

Planned improvements to the adaptive lighting system:

1. **Lux Sensor Integration**: Adjusting brightness based on ambient light levels
2. **Occupancy-Based Control**: Adapting to presence in different rooms
3. **Activity Recognition**: Optimizing lighting for specific activities
4. **Personal Preferences**: Individual user profiles with preferred settings

## Technical Implementation

The configuration is implemented using Home Assistant's Adaptive Lighting integration installed through HACS, with room-specific settings defined in the configuration.yaml file.

For further details on all available configuration options, refer to the [Adaptive Lighting documentation](https://github.com/basnijholt/adaptive-lighting).