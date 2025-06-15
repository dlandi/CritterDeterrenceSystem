# Meadow-Based Living Room Camera Unit UML Design

## Component Architecture

The living room unit combines motion detection with evidence capture, using Meadow F7's processing power to coordinate PIR sensors, strobe deterrents, and camera recording through sophisticated GPIO management.

```plantuml
@startuml LivingRoom_Component_Diagram
!define RECTANGLE class

title Living Room Unit - Component Architecture

package "Meadow F7 Hardware" {
  [STM32F7 MCU] as MCU
  [ESP32 WiFi] as ESP32
  [GPIO Pins] as GPIO
  [SPI/I2C Bus] as BUS
}

package "Sensors" {
  [PIR Motion Sensor] as PIR
  [Ambient Light Sensor] as ALS
}

package "Deterrents & Capture" {
  [Evictor Strobe Light] as STROBE
  [IP Camera Module] as CAMERA
  [IR Illuminators] as IR
}

package "Interface Hardware" {
  [DPDT Relay Module] as RELAY
  [Camera Trigger Interface] as TRIG
  [Level Shifters] as LEVEL
  [SD Card Storage] as SD
}

package "Software Components" {
  [Motion Detection Service] as MDS
  [Camera Controller] as CC
  [Image Processing] as IP
  [Cloud Service] as CS
  [State Manager] as SM
  [Storage Manager] as STG
}

' Hardware connections
MCU --> GPIO
MCU --> BUS
GPIO --> LEVEL
LEVEL --> RELAY
RELAY --> STROBE
RELAY --> TRIG
TRIG --> CAMERA
CAMERA --> IR

PIR --> GPIO : Interrupt
ALS --> BUS : I2C
SD --> BUS : SPI

ESP32 <--> MCU : SPI
ESP32 <--> CS : WiFi/MQTT

' Software connections
MDS --> PIR : Monitor
MDS --> SM : Events
SM --> CC : Capture
CC --> CAMERA : Control
CC --> IP : Process
IP --> STG : Store
STG --> SD : Write
CS <--> SM : Sync
CS --> STG : Upload

@enduml
```

![LivingRoom_Component_Diagram](diagrams/LivingRoom_Component_Diagram.png)

The component architecture prioritizes evidence capture with local storage redundancy. The camera trigger interface converts Meadow's 3.3V signals to camera-compatible dry contacts. The ambient light sensor enables intelligent IR illuminator control, activating only when needed to avoid overexposure. Image processing occurs on-device for motion detection zones and preliminary threat assessment before cloud upload.

## Class Structure

The object model emphasizes image capture and processing capabilities while maintaining the modular deterrent architecture established in the attic unit.

```plantuml
@startuml LivingRoom_Class_Diagram
title Living Room Unit - Class Architecture

interface IImageCapture {
  + CaptureAsync() : Task<byte[]>
  + StartRecording(duration: TimeSpan) : Task
  + StopRecording() : Task
  + bool IsRecording
}

interface IImageProcessor {
  + DetectMotion(image: byte[]) : MotionRegions
  + CompressImage(image: byte[]) : byte[]
  + GenerateThumbnail(image: byte[]) : byte[]
}

class LivingRoomApp {
  - IMotionSensor motionSensor
  - IImageCapture camera
  - IImageProcessor processor
  - List<IDeterrent> deterrents
  - StorageService storage
  + override Initialize() : Task
  + override Run() : Task
  - ProcessMotionEvent() : Task
}

class IpCameraModule {
  - HttpClient httpClient
  - string rtspUrl
  - bool isRecording
  + CaptureAsync() : Task<byte[]>
  + StartRecording(duration: TimeSpan) : Task
  + StopRecording() : Task
  + TriggerSnapshot() : Task
  - StreamToFile(filename: string) : Task
}

class CameraTriggerInterface {
  - IDigitalOutputPort triggerPort
  - TimeSpan pulseWidth
  + SendTriggerPulse() : Task
  + SetPulseWidth(width: TimeSpan) : void
}

class MotionZoneProcessor {
  - Rectangle[] zones
  - byte[] previousFrame
  + DetectMotion(image: byte[]) : MotionRegions
  + ConfigureZones(zones: Rectangle[]) : void
  - CalculateDifference(current: byte[], previous: byte[]) : int
}

class StorageService {
  - IFileSystem fileSystem
  - Queue<ImageRecord> uploadQueue
  - long maxStorageBytes
  + SaveImage(data: byte[], metadata: CaptureMetadata) : Task
  + SaveVideo(stream: Stream, metadata: CaptureMetadata) : Task
  + GetPendingUploads() : Task<List<ImageRecord>>
  - ManageStorageSpace() : Task
}

class CloudUploadService {
  - HttpClient httpClient
  - string apiEndpoint
  - int maxRetries
  + UploadImageAsync(record: ImageRecord) : Task
  + UploadVideoAsync(record: VideoRecord) : Task
  - CompressForUpload(data: byte[]) : byte[]
}

class IrIlluminatorControl {
  - IDigitalOutputPort irPort
  - IAmbientLightSensor lightSensor
  + bool IsActive
  + EnableAutoMode() : void
  + SetManualMode(active: bool) : void
  - CheckLightLevel() : Task<bool>
}

class CaptureMetadata {
  + DateTime Timestamp
  + MotionRegions Regions
  + double AmbientLight
  + int SequenceNumber
  + TimeSpan Duration
}

' Relationships
LivingRoomApp --> IMotionSensor
LivingRoomApp --> IImageCapture
LivingRoomApp --> IImageProcessor
LivingRoomApp --> StorageService

IpCameraModule ..|> IImageCapture
IpCameraModule --> CameraTriggerInterface
MotionZoneProcessor ..|> IImageProcessor

StorageService --> CloudUploadService
StorageService --> CaptureMetadata
LivingRoomApp --> IrIlluminatorControl

@enduml
```

