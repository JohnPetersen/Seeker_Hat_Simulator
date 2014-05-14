

import processing.serial.*;

Serial mySerial;
boolean serialReady = false;

int WIDTH = 640;
int HEIGHT = 360;
float ARC_SEC = 1.0 / 3600.0;
int CROSS_SIZE = 10;

float theta = 0.0;  // Start angle at 0
int radius;
int lon;
int lat;
int centerLon;
int centerLat;
int recvLon;
int recvLat;
byte alarmBase = 16;
byte alarmBit = 1;
byte ackBit = 2;
int sendTime = 0;
int recvTime = 0;
int firstMsgRecvTime = 0;

String lastMsgReceived = "<NONE>";
String lastMsgSent = "<NONE>";

int btnAckX, btnAckY;
int btnAlmX, btnAlmY;
int btnStopX, btnStopY;
int rectSize = 75;
color rectColor, rectHighlight, rectPressed;
boolean btnAckOver = false;
boolean btnAlmOver = false;
boolean btnStopOver = false;
boolean btnAckPressed = false;
boolean btnAlmPressed = false;
boolean btnStopPressed = false;

void setup() {
  size(WIDTH, HEIGHT);
  frameRate(10);

  rectColor = #08087F;
  rectHighlight = #3F3FFF;
  rectPressed = #087F08;
  btnAckX = WIDTH-rectSize-10;
  btnAckY = HEIGHT-rectSize-10;
  btnAlmX = WIDTH-rectSize-10;
  btnAlmY = btnAckY - rectSize - 10;
  btnStopX = WIDTH-rectSize-10;
  btnStopY = btnAlmY - 2*(rectSize + 10);

  // convert centerpoint and radious with higher precision
  centerLon = toBams(-121.316289);
  centerLat =   toBams(38.869004);
  recvLon = centerLon;
  recvLat = centerLat;
  println("centerLat: " + centerLat + " centerLon: " + centerLon);
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
  // blank background
  background(0);
  // draw button
  btnAckOver = overRect(btnAckX, btnAckY, rectSize, rectSize);
  btnAlmOver = overRect(btnAlmX, btnAlmY, rectSize, rectSize);
  btnStopOver = overRect(btnStopX, btnStopY, rectSize, rectSize);
  drawButton("ACK", btnAckOver, btnAckPressed, btnAckX, btnAckY, rectSize, rectSize);
  drawButton("Alarm", btnAlmOver, btnAlmPressed, btnAlmX, btnAlmY, rectSize, rectSize);
  drawButton("Stop", btnStopOver, btnStopPressed, btnStopX, btnStopY, rectSize, rectSize);
  
  if (!btnStopPressed) { 
    calcPoint();
  }
  
  // send message to other every 2 seconds
  if (millis() > sendTime) {
    sendPosition();
    sendTime = millis() + 2000;
  }
  if (millis() > recvTime) {
    receivePosition();
    recvTime = millis() + 1000;
  }
  renderData();
}

void drawButton(String txt, boolean highlight, boolean pressed, int x, int y, int w, int h) {
  //println("Draw button: "+ x + ", " + y + ", " + w + ", " + h);
  if (pressed) {
    fill(rectPressed);
  } else if (highlight) {
    fill(rectHighlight);
  } else {
    fill(rectColor);
  }
  stroke(255);
  rect(x, y, w, h);
  fill(255);
  float tw = textWidth(txt);
  float th = textAscent() + textDescent();
  text(txt, x + ((w - tw) / 2), y + ((h - th) / 2));
}

boolean overRect(int x, int y, int width, int height)  {
  if (mouseX >= x && mouseX <= x+width && 
      mouseY >= y && mouseY <= y+height) {
    return true;
  } else {
    return false;
  }
}

int toBams(float a) {
  return (int)((a/180.0) * 2147483647);
}

float toDeg(int b) {
  return (b/2147483647.0) * 180.0;
}

float rad2deg(float r) {
  return r * 180.0/PI;
}

