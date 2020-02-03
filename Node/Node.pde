/*  
 *  ------ [802_02] - send packets -------- 
 *  
 *  Explanation: This program shows how to send packets to a gateway
 *  indicating the MAC address of the receiving XBee module 
 *  
 *  Copyright (C) 2016 Libelium Comunicaciones Distribuidas S.L. 
 *  http://www.libelium.com 
 *  
 *  This program is free software: you can redistribute it and/or modify 
 *  it under the terms of the GNU General Public License as published by 
 *  the Free Software Foundation, either version 3 of the License, or 
 *  (at your option) any later version. 
 *  
 *  This program is distributed in the hope that it will be useful, 
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of 
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 *  GNU General Public License for more details. 
 *  
 *  You should have received a copy of the GNU General Public License 
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>. 
 *  
 *  Version:           3.0
 *  Design:            David Gascón 
 *  Implementation:    Yuri Carmona
 */
 
#include <WaspXBee802.h>
#include <WaspFrame.h>
 #include <WaspSensorEvent_v30.h>

// Destination MAC address
//////////////////////////////////////////
char RX_ADDRESS[] = "0013A200416BE350";
//////////////////////////////////////////

// Define the Waspmote ID
char WASPMOTE_ID[] = "node_01";


// define variable
uint8_t error;

//Sensor Variables
float temp;
float humd;
float pres;
float value;
pirSensorClass pir(SOCKET_1);


void setup()
{
  // init USB port
  USB.ON();

  //LEDS
  Utils.setLED(LED0, LED_OFF);
  Utils.setLED(LED1, LED_OFF);
  
  //XBEE
  USB.println(F("XBEE SETUP"));  
  // store Waspmote identifier in EEPROM memory
  frame.setID( WASPMOTE_ID );
  // init XBee
  xbee802.ON();

  //SENSORS
  Events.ON();

  //PIR
  value = pir.readPirSensor();
  while (value == 1)
  {
    USB.println(F("...wait for PIR stabilization"));
    delay(1000);
    value = pir.readPirSensor();    
  }
  // Enable interruptions from the board
  Events.attachInt();

  //ACC
  ACC.ON();
  ACC.check();
  ACC.setFF(); 
  
  //RTC
  USB.println(F("RTC SETUP"));
  RTC.ON();
  RTC.setTime("13:01:11:06:12:33:00");
  USB.print(F("Setting time: "));
  USB.println(F("13:01:11:06:12:33:00"));
  RTC.setAlarm1("00:00:00:10",RTC_OFFSET,RTC_ALM1_MODE2);
  
}


void loop()
{
 
  //USB.printf("%d\n",intFlag);
  //USB.println(F("Waspmote goes into sleep mode until the Accelerometer or Alarm causes an interrupt"));
  //PWR.sleep(ALL_ON);
  USB.printf("%d %s\n",intFlag,RTC.getAlarm1());

  if( intFlag & ACC_INT )
  {
    // clear interruption flag
    intFlag &= ~(ACC_INT);
    ACC.ON();
    ACC.unsetFF(); 
    // print info
    USB.ON();
    USB.println(F("++++++++++++++++++++++++++++"));
    USB.println(F("++ ACC interrupt detected ++"));
    USB.println(F("++++++++++++++++++++++++++++")); 
    USB.println(); 
    
    ///////////////////////////////////////////
    // 2. Send packet
    ///////////////////////////////////////////  
    frame.createFrame(ASCII);  
    frame.addSensor(SENSOR_STR, "NodeACCWarning");  
    // send XBee packet
    error = xbee802.send( RX_ADDRESS, frame.buffer, frame.length );
    if( error == 0 )
    {
      USB.println(F("send warning ok"));
      // blink green LED
      //Utils.blinkGreenLED();
      
    }
    else 
    {
      USB.println(F("send warning error"));
      // blink red LED
      //Utils.blinkRedLED();
    }  
    ACC.ON();
    ACC.setFF();

    // blink LEDs
    Utils.blinkGreenLED(200, 10); 
  }

  if (intFlag & SENS_INT)
  {
    // Disable interruptions from the board
    Events.detachInt();
    
    // Load the interruption flag
    Events.loadInt();
    
    // In case the interruption came from PIR
    if (pir.getInt())
    {
      USB.println(F("-----------------------------"));
      USB.println(F("Interruption from PIR"));
      USB.println(F("-----------------------------"));
    }    
    
    // User should implement some warning
    // In this example, now wait for signal
    // stabilization to generate a new interruption
    // Read the sensor level
    value = pir.readPirSensor();
    
    while (value == 1)
    {
      USB.println(F("...wait for PIR stabilization"));
      delay(1000);
      value = pir.readPirSensor();
    }
    
    // Clean the interruption flag
    intFlag &= ~(SENS_INT);
    
        ///////////////////////////////////////////
    // 2. Send packet
    ///////////////////////////////////////////  
    frame.createFrame(ASCII);  
    frame.addSensor(SENSOR_STR, "NodePIRWarning");
        // check TX flag
    if( error == 0 )
    {
      USB.println(F("send warning ok"));
      // blink green LED
      //Utils.blinkGreenLED();
      
    }
    else 
    {
      USB.println(F("send warning error"));
      // blink red LED
      //Utils.blinkRedLED();
    }  
    // send XBee packet
    error = xbee802.send( RX_ADDRESS, frame.buffer, frame.length );
    
    // Enable interruptions from the board
    Utils.blinkRedLED(200, 10);
    Events.attachInt();
  }

  if( intFlag & RTC_INT )
  {
    //Clear and  program next
    USB.println(F("++ time interrupt ++"));
    USB.println(RTC.getTime());
    intFlag &= ~(RTC_INT); // Clear flag
   
    frame.createFrame(ASCII);  
    frame.addSensor(SENSOR_STR, "Node");
    frame.addSensor(SENSOR_TCA, Events.getTemperature()); 
    frame.addSensor(SENSOR_HUMA, Events.getHumidity()); 
    frame.addSensor(SENSOR_PA, Events.getPressure()); 
    frame.addSensor(SENSOR_ACC, ACC.getX(),ACC.getY(),ACC.getY());
    frame.addSensor(SENSOR_BAT, PWR.getBatteryLevel());

    ///////////////////////////////////////////
    // 2. Send packet
    ///////////////////////////////////////////  
  
    // send XBee packet
    error = xbee802.send( RX_ADDRESS, frame.buffer, frame.length );   
    
    // check TX flag
    if( error == 0 )
    {
      USB.println(F("send ok"));
      // blink green LED
      //Utils.blinkGreenLED();
      
    }
    else 
    {
      USB.println(F("send error"));
      // blink red LED
      //Utils.blinkRedLED();
    }
    RTC.setAlarm1("00:00:00:10",RTC_OFFSET,RTC_ALM1_MODE2);
  }
  //delay(100);
  PWR.clearInterruptionPin();
}



