/*
    ------ WIFI Example --------

    Explanation: This example shows how to set up a TCP client connecting
    to a MQTT broker  (based on WIFI_PRO example from Libelium)

    Máster IoT-UPM

    Version:           1.0
*/

// Put your libraries here (#include ...)
#include <WaspWIFI_PRO.h>
#include <WaspFrame.h>
#include <WaspXBee802.h>

#include <Countdown.h>
#include <FP.h>
#include <MQTTFormat.h>
#include <MQTTLogging.h>
#include <MQTTPacket.h>
#include <MQTTPublish.h>
#include <MQTTSubscribe.h>
#include <MQTTUnsubscribe.h>

// choose socket (SELECT USER'S SOCKET)
///////////////////////////////////////
uint8_t socket = SOCKET1;
///////////////////////////////////////
// WiFi AP settings (CHANGE TO USER'S AP)
///////////////////////////////////////
char ESSID[] = "Wall-e";
char PASSW[] = "@gmail.com";
///////////////////////////////////////

// define variables
uint8_t error;
uint8_t status;

// choose TCP server settings
///////////////////////////////////////
char HOST[]        = "192.168.43.89"; //MQTT Broker
char REMOTE_PORT[] = "1883";  //MQTT
char LOCAL_PORT[]  = "3000";
///////////////////////////////////////
uint32_t msg_timeout = 10000;

uint16_t socket_handle = 0;

int connect_to_wifi(){
  //////////////////////////////////////////////////
  // 1. Switch ON the WiFi module
  //////////////////////////////////////////////////
  USB.println(F("Setting up wifi"));
  error = WIFI_PRO.ON(socket);

  if (error == 0)
  {    
    USB.println(F("1. WiFi switched ON"));
  }
  else
  {
    USB.println(F("1. WiFi did not initialize correctly"));
    return -1;
  }


  //////////////////////////////////////////////////
  // 2. Reset to default values
  //////////////////////////////////////////////////
  error = WIFI_PRO.resetValues();

  if (error == 0)
  {    
    USB.println(F("2. WiFi reset to default"));
  }
  else
  {
    USB.println(F("2. WiFi reset to default ERROR"));
    return -1;
  }


  //////////////////////////////////////////////////
  // 3. Set ESSID
  //////////////////////////////////////////////////
  error = WIFI_PRO.setESSID(ESSID);

  if (error == 0)
  {    
    USB.println(F("3. WiFi set ESSID OK"));
  }
  else
  {
    USB.println(F("3. WiFi set ESSID ERROR"));
    return -1;
  }


  //////////////////////////////////////////////////
  // 4. Set password key (It takes a while to generate the key)
  // Authentication modes:
  //    OPEN: no security
  //    WEP64: WEP 64
  //    WEP128: WEP 128
  //    WPA: WPA-PSK with TKIP encryption
  //    WPA2: WPA2-PSK with TKIP or AES encryption
  //////////////////////////////////////////////////
  error = WIFI_PRO.setPassword(WPA2, PASSW);

  if (error == 0)
  {    
    USB.println(F("4. WiFi set AUTHKEY OK"));
  }
  else
  {
    USB.println(F("4. WiFi set AUTHKEY ERROR"));
    return -1;
  }


  //////////////////////////////////////////////////
  // 5. Software Reset 
  // Parameters take effect following either a 
  // hardware or software reset
  //////////////////////////////////////////////////
  error = WIFI_PRO.softReset();

  if (error == 0)
  {    
    USB.println(F("5. WiFi softReset OK"));
  }
  else
  {
    USB.println(F("5. WiFi softReset ERROR"));
    return -1;
  }
  USB.println(F("*******************************************"));
  USB.println(F("Wifi seted up correctly!!"));
  USB.println(F("*******************************************\n"));  
  return 0;
}