![LivingRoom_Class_Diagram](diagrams/LivingRoom_Class_Diagram.png)

The class structure separates image capture from processing, enabling different camera types through the `IImageCapture` interface. The `MotionZoneProcessor` implements intelligent motion detection within defined regions, reducing false triggers from areas like windows. The `StorageService` manages limited SD card space through rolling deletion of uploaded content. Cloud upload occurs asynchronously with retry logic for network failures.

## Evidence Capture Sequence

The sequence demonstrates coordinated capture with pre-event buffering, ensuring complete documentation of intrusion attempts.

```plantuml

@startuml LivingRoom_Sequence_Diagram
title Living Room Unit - Motion Detection and Evidence Capture

actor Squirrel
participant "PIR Sensor" as PIR
participant "Motion Service" as MS
participant "State Machine" as SM
participant "Camera" as CAM
participant "IR Lights" as IR
participant "Strobe" as STROBE
participant "Storage" as STORE
participant "Cloud" as CLOUD

== Pre-Buffer Recording ==
loop Every 5 seconds
  CAM -> CAM : Capture frame
  CAM -> STORE : Save to ring buffer
end

== Motion Detection ==
Squirrel -> PIR : Enters room
PIR -> MS : Interrupt signal
activate MS
MS -> SM : FireAsync(MotionStart)
deactivate MS

activate SM
SM -> IR : CheckLightLevel()
IR -> IR : Read ambient sensor

alt Low light detected
  SM -> IR : Activate()
  activate IR
end

SM -> CAM : StartRecording(60s)
activate CAM
CAM -> STORE : Lock pre-buffer
CAM -> CAM : Begin HD recording

SM -> STROBE : ActivateAsync(30s)
activate STROBE

par Evidence Collection
  CAM -> STORE : Stream video
  activate STORE
  
  loop Every 2 seconds
    CAM -> CAM : Capture snapshot
    CAM -> STORE : Save image
  end
else Cloud Notification
  SM -> CLOUD : PublishEvent(motion)
  activate CLOUD
  CLOUD -> CLOUD : Notify attic unit
  CLOUD -> CLOUD : Alert user app
  deactivate CLOUD
end

...30 seconds...
STROBE -> STROBE : Auto-stop
deactivate STROBE

...60 seconds...
CAM -> CAM : Stop recording
deactivate CAM
STORE -> STORE : Finalize video
deactivate STORE

SM -> CLOUD : UploadEvidence()
activate CLOUD
CLOUD -> STORE : GetPendingFiles()
STORE -> CLOUD : Transfer files
deactivate CLOUD

deactivate IR
deactivate SM

@enduml

```

![LivingRoom_Sequence_Diagram](diagrams/LivingRoom_Sequence_Diagram.png)

The sequence implements a sophisticated capture strategy with continuous pre-buffering ensuring events leading to motion detection are recorded. The 5-second ring buffer captures approach behavior before PIR triggering. Parallel processing handles evidence collection while maintaining real-time deterrent activation. High-resolution snapshots every 2 seconds provide clear identification even if video compression affects quality. Cloud upload occurs after local storage to prevent network delays from affecting capture.

## State Management

The state machine incorporates capture-specific states while maintaining compatibility with the broader security system architecture.

