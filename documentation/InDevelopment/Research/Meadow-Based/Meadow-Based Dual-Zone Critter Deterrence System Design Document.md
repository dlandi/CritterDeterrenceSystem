# Meadow-Based Dual-Zone Critter Deterrence System Design Document

## Executive Summary

This document details the complete hardware and software design for a cloud-connected, dual-zone critter deterrence system using the Wilderness Labs Meadow platform. The system deploys two coordinated units: a living room camera unit for evidence capture and an attic deterrent unit for active intrusion prevention. Both units leverage Meadow F7v2 boards with .NET programming and Meadow.Cloud for orchestration.

## System Architecture Overview

### Core Components
- **Living Room Unit**: Motion detection, evidence capture (video/images), strobe deterrent, cloud upload
- **Attic Unit**: Motion detection, strobe light, klaxon horn, remote activation capability
- **Cloud Platform**: Meadow.Cloud for device management, event coordination, and evidence storage
- **User Interface**: Mobile app notifications, web dashboard, Alexa integration

### Communication Architecture
- Local: GPIO interrupts, SPI/I2C for sensors
- Network: WiFi via ESP32 coprocessor, MQTT for real-time events
- Cloud: REST APIs for configuration, MQTT for commands, HTTPS for evidence upload

## Hardware Design Specifications

### Living Room Unit Hardware

#### Core Processing
- **Meadow F7v2 Feather** (STM32F7 216MHz, 32MB RAM, 64MB Flash)
- **ESP32 Coprocessor** for WiFi connectivity
- **SD Card Module** (minimum 32GB) for video buffering

#### Sensors
- **Parallax PIR Sensor** (28032) - 120° detection angle, 30ft range
- **VEML7700 Ambient Light Sensor** (I2C) for IR illuminator control
- **Status LED** (RGB) for system state indication

#### Camera System
- **IP Camera Module** with RTSP support (e.g., ESP32-CAM or Raspberry Pi Camera)
- **IR LED Array** (850nm, 12x 100mA LEDs) with MOSFET driver
- **Camera Trigger Interface** using optocoupler for dry contact

#### Deterrents
- **Evictor 10K Strobe Light** (175mA @ 12V)
- **DPDT Relay Module** (2-channel, 10A contacts) for strobe control
- **Level Shifters** (3.3V to 5V) for relay interfacing

#### Power System
- **12V 3A Power Supply** for strobe and IR illuminators
- **5V 2A Buck Converter** for Meadow and camera
- **1000µF Capacitor Bank** for strobe inrush current

### Attic Unit Hardware

#### Core Processing
- **Meadow F7v2 Feather** (identical to living room unit)
- **Project Lab Board** (optional) for local display/control

#### Sensors
- **Parallax PIR Sensor** (28032) with weatherproof housing
- **DS18B20 Temperature Sensor** for environmental monitoring

#### Deterrents
- **Evictor 10K Strobe Light** with heat shield
- **Honeywell 748 Klaxon** (118dB, 280mA @ 12V)
- **Shelly 1PM Smart Relay** for klaxon control (WiFi backup)

#### Power Distribution
- **GFCI Breaker** (15A) for code compliance
- **12V 5A Transformer** for combined deterrent power
- **Terminal Block Distribution** with fused outputs

#### Environmental Protection
- **NEMA 4X Enclosure** for electronics
- **Conformal Coating** on PCBs for humidity protection
- **Cable Glands** for sealed wire entry

### Network Infrastructure

#### Required Components
- **WiFi Router** with 2.4GHz support
- **WiFi Range Extender** for attic coverage
- **PoE Switch** (optional) for camera power
- **UPS Battery Backup** (minimum 500VA)

## Software Architecture

### Core Software Stack

#### Operating System Layer
- **Meadow.OS** v1.10+ with hardware abstraction
- **Real-time interrupt handling** for PIR sensors
- **Watchdog timer** for system reliability

#### Application Framework
```csharp
// Base application structure
public class MeadowApp<T> : App<T>
{
    protected IMotionSensor motionSensor;
    protected List<IDeterrent> deterrents;
    protected ICloudService cloudService;
    protected StateMachine stateMachine;
}
```

### Living Room Unit Software

#### Key Services
1. **Motion Detection Service**
   - Hardware interrupt processing
   - Software debouncing (100ms)
   - Zone-based filtering

