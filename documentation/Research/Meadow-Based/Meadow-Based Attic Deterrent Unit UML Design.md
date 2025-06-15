# Meadow-Based Attic Deterrent Unit UML Design

## Component Architecture

The attic unit leverages Meadow F7's GPIO capabilities to control high-power deterrents through relay interfaces, with cloud connectivity enabling remote management and coordination with other units.

```plantuml
@startuml Attic_Component_Diagram
!define RECTANGLE class

title Attic Unit - Component Architecture

package "Meadow F7 Hardware" {
  [STM32F7 MCU] as MCU
  [ESP32 WiFi] as ESP32
  [GPIO Pins] as GPIO
  [Power Management] as PWR
}

package "Sensors" {
  [PIR Motion Sensor] as PIR
  [Temperature Sensor] as TEMP
}

package "Deterrents" {
  [Evictor Strobe Light] as STROBE
  [Honeywell Klaxon] as KLAXON
}

package "Interface Hardware" {
  [DPDT Relay Module] as RELAY
  [Shelly Smart Relay] as SHELLY
  [12V Transformer] as TRANS
  [Level Shifters] as LEVEL
}

package "Software Components" {
  [Motion Detection Service] as MDS
  [Deterrent Controller] as DC
  [Cloud Service] as CS
  [State Manager] as SM
  [Power Monitor] as PM
}

' Hardware connections
MCU --> GPIO
GPIO --> LEVEL
LEVEL --> RELAY
RELAY --> STROBE
RELAY --> SHELLY
SHELLY --> TRANS
TRANS --> KLAXON

PIR --> GPIO : Interrupt
TEMP --> GPIO : I2C

ESP32 <--> MCU : SPI
ESP32 <--> CS : WiFi/MQTT

' Software connections
MDS --> PIR : Monitor
MDS --> SM : Events
SM --> DC : Commands
DC --> RELAY : Control
DC --> SHELLY : Control
CS <--> SM : Sync
PM --> PWR : Monitor

@enduml
```

![Attic_Component_Diagram](diagrams/Attic_Component_Diagram.png)

This component diagram illustrates the hardware abstraction layers and software services. The Meadow F7's GPIO pins interface with sensors and control relays through level shifters to handle voltage differences. The ESP32 coprocessor manages network connectivity independently, ensuring reliable cloud communication. Software components follow a service-oriented architecture with clear separation between detection, control, and communication responsibilities.

## Class Structure

The object-oriented design leverages C# interfaces and async patterns to create maintainable, testable code that maximizes Meadow.Foundation's capabilities.

```plantuml
@startuml Attic_Class_Diagram
title Attic Unit - Class Architecture

interface IMotionSensor {
  + bool IsMotionDetected
  + event EventHandler<bool> MotionChanged
  + Initialize() : Task
}

interface IDeterrent {
  + bool IsActive
  + ActivateAsync(duration: TimeSpan) : Task
  + DeactivateAsync() : Task
}

interface ICloudService {
  + ConnectAsync() : Task
  + PublishEventAsync(event: MotionEvent) : Task
  + SubscribeToCommands() : Task
}

class AtticApp {
  - IMotionSensor motionSensor
  - List<IDeterrent> deterrents
  - ICloudService cloudService
  - StateMachine stateMachine
  + override Initialize() : Task
  + override Run() : Task
}

class PirMotionSensor {
  - IDigitalInterruptPort pirPort
  - DateTime lastMotion
  + bool IsMotionDetected
  + event EventHandler<bool> MotionChanged
  + Initialize() : Task
  - OnMotionInterrupt(sender, args) : void
}

class StrobeDeterrent {
  - IDigitalOutputPort relayPort
  - Timer strobeTimer
  + bool IsActive
  + ActivateAsync(duration: TimeSpan) : Task
  + DeactivateAsync() : Task
  - ToggleStrobe() : void
}

class KlaxonDeterrent {
  - ShellyRelay shellyRelay
  - bool remoteEnabled
  + bool IsActive
  + ActivateAsync(duration: TimeSpan) : Task
  + DeactivateAsync() : Task
  + SetRemoteEnabled(enabled: bool) : void
}

class ShellyRelay {
  - HttpClient httpClient
  - string ipAddress
  + TurnOnAsync() : Task
  + TurnOffAsync() : Task
  + GetStatusAsync() : Task<bool>
}

class MeadowCloudService {
  - IMeadowCloudClient client
  - string deviceId
  + ConnectAsync() : Task
  + PublishEventAsync(event: MotionEvent) : Task
  + SubscribeToCommands() : Task
  - OnCommandReceived(command: CloudCommand) : void
}

class StateMachine {
  - State currentState
  - Dictionary<State, List<Transition>> transitions
  + CurrentState : State
  + FireAsync(trigger: Trigger) : Task
  + OnStateChanged : EventHandler<State>
}

enum State {
  Idle
  Armed
  MotionDetected
  DeterrentsActive
  Cooldown
}

enum Trigger {
  Arm
  Disarm
  MotionStart
  MotionEnd
  DeterrentsComplete
  CooldownComplete
}

' Relationships
AtticApp --> IMotionSensor
AtticApp --> IDeterrent
AtticApp --> ICloudService
AtticApp --> StateMachine

PirMotionSensor ..|> IMotionSensor
StrobeDeterrent ..|> IDeterrent
KlaxonDeterrent ..|> IDeterrent
KlaxonDeterrent --> ShellyRelay
MeadowCloudService ..|> ICloudService

StateMachine --> State
StateMachine --> Trigger

@enduml
```

![Attic_Class_Diagram](diagrams/Attic_Class_Diagram.png)

The class architecture employs dependency injection through interfaces, enabling unit testing and component substitution. The `AtticApp` class inherits from Meadow's base application class, overriding initialization and run methods. Deterrent classes encapsulate hardware control logic, while the state machine ensures predictable system behavior. The `ShellyRelay` class demonstrates HTTP-based control of smart devices, extending the system's capabilities beyond direct GPIO control.

## Motion Detection Sequence

The sequence flow demonstrates interrupt-driven motion detection with cloud-coordinated responses, showcasing Meadow's event-driven architecture.

```plantuml
@startuml Attic_Sequence_Diagram
title Attic Unit - Motion Detection and Response Sequence

actor Squirrel
participant "PIR Sensor" as PIR
participant "GPIO Interrupt" as GPIO
participant "Motion Service" as MS
participant "State Machine" as SM
participant "Strobe Light" as STROBE
participant "Klaxon" as KLAXON
participant "Cloud Service" as CLOUD
participant "Living Room Unit" as LRU

== Motion Detection ==
Squirrel -> PIR : Enters detection zone
PIR -> GPIO : Hardware interrupt
GPIO -> MS : RisingEdge event

activate MS
MS -> MS : Debounce check
MS -> SM : FireAsync(MotionStart)
deactivate MS

activate SM
SM -> SM : Transition to MotionDetected
SM -> CLOUD : PublishEventAsync
activate CLOUD
CLOUD -> LRU : MQTT notification
deactivate CLOUD

SM -> STROBE : ActivateAsync(30s)
activate STROBE
STROBE -> STROBE : Start strobing

alt Klaxon enabled remotely
  SM -> KLAXON : ActivateAsync(10s)
  activate KLAXON
  KLAXON -> KLAXON : Sound alarm
  
  ...10 seconds...
  
  KLAXON -> KLAXON : Auto-stop
  deactivate KLAXON
end

...30 seconds...

STROBE -> STROBE : Auto-stop
deactivate STROBE

SM -> SM : Transition to Cooldown
deactivate SM

== Motion End ==
PIR -> GPIO : FallingEdge event
GPIO -> MS : Motion ended
MS -> SM : FireAsync(MotionEnd)

@enduml
```

![Attic_Sequence_Diagram](diagrams/Attic_Sequence_Diagram.png)

The sequence leverages hardware interrupts for immediate response to motion events. The GPIO interrupt handler executes in microseconds, triggering the motion service which performs software debouncing to prevent false triggers. State machine transitions ensure deterrents activate in the correct sequence, with the strobe light providing immediate visual deterrence while the klaxon depends on remote enablement. Cloud notifications enable cross-unit coordination, allowing the living room camera to begin recording simultaneously.

## State Management

The state machine provides deterministic behavior with clear transitions between operational modes, essential for reliable security systems.

```plantuml
@startuml Attic_State_Diagram
title Attic Unit - System State Machine

[*] --> Initializing : Power On

state Initializing {
  [*] --> LoadingConfig
  LoadingConfig --> ConnectingWiFi
  ConnectingWiFi --> CloudSync
  CloudSync --> [*]
}

Initializing --> Idle : Init Complete

state Idle {
  [*] --> Disarmed
  Disarmed --> Armed : Arm Command
  Armed --> Disarmed : Disarm Command
}

state Armed {
  [*] --> Monitoring
  Monitoring : PIR Active
  Monitoring : Awaiting Motion
}

Armed --> MotionDetected : Motion Trigger

state MotionDetected {
  [*] --> ActivatingDeterrents
  ActivatingDeterrents --> DeterrentsRunning
  
  state DeterrentsRunning {
    [*] --> StrobeActive
    StrobeActive : 30s duration
    
    state c <<choice>>
    StrobeActive --> c : Check klaxon
    c --> KlaxonActive : If enabled
    c --> StrobeOnly : If disabled
    
    KlaxonActive : 10s duration
    StrobeOnly : Continue strobe
  }
}

MotionDetected --> Cooldown : Deterrents Complete

state Cooldown {
  Cooldown : 60s lockout
  Cooldown : Ignore new motion
}

Cooldown --> Armed : Cooldown Complete
Armed --> Idle : Disarm Command
Cooldown --> Idle : Disarm Command

state ErrorRecovery {
  ErrorRecovery : Reconnect WiFi
  ErrorRecovery : Local operation
}

Idle --> ErrorRecovery : Connection Lost
Armed --> ErrorRecovery : Connection Lost
ErrorRecovery --> Idle : Connection Restored

@enduml
```

![Attic_State_Diagram](diagrams/Attic_State_Diagram.png)

The hierarchical state machine manages system complexity through nested states and guarded transitions. The initialization sequence ensures all components are ready before entering operational states. The cooldown period prevents rapid retriggering that could annoy neighbors or drain power. Error recovery states maintain local functionality during network outages, with the system continuing to respond to motion events even without cloud connectivity. State persistence across power cycles ensures the system returns to its previous armed/disarmed state.

## Physical Deployment

The deployment architecture shows the practical installation layout with proper component placement for optimal coverage and maintenance access.

```plantuml
@startuml Attic_Deployment_Diagram
title Attic Unit - Physical Deployment Architecture

node "Attic Rafter Mount" as Rafter {
  component "PIR Sensor Module" as PIR_MOD {
    [PIR Sensor]
    [Fresnel Lens]
    [Adjustment Pots]
  }
  
  component "Meadow F7 Enclosure" as MEADOW_BOX {
    [Meadow F7v2]
    [Power Supply]
    [Terminal Blocks]
  }
}

node "Central Attic Space" as Central {
  component "Deterrent Assembly" as DET_ASSY {
    [Evictor Strobe]
    [Mounting Bracket]
    [Heat Shield]
  }
  
  component "Klaxon System" as KLAXON_SYS {
    [Honeywell 748]
    [Weather Enclosure]
  }
}

node "Electrical Panel Area" as Electrical {
  component "Power Distribution" as POWER {
    [GFCI Breaker]
    [12V Transformer]
    [Shelly Relay]
  }
  
  component "Network Equipment" as NETWORK {
    [WiFi Extender]
    [Surge Protector]
  }
}

cloud "Meadow.Cloud" as CLOUD {
  [Device Registry]
  [MQTT Broker]
  [Command API]
}

' Physical connections
PIR_MOD ..> MEADOW_BOX : "6ft shielded cable"
MEADOW_BOX ..> DET_ASSY : "14 AWG power"
MEADOW_BOX ..> POWER : "Control signals"
POWER ..> KLAXON_SYS : "12V DC"
NETWORK ..> MEADOW_BOX : "WiFi signal"
MEADOW_BOX ..> CLOUD : "MQTT/TLS"

note right of PIR_MOD : Mount 6-8ft high\nClear view of entry points

note left of DET_ASSY : Center position\nMaximum coverage

note bottom of POWER : Professional installation\nrequired for mains wiring

@enduml
```

![Attic_Deployment_Diagram](diagrams/Attic_Deployment_Diagram.png)

Physical deployment considerations include mounting the PIR sensor at optimal height (6-8 feet) with clear sightlines to potential entry points. The Meadow F7 enclosure requires adequate ventilation despite attic temperature extremes. Shielded cables prevent electromagnetic interference from affecting PIR sensor signals. The strobe light's central positioning maximizes its disorienting effect throughout the attic space. Professional electrical installation ensures code compliance for mains voltage connections, while low-voltage wiring to sensors and the klaxon can be self-installed. WiFi coverage often requires an extender in attic installations due to signal attenuation through building materials.