```plantuml
@startuml LivingRoom_State_Diagram
title Living Room Unit - Camera System State Machine

[*] --> Initializing : Power On

state Initializing {
  [*] --> CameraCheck
  CameraCheck : Verify camera connection
  CameraCheck --> StorageCheck : Camera OK
  StorageCheck : Verify SD card
  StorageCheck --> NetworkInit : Storage OK
  NetworkInit --> [*]
}

Initializing --> Idle : Init Complete
Initializing --> LocalMode : Network Fail

state Idle {
  [*] --> PreBuffering
  PreBuffering : 5-second loop
  PreBuffering : Low-res capture
}

state Armed {
  [*] --> ActiveMonitoring
  ActiveMonitoring : PIR enabled
  ActiveMonitoring : Full sensitivity
}

Idle --> Armed : Arm Command
Armed --> Idle : Disarm Command

Armed --> CaptureSequence : Motion Detected

state CaptureSequence {
  [*] --> LockBuffer
  LockBuffer : Save pre-event
  
  LockBuffer --> StartRecording
  StartRecording : HD video + audio
  
  StartRecording --> ActiveCapture
  state ActiveCapture {
    [*] --> RecordingVideo
    RecordingVideo --> SnapshotCapture : 2s timer
    SnapshotCapture --> RecordingVideo : Continue
    
    RecordingVideo : Stream to SD
    SnapshotCapture : High-res still
  }
  
  ActiveCapture --> ProcessingEvidence : 60s complete
  ProcessingEvidence : Generate metadata
  ProcessingEvidence : Create thumbnail
}

CaptureSequence --> UploadPending : Processing complete

state UploadPending {
  [*] --> QueueFiles
  QueueFiles --> Uploading
  
  state Uploading {
    [*] --> TransferVideo
    TransferVideo --> TransferImages
    TransferImages --> UpdateCloud
  }
  
  Uploading --> [*] : Success
  Uploading --> RetryQueue : Failure
}

UploadPending --> Cooldown : Upload complete
UploadPending --> Cooldown : Timeout

state Cooldown {
  Cooldown : 30s minimum
  Cooldown : Low-res only
}

Cooldown --> Armed : Timer expires

state LocalMode {
  LocalMode : No cloud sync
  LocalMode : Store locally only
  LocalMode : Auto-delete old files
}

LocalMode --> Idle : Network restored

@enduml
```

![LivingRoom_State_Diagram](diagrams/LivingRoom_State_Diagram.png)

The state machine balances evidence quality with storage constraints. Pre-buffering states maintain a rolling window of low-resolution footage without filling storage. The capture sequence ensures all evidence is secured before attempting uploads, preventing data loss from network issues. Local mode provides degraded but functional operation during internet outages, with intelligent storage management preventing SD card overflow.

## Physical Deployment

The deployment layout optimizes camera coverage while maintaining discrete installation appropriate for living spaces.

```plantuml
@startuml LivingRoom_Deployment_Diagram
title Living Room Unit - Physical Installation Layout

node "Wall Mount (Entry View)" as WallMount {
  component "Sensor Package" as SENSORS {
    [PIR Sensor]
    [Light Sensor]
    [Status LED]
  }
  
  component "Camera Assembly" as CAM_ASSY {
    [IP Camera]
    [IR LED Array]
    [Privacy Shutter]
  }
}

node "Ceiling Corner" as Ceiling {
  component "Meadow Control Unit" as CONTROL {
    [Meadow F7v2]
    [Interface Board]
    [Power Regulation]
  }
  
  component "Strobe Housing" as STROBE_H {
    [Evictor Strobe]
    [Diffusion Lens]
    [Thermal Management]
  }
}

node "Network Closet" as Closet {
  component "Infrastructure" as INFRA {
    [PoE Switch]
    [Network Router]
    [Backup Battery]
  }
  
  component "Storage NVR" as NVR {
    [4TB Drive]
    [RTSP Server]
    [Web Interface]
  }
}

node "User Devices" as Users {
  [Smartphone App]
  [Web Dashboard]
  [Alexa Integration]
}

cloud "Meadow.Cloud" as CLOUD {
  [Evidence Storage]
  [AI Analysis]
  [Alert Service]
}

' Connections
SENSORS ..> CONTROL : "Low voltage\n4-wire cable"
CAM_ASSY ..> CONTROL : "Trigger wire"
CAM_ASSY ..> INFRA : "Cat6 PoE"
CONTROL ..> STROBE_H : "Relay control"
INFRA ..> NVR : "Gigabit LAN"
CONTROL ..> INFRA : "WiFi 2.4GHz"

Users ..> CLOUD : "Mobile/Web"
CLOUD ..> CONTROL : "MQTT commands"
NVR ..> CLOUD : "Backup sync"

note right of CAM_ASSY : 7ft height\n130° coverage\nAvoid windows

note left of STROBE_H : Corner mount\nIndirect bounce\nNo direct eye exposure

note bottom of INFRA : UPS protection\n4-hour runtime

@enduml
```

![LivingRoom_Deployment_Diagram](diagrams/LivingRoom_Deployment_Diagram.png)

Living room deployment requires aesthetic considerations alongside functionality. Wall-mounted sensors blend with modern home decor while maintaining optimal detection angles. The camera's 7-foot mounting height prevents tampering while providing comprehensive room coverage. Privacy shutters address resident concerns about continuous monitoring. Strobe positioning uses indirect lighting to avoid disorienting residents while maintaining effectiveness against intruders. Network infrastructure in a separate closet reduces electromagnetic interference and provides physical security for recording equipment. The PoE camera connection simplifies installation while providing reliable power and data through a single cable.
