

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

String lastMsgReceived = "<NONE>";
String lastMsgSent = "<NONE>";

void setup() {
  size(WIDTH, HEIGHT);
  frameRate(10);

  // convert centerpoint and radious with higher precision
  centerLon = (int)(-121.316289/180.0) * 2147483647;
  centerLat =   (int)(38.869004/180.0) * 2147483647;
  radius = (int)((0.000278/180.0) * 2147483647.0);

  for (String s : Serial.list()) {
    println("port: " + s);
  }
  try {
    String portName = Serial.list()[0];
    mySerial = new Serial(this, portName, 9600);
  } catch(ArrayIndexOutOfBoundsException e) {
    println("No serial port found!");
  } catch (Exception e) {
    println("Error opening serial port.");
  }
}

void draw() {
  background(0);
  calcPoint();
  sendPosition();
  receivePosition();
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
    lastMsgSent = "{0," + lat + "," + lon + "}";
    mySerial.write(lastMsgSent);
  }
}

void receivePosition() {
    // initially we will receive strings...
    if (serialReady) {
      if (mySerial.available() > 0) {
        String data = mySerial.readString();
        lastMsgReceived = data;
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

