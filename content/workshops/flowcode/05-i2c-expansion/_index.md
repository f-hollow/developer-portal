---
title: "Flowcode - M5 Stack Dial Workshop - 5. I2C Expansion"
date: 2024-12-09
authors:
    - john-dobson
---

In this section we are going to read a sensor value using the
I2C connection on the M5 Stack Dial.
In this case we will use a small Grove sensor that contains a
SH31 temperature and humidity chip.
Of course it’s a bit odd having a temperature and humidity
sensor on a door lock! But it allows us to teach you how you
can take advantage of the huge range of I2C sensors and
expansion devices to extend the functionality of your M5stack
Dial.                                                  SHT31.png



Start with the program you made in the previous section.


Add a SHT31 Temp / Humidity sensor from the Sensors
component section.
Adjust its properties as you can see here:



You should have a panel that looks like this:
Add two variables of type INT: Temperature and       Humidity.
                                              5 1 sht31 properties.png
Then develop the program you can see below.
The program is easy to read but there are a few things of note:
The program initialises the display and the SHT31 sensor.
Initialisation is used on many components to set up registers
inside the microcontroller.
When reading and display a value like this one issue you have
is that you are writing new numbers on top of old ones. When
the number changes the display becomes hard to read. So we
need to clear the area of the screen before we rewrite the
number. Clearing the screen takes time - its quicker to draw a
rectangle of the background colour (black here).

Over to you:                5 2 panel.png


In practice the temperature and humidity are quantities that


change very slowly. So there is no need to constantly rewrite



Start with the program you made in the previous section.


Add a SHT31 Temp / Humidity sensor from the Sensors
component section.
Adjust its properties as you can see here:



You should have a panel that looks like this:
Add two variables of type INT: Temperature and Humidity.
Then develop the program you can see below. 5 3 variables.png
The program is easy to read but there are a few things of note:
The program initialises the display and the SHT31 sensor.
Initialisation is used on many components to set up registers
inside the microcontroller.
When reading and display a value like this one issue you have
is that you are writing new numbers on top of old ones. When
the number changes the display becomes hard to read. So we
need to clear the area of the screen before we rewrite the
number. Clearing the screen takes time - its quicker to draw a
rectangle of the background colour (black here).

Over to you:
In practice the temperature and humidity are quantities that
change very slowly. So there is no need to constantly rewrite
the values on the screen.
Develop a program that only redraws the values when they
change.



           5 4 temp hum program.png







                          Youtube logo.png




A YouTube video accompanies this tutorial.
                          5 - I2C expansion.jpg




                                        Flowcode logo.png
A Flowcode example file accompanies this tutorial. This is
available from the Flowcode Wiki:
https://www.flowcode.co.uk/wiki/index.php?
title=Examples_and_Tutorials
5 - I2C expansion.fcfx