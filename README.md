# MacroRail
Automate your macro photography. More precision, more detail, and greater depth of field.

MacroRail is a motorized macro photography rail designed to automate image capture for Focus Stacking.

In macro photography, depth of field can be extremely shallow. Even when using small apertures, getting the entire subject perfectly in focus can be challenging.

MacroRail solves this problem by moving the camera precisely, automatically, and consistently, taking a photograph at each position. The resulting images can then be combined using Focus Stacking software to create a final photograph with a much greater depth of field.

## Print it. Build it. Automate it.

MacroRail has been designed as a DIY project combining:

3D Printing + Electronics + Photography + Automation

The goal is to create a fully functional macro photography tool that you can print, assemble, and configure yourself.

The project includes all the information you need to build your own MacroRail:

- Complete Bill of Materials (BOM)
- 3D printing files
- Printing settings
- Wiring diagram
- Firmware installation
- Bluetooth configuration

## How does it work?

Using MacroRail is simple:

Configure → Start → Move → Shoot → Repeat → Stack

1. Mount your camera on the MacroRail.
2. Position and focus on the subject you want to photograph.
3. Configure the process from the mobile app via Bluetooth.
4. MacroRail moves the camera using a NEMA 17 stepper motor.
5. The camera precisely reaches the next position.
6. The infrared module automatically sends the shutter command to the camera.
7. The rail moves again by the configured distance.
8. The process is automatically repeated until the entire configured travel distance has been completed.
9. Combine the captured images using your favorite Focus Stacking software.

The result is a series of photographs captured at precise, progressively spaced positions, ready to be stacked.


## Main Features

### Mobile App Control

MacroRail is controlled wirelessly via Bluetooth, allowing you to configure and run capture sequences without physically touching the rail.

This is particularly useful in macro photography, where even small movements or vibrations can affect the final result.

The mobile application was developed using Flutter and is currently available for Android.

### Precise Movement with NEMA 17

Movement is provided by a NEMA 17 stepper motor, allowing for small, controlled, and repeatable movements.

The camera progressively moves along the rail throughout the entire capture sequence.

### Automatic Camera Shutter

MacroRail features an infrared transmitter module capable of sending shutter commands to compatible cameras.

It is currently designed for use with the Sony A6400 using Sony's SIRC20 infrared protocol.

This allows the entire process to be automated:

Move camera → Stabilize → Shoot → Move camera → Stabilize → Shoot...

There is no need to touch the camera between shots.

### Limit Switches

The system features multiple microswitches that detect the physical travel limits of the mechanism, preventing the carriage from moving beyond its safe operating range and avoiding unnecessary stress on the motor.


# Bill of Materials (BOM)

| Component             | Qty. | Specification                    | Link |
|-----------------------|------|----------------------------------|------|
| NEMA 17 Stepper Motor | 1    | 42mm NEMA 17                     |      |
| Stepper Motor Driver  | 1    | DRV8825                          |      |
| Microcontroller       | 1    | Arduino Nano                     |      |
| Bluetooth module      | 1    | HC-05                            |      |
| IR Transmitter Module | 1    | 38kHz IR transmitter for arduino |      |
| Microswitch           | 2    | lever microswitch                |      |
| Power Supply          | 1    | 9V 3A power supply               |      |
| Cable USB Type C      | 1    | USB compatible with Arduino Nano |      |
|                       |      |                                  |      |

...


# 3D printing files

All the files are available in makerworld:

* [https://makerworld.com/es/models/3184573-macrorail-automatic-motorized-focus-stacking-rail#profileId-3602152](https://makerworld.com/es/models/3184573-macrorail-automatic-motorized-focus-stacking-rail#profileId-3602152)


# Wiring Diagram

As it is shown in BOM section I used an Arduino Nano (chinese version). 

## Bluetooth

For the conexion of `HC-05` bluetooth module we need to connect the followin 4 pins.

| **HC-05 BT** 	| **Arduino** 	|
|:------------:	|:-----------:	|
|      RXD     	|      D3     	|
|      TXD     	|      D2     	|
|      GND     	|     GND     	|
|      VCC     	|     VCC     	|

![](/images/hc-05.png)

## Microswitches

There are two microswitches, the first marks the beginning of the lane (known as HOME), and the second marks the end.

The switch can be used in two ways: normally open or normally closed. In our case, we will use it as a **normally open** switch.

| **SW HOME** 	| **SW END** 	| **Arduino** 	|
|:-----------:	|------------	|:-----------:	|
|      NO     	|            	|      D8     	|
|             	|     NO     	|      D7     	|
|      C      	|      C     	|     GND     	|
![](/images/switch.png)


## IR Transmitter

In order to send the shutter signal to the camera, we need an infrared transmitter.

| **IR Transmitter** 	| **Arduino** 	|
|:------------------:	|:-----------:	|
|        DATA        	|      D4     	|
|         GND        	|     GND     	|
|         VCC        	|     VCC     	|

![](/images/ir.png)


## Motor and Driver

The DRV8825 driver has been configured with 1/32 microstepping for greater precision.

It is important to install a capacitor between the power supply—in my case, 9V 3A—and the driver. Use a capacitor with a minimum capacitance of 100 uF.

Go to the next tutorial to configure the current of the driver. I can´t explain it better.

* [https://lastminuteengineers.com/drv8825-stepper-motor-driver-arduino-tutorial/](https://lastminuteengineers.com/drv8825-stepper-motor-driver-arduino-tutorial/)

![](/images/motor.png)


# Firmware installation

The code is available on the [https://github.com/benjugat/MacroRail/blob/main/arduino/MacroRail.ino](github repo), just use Arduino IDE to compile and upload the sketch to the arduino nano.

If you have a different camera, just change the IR signal on the `sendPhotoIR()` function. I read the signal with a FlipperZero.

```cpp
void sendPhotoIR() {
  uint16_t rawData[] = {
    2400, 600,
    1200, 600,
    600, 600,
    1200, 600,
    1200, 600,
    600, 600,
    1200, 600,
    600, 600,
    600, 600,
    1200, 600,
    600, 600,
    1200, 600,
    1200, 600,
    1200, 600,
    600, 600,
    600, 600,
    600, 600,
    1200, 600,
    1200, 600,
    1200, 600,
    1200, 600
  };

  IrSender.sendRaw(rawData, sizeof(rawData) / sizeof(rawData[0]), 40);
  sendMessage("PHOTO");
}
```

# Bluetooth configuration

An android application with flutter was delevoped in order to control the MacroRail. So launch the application and go to Scan Devices. By default is shown as `Slave HC-05` or just `HC-05`.

Connect and send the default pin `1234`.