2. **Camera Control Service**
   - Pre-buffer management (5-second ring buffer)
   - HD recording activation (1080p @ 15fps)
   - Snapshot capture (2-second intervals)

3. **Image Processing Service**
   - Motion region detection
   - JPEG compression
   - Thumbnail generation

4. **Storage Management Service**
   - SD card space monitoring
   - Rolling deletion of uploaded content
   - Evidence metadata tracking

5. **Cloud Upload Service**
   - Asynchronous batch uploads
   - Retry logic with exponential backoff
   - Bandwidth throttling

#### State Machine States
- Initializing → Idle → Armed → MotionDetected → CaptureSequence → UploadPending → Cooldown

### Attic Unit Software

#### Key Services
1. **Deterrent Controller**
   - Strobe pattern management (1Hz flash rate)
   - Klaxon duration limiting (10 seconds max)
   - Power sequencing logic

2. **Remote Command Service**
   - MQTT subscription for activation commands
   - Local override capability
   - Command validation

3. **Environmental Monitoring**
   - Temperature logging
   - Overheat protection (>60°C shutdown)

#### State Machine States
- Initializing → Idle → Armed → MotionDetected → DeterrentsActive → Cooldown

### Shared Components

#### Cloud Communication Module
```csharp
public interface ICloudService
{
    Task ConnectAsync();
    Task PublishEventAsync(MotionEvent evt);
    Task<CloudCommand> ReceiveCommandAsync();
    Task UploadEvidenceAsync(byte[] data, EvidenceMetadata metadata);
}
```

#### Configuration Management
- JSON-based configuration files
- Runtime parameter updates via cloud
- Local fallback values

#### Logging System
- Structured logging with severity levels
- Local buffering with cloud sync
- Diagnostic data collection

## Communication Protocols

### Device-to-Cloud (MQTT)
- **Topics Structure**:
  - `devices/{deviceId}/telemetry` - Health metrics
  - `devices/{deviceId}/events` - Motion events
  - `devices/{deviceId}/commands` - Control messages
  - `devices/{deviceId}/config` - Configuration updates

### Inter-Device Coordination
- Living room publishes: Motion detection events
- Attic subscribes: Deterrent activation commands
- Latency target: <500ms end-to-end

### Evidence Upload (HTTPS)
- Multipart form upload for images/video
- Chunked transfer for large videos
- Signed URLs for secure storage

## Installation Requirements

### Living Room Installation
1. Wall mount at 7ft height with 130° room coverage
2. Avoid direct sunlight or heat sources
3. Ensure clear WiFi signal path
4. Professional electrical work for 120V connections

### Attic Installation
1. PIR sensor 6-8ft high with entry point visibility
2. Central strobe positioning for maximum coverage
3. Weatherproof all connections
4. Adequate ventilation for electronics

### Network Configuration
1. Static IP assignments for reliability
2. Port forwarding for camera RTSP (optional)
3. MQTT broker connection (port 8883)
4. Firewall exceptions for cloud communication

## Performance Specifications

### Response Times
- PIR interrupt to deterrent activation: <50ms
- Motion event to cloud notification: <200ms
- Cloud command to attic activation: <500ms
- Evidence upload completion: <30s for 60s video

### Storage Requirements
- Pre-buffer: 5MB (5 seconds @ 720p)
- Per-event video: 120MB (60 seconds @ 1080p)
- Per-event images: 30MB (15 images @ 2MB each)
- Total SD capacity: 32GB minimum

### Power Consumption
- Living Room Unit: 15W peak, 3W idle
- Attic Unit: 40W peak (with klaxon), 2W idle
- Annual energy cost: ~$25 @ $0.12/kWh

## Security Considerations

### Device Security
- Signed firmware with secure boot
- Encrypted configuration storage
- API key rotation every 90 days

### Network Security
- WPA2/WPA3 WiFi encryption
- TLS 1.3 for all cloud communication
- Certificate pinning for MQTT

### Privacy Protection
- Local processing of video (no cloud streaming)
- Configurable retention policies
- Manual privacy shutter on camera

## Maintenance Requirements

### Routine Maintenance (Monthly)
- Clean PIR sensor lenses
- Verify strobe operation
- Check SD card health
- Review cloud connectivity logs

### Preventive Maintenance (Annual)
- Replace backup batteries
- Update firmware
- Clean electrical contacts
- Recalibrate PIR sensitivity

This design provides a production-ready architecture for a sophisticated critter deterrence system leveraging modern IoT capabilities while maintaining reliability and security.