int openTCPClient(){
    USB.println(F("Setting TCP client"));
    status =  WIFI_PRO.isConnected();
    if (status == true)
    {
      error = WIFI_PRO.setTCPclient( HOST, REMOTE_PORT, LOCAL_PORT);
      if (error == 0)
      {
        // get socket handle (from 0 to 9)
        socket_handle = WIFI_PRO._socket_handle;
  
        USB.print(F("3.1. Open TCP socket OK in handle: "));
        USB.println(socket_handle, DEC);
        return 0;
      }
      else
      {
        USB.println(F("3.1. Error calling 'setTCPclient' function"));
        WIFI_PRO.printErrorCode();
        return -1;
      }
    }
    else{
      USB.println(F("Not connected to wifi"));
      return -1; 
    }
}

int closeTCPClient(){
  USB.println(F("Close TCP client"));
  error = WIFI_PRO.closeSocket(socket_handle);
  if (error == 0)
  {
    USB.println(F("3.3. Close socket OK"));
    return 0;
  }
  else
  {
    USB.println(F("3.3. Error calling 'closeSocket' function"));
    WIFI_PRO.printErrorCode();
    return -1;
  }
}

void setup()
{
  // init XBee 
  xbee802.ON();
  // get current time
  if(connect_to_wifi() != 0){
    USB.println(F("*******************************************"));
    USB.println(F("Wifi set up falied"));
    USB.println(F("*******************************************\n"));
  }
  if(openTCPClient() != 0){
    USB.println(F("*******************************************"));
    USB.println(F("TCP set up falied"));
    USB.println(F("*******************************************\n"));
  }
  if(closeTCPClient() != 0){
    USB.println(F("*******************************************"));
    USB.println(F("TCP close falied"));
    USB.println(F("*******************************************\n"));
  }
  WIFI_PRO.OFF(socket);
}



void loop()
{
  USB.println(F("Waiting for 108.15.4 data"));  
  error = xbee802.receivePacketTimeout( msg_timeout );
  // check answer  
  if( error == 0 ) 
  {
    // Show data stored in '_payload' buffer indicated by '_length'
    USB.print(F("Data: "));  
    USB.println( xbee802._payload, xbee802._length);
    
    // Show data stored in '_payload' buffer indicated by '_length'
    USB.print(F("Length: "));  
    USB.println( xbee802._length,DEC);

    //MQTT PUBLISH  
    if (WIFI_PRO.ON(socket) == 0 && openTCPClient() == 0)
    {
      /// Publish MQTT
      MQTTPacket_connectData data = MQTTPacket_connectData_initializer;
      MQTTString topicString = MQTTString_initializer;
      unsigned char buf[300];
      int buflen = sizeof(buf);
      unsigned char payload[300];
  
      // options
      data.clientID.cstring = (char*)"mt1";
      data.keepAliveInterval = 30;
      data.cleansession = 1;
      int len = MQTTSerialize_connect(buf, buflen, &data); /* 1 */
  
      // Topic and message
      topicString.cstring = (char *)"g0/mota1/temperature";
      //snprintf((char *)payload, 100, "%s%d", "Mota1 #", ciclo);
      //int payloadlen = strlen((const char*)payload);
      //payload = (char *)xbee802._payload;
      //payloadlen = xbee802._length;
  
      len += MQTTSerialize_publish(buf + len, buflen - len, 0, 0, 0, 0, topicString, xbee802._payload, xbee802._length); /* 2 */
      len += MQTTSerialize_disconnect(buf + len, buflen - len); /* 3 */
  
      error = WIFI_PRO.send( socket_handle, buf, len);
  
      // check response
      if (error == 0)
      {
        USB.println(F("3.2. Send data OK"));
      }
      else
      {
        USB.println(F("3.2. Error calling 'send' function"));
        WIFI_PRO.printErrorCode();
      }
      closeTCPClient();
      WIFI_PRO.OFF(socket);
    }
    else{
      USB.println(F("Issues connecting wifi or tcpClient"));
      WIFI_PRO.OFF(socket);
      closeTCPClient();
    }
  }
  else
  {
    // Print error message:
    /*
     * '7' : Buffer full. Not enough memory space
     * '6' : Error escaping character within payload bytes
     * '5' : Error escaping character in checksum byte
     * '4' : Checksum is not correct    
     * '3' : Checksum byte is not available 
     * '2' : Frame Type is not valid
     * '1' : Timeout when receiving answer   
    */
    USB.print(F("Error receiving a packet:"));
    USB.println(error,DEC);     
  }

}