void mousePressed() {
  if (btnAckOver) {
    println("ACK");
    btnAckPressed = !btnAckPressed;
  } else if (btnAlmOver) {
    println("ALARM");
    btnAlmPressed = !btnAlmPressed;
  } else if (btnStopOver) {
    println("STOP");
    btnStopPressed = !btnStopPressed;
  }
}

void calcPoint() {
  // Increment theta (try different values for 'angular velocity' here
  theta = (theta + 0.02) % TWO_PI;

  lon = (int)(radius * cos(theta)) + centerLon;
  lat = (int)(radius * sin(theta)) + centerLat;
//  lon = (int)(radius * sin(theta)) + centerLon;
//  lat = (int)(radius * cos(theta)) + centerLat;
}

void sendPosition() {
  // initially we will send strings...
  if (serialReady) {
    
    byte a = (byte) (alarmBase | (btnAlmPressed ? alarmBit : 0) | (btnAckPressed ? ackBit : 0));
    
    byte buff[] = new byte[11];
    
    buff[0] = START_FLAG;
    buff[1] = a;
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
    
    lastMsgSent = a + ", " + lat + ", " + lon;
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
          if (alarm >= 16) {
            recvLat = lat;
            recvLon = lon;
          }
          println(lastMsgReceived);
          if (firstMsgRecvTime == 0) {
            firstMsgRecvTime = millis();
          } else {
            println("Current runtime: " + ((millis() - firstMsgRecvTime)/1000) + " seconds");
          }
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
  int half = min(HEIGHT, WIDTH)/2;
  return (int)map(v, centerLon - radius, centerLon + radius, WIDTH/2 - half, WIDTH/2 + half);
}

String angleText(float r) {
  return nfs(rad2deg(r),3,1) + "  " + nfs(r,1,3);
}

void renderData() {
  // outer circle
  noFill();
  stroke(0, 0, 255);
  ellipse(WIDTH/2, HEIGHT/2, min(HEIGHT, WIDTH), min(HEIGHT, WIDTH));
  line(WIDTH/2, HEIGHT/2, WIDTH*4/5, HEIGHT/2);
  fill(0,0,255);
  text("N", WIDTH*4/5, HEIGHT/2 + 5);
  
  // theta line
  stroke(255, 0, 0);
  int myX = lon2pixels(lon);
  int myY = lat2pixels(lat);
  line(WIDTH/2, HEIGHT/2, myX, myY);
  noFill();
  arc(WIDTH/2, HEIGHT/2, min(HEIGHT, WIDTH)/3, min(HEIGHT, WIDTH)/3, 0, theta);
  
  // orbiting circle (my position)
  noStroke();
  fill(255);
  ellipse(myX, myY, 16, 16);
  
  // received position
  stroke(0,255,0);
  int x = lon2pixels(recvLon);
  int y = lat2pixels(recvLat);
  line(x,y,myX,myY);
  pushMatrix();
  translate(x,y);
  line(-CROSS_SIZE,0,min(HEIGHT, WIDTH)/5,0);
  line(0,-CROSS_SIZE,0,CROSS_SIZE);
  float az = atan2(myY-y,myX-x);
  popMatrix();
  noFill();
  if (az < 0) az = TWO_PI + az;
  arc(x,y,min(HEIGHT, WIDTH)/4, min(HEIGHT, WIDTH)/4, 0, az);

  String s = "LAT: " + lat; 
  text(s, 10, 350);
  s = "LON: " + lon;
  text(s, 10, 330);
  s = "THETA: " + angleText(theta);
  fill(255,0,0);
  text(s, 10, 310);
  s = "AZIMUTH: " + angleText(az);
  fill(0,255,0);
  text(s, 10, 290);
  s = "RECEIVED: " + lastMsgReceived;
  fill(255,255,255);
  text(s, 10, 20);
  s = "SENT: " + lastMsgSent;
  text(s, 10, 40);
}

