

import processing.serial.*;

Serial mySerial;
boolean serialReady = false;

int WIDTH = 640;
int HEIGHT = 360;
float ARC_SEC = 1.0 / 3600.0;

float theta = 0.0;  // Start angle at 0
int radius;
int lon;
int lat;
int centerLon;
int centerLat;

int sendTime = 0;
int recvTime = 0;

String lastMsgReceived = "<NONE>";
String lastMsgSent = "<NONE>";

void setup() {
  size(WIDTH, HEIGHT);
  frameRate(10);

  // convert centerpoint and radious with higher precision
  centerLon = toBams(-121.316289);
  centerLat =   toBams(38.869004);
  radius = toBams(0.000278);

  println("Ports:");
  for (String s : Serial.list()) {
    println("  port: " + s);
  }
  println("End Ports");
  try {
    String portName = Serial.list()[0];
    mySerial = new Serial(this, portName, 9600);
    serialReady = true;
  } catch(ArrayIndexOutOfBoundsException e) {
    println("No serial port found!");
  } catch (Exception e) {
    println("Error opening serial port.");
  }
}

void draw() {
  background(0);
  calcPoint();
  if (millis() > sendTime) {
    sendPosition();
    sendTime = millis() + 2000;
  }
  if (millis() > recvTime) {
    receivePosition();
    recvTime = millis() + 1000;
  }
  renderData();
  // alarm button handler
}

int toBams(float a) {
  return (int)((a/180.0) * 2147483647);
}

float toDeg(int b) {
  return (b/2147483647.0) * 180.0;
}

void calcPoint() {
  // Increment theta (try different values for 'angular velocity' here
  theta = (theta + 0.02) % TWO_PI;

  lon = (int)(radius * sin(theta)) + centerLon;
  lat = (int)(radius * cos(theta)) + centerLat;
}

void sendPosition() {
  // initially we will send strings...
  if (serialReady) {
    
    byte buff[] = new byte[11];
    
    buff[0] = START_FLAG;
    buff[1] = 16;
    buff[2] = (byte) (lat >> 24); 
    buff[3] = (byte) (lat >> 16);
    buff[4] = (byte) (lat >> 8);
    buff[5] = (byte) lat;
    buff[6] = (byte) (lon >> 24);
    buff[7] = (byte) (lon >> 16);
    buff[8] = (byte) (lon >> 8);
    buff[9] = (byte) lon;
    buff[10] = 0;
    mySerial.write(buff);
    
    lastMsgSent = "16, " + lat + ", " + lon;
  //  mySerial.write(lastMsgSent);
  }
}

int getLong(byte buff[], int i) {
  return buff[i] << 24 | (buff[i+1] & 0xFF) << 16 | (buff[i+2] & 0xFF) << 8 | (buff[i+3] & 0xFF);
}

byte START_FLAG = (byte)0xff;

void receivePosition() {
    // initially we will receive strings...
    if (serialReady) {
      byte buff[] = new byte[30];
      if (mySerial.available() > 0) {
        int n = mySerial.readBytes(buff);
        println(n + " bytes to read");
        //println(buff);
        // fast forward to the first message start marker
        int i = 0;
        while (i < n && buff[i] != START_FLAG) {
          i++;   
        }
        println("i = " + i);
        if (n - i >= 11) {
          // there should be a message in the buffer
          byte alarm = buff[++i];
          int lat = getLong(buff, ++i);
          int lon = getLong(buff, i+=4);
          lastMsgReceived = alarm + ", " + lat + ", " + lon;
          println(lastMsgReceived);
        } else {
          println("no message!");
        }
      }
    }
}

int lat2pixels(long v) {
  return (int)map(v, centerLat - radius, centerLat + radius, 0, min(HEIGHT, WIDTH));
}
int lon2pixels(long v) {
  return (int)map(v, centerLon - radius, centerLon + radius, 0, min(HEIGHT, WIDTH)) + min(HEIGHT, WIDTH)/2;
}

void renderData() {
  noFill();
  stroke(0, 0, 255);
  ellipse(WIDTH/2, HEIGHT/2, min(HEIGHT, WIDTH), min(HEIGHT, WIDTH));
  stroke(255, 0, 0);
  int x = lon2pixels(lon);
  int y = lat2pixels(lat);
  line(WIDTH/2, HEIGHT/2, x, y);
  noStroke();
  fill(255);
  ellipse(x, y, 16, 16);

  String s = "LAT: " + lat; 
  text(s, 10, 350);
  s = "LON: " + lon;
  text(s, 10, 330);
  s = "THETA: " + theta;
  text(s, 10, 310);
  s = "RECEIVED: " + lastMsgReceived;
  text(s, 10, 20);
  s = "SENT: " + lastMsgSent;
  text(s, 10, 40);
}

