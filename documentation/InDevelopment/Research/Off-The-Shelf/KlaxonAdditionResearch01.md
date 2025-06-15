# Adding a klaxon alarm to your ONEVER motion sensor squirrel deterrent system

The technical solution involves using a relay module to split your ONEVER PIR sensor output between the existing Evictor strobe light and new klaxon, with a smart WiFi switch providing remote on/off control. This approach ensures the klaxon only sounds when you've specifically enabled it via smartphone, preventing unwanted neighborhood disruptions.

## Recommended system configuration

Your best approach combines the ONEVER sensor's existing functionality with a smart relay system that acts as a remote-controlled gate. When enabled via smartphone, motion triggers both the strobe light and klaxon. When disabled, only the strobe light activates.

### Core components needed

**Klaxon Selection**
The **Honeywell Ademco 748** ($44-65) delivers 119dB of dual-tone sound - painfully loud and audible 200+ feet away according to verified customers. This weather-resistant siren runs on 12VDC and has proven effective for outdoor pest deterrence. For a more budget-friendly option, the **MG50JR** ($35-50) provides 115dB output with similar effectiveness.

**Smart Control System**
The **Shelly 1 Gen3** ($12-18) smart relay offers the best value with no subscription fees ever required. It provides 16A switching capacity, works with Alexa/Google Home, and includes local control options. Mount it in a weatherproof IP66 enclosure ($25-35) for outdoor durability.

**Power and Integration**
A **12V 60W outdoor transformer** ($60-85) converts your 110V AC to safe 12V DC for the klaxon. An **MY2NJ 110V AC DPDT relay** ($15-25) splits the PIR sensor signal between your existing strobe light and the new klaxon circuit.

## Wiring method for shared motion sensor trigger

The integration leverages your ONEVER sensor's 110V AC output through a dual-relay configuration:

**Primary Circuit Path:**
1. ONEVER PIR output (red wire) connects to DPDT relay coil (110V AC)
2. Relay Contact 1 maintains connection to existing Evictor strobe light
3. Relay Contact 2 feeds the Shelly smart switch input
4. Shelly output controls 12V transformer powering the klaxon
5. Smart switch acts as enable/disable gate via WiFi control

This configuration preserves your existing strobe light functionality while adding independently controllable klaxon activation. The DPDT relay handles the signal splitting, preventing interference between devices.

## Remote control implementation

**Smartphone Control**
Download the free Shelly Smart Control app for iOS/Android. After connecting the Shelly device to your 2.4GHz WiFi network, you can instantly toggle the klaxon system on/off from anywhere. The app displays real-time status and allows scheduling if desired.

**Voice Assistant Integration**
Enable the Shelly skill in Alexa or Google Home for voice commands like "Alexa, turn on backyard alarm" or "Hey Google, disable squirrel alarm." No subscription required for basic voice control.

**Advanced Automation Options**
Create location-based rules to automatically disable the klaxon when you arrive home, or set schedules for quiet hours. The Shelly device supports local control without internet, ensuring reliability even during outages.

## Complete shopping list with pricing

### Essential Components ($175-225)
- **Honeywell Ademco 748 Klaxon** - $50 (Amazon)
- **Shelly 1 Gen3 Smart Relay** - $15 (Amazon/Shelly Store)
- **IP66 Weatherproof Enclosure** - $30 (Amazon)
- **12V 60W Outdoor Transformer** - $70 (Landscape lighting suppliers)
- **MY2NJ 110V AC DPDT Relay** - $20 (Electronics suppliers)
- **WAGO 221 Terminal Blocks** - $25 (Electrical suppliers)
- **14 AWG Outdoor Wire (25ft)** - $15 (Home Depot)

### Optional Enhancements ($50-100)
- **12V 7AH Backup Battery** - $30 (For power outage operation)
- **Professional Junction Box** - $35 (NEMA 4X rated)
- **PVC Conduit and Fittings** - $25 (For exposed wiring)
- **Surge Protector** - $20 (Protects electronics)

## Installation instructions

### Phase 1: Electrical Preparation
Install a GFCI-protected outlet near your existing PIR sensor location if not already present. Mount the weatherproof enclosure for housing the relay and smart switch components. Run 14 AWG wire from the enclosure to your planned klaxon location.

### Phase 2: Relay Integration
Inside the weatherproof enclosure, connect the ONEVER sensor's output (red wire) to the DPDT relay coil terminals. Wire relay contact set 1 to maintain the existing strobe light connection. Connect relay contact set 2 to the Shelly smart switch input terminal.

### Phase 3: Power Supply Setup
Mount the 12V transformer in a protected location. Connect transformer primary to the Shelly switch output. Run low-voltage wiring from transformer to klaxon location using outdoor-rated cable.

### Phase 4: Klaxon Installation
Mount the Ademco 748 klaxon at least 8 feet high to prevent tampering. Connect to 12V power from transformer. Test system before final weatherproofing.

### Phase 5: Smart Control Configuration
Connect Shelly device to WiFi following app instructions. Test remote on/off functionality. Configure any desired automation rules or voice assistant integration.

## Safety considerations

All 110V AC connections require professional installation by a licensed electrician for safety and code compliance. The system uses GFCI protection for all outdoor circuits. Low-voltage klaxon operation (12V DC) provides additional safety compared to direct 110V alternatives.

The DPDT relay isolation prevents feedback between devices, while the weatherproof enclosures protect all electronics from moisture damage. Professional installation typically takes 4-6 hours and ensures proper grounding and circuit protection.

## System effectiveness

Customer reviews consistently praise the Ademco 748's effectiveness for wildlife deterrence, with many reporting successful squirrel and raccoon deterrence. The 119dB output creates an immediately unpleasant environment that conditions animals to avoid the area. Combined with your existing strobe light, this creates a powerful multi-sensory deterrent.

The remote control capability proves essential for maintaining neighbor relations - you can disable the system during parties, when expecting deliveries, or based on your schedule. The smartphone notifications also alert you to activations, helping monitor squirrel activity patterns.

## Conclusion

This klaxon integration provides a powerful, remotely controllable addition to your existing ONEVER motion sensor system. The Shelly smart relay enables convenient smartphone control without subscription fees, while the professional-grade Ademco klaxon delivers proven wildlife deterrence. Total system cost ranges from $175-325 depending on installation complexity, with all components readily available from major retailers. The modular design allows future expansion or modification as needed for optimal squirrel deterrence.