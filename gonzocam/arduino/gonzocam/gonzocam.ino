#include <avr/sleep.h>
#include <Servo.h>

// pin assign -------------//
#define POT0    A0
#define POT1    A1
#define SENSOR  A3 //if use digital input > set 2
#define SWITCH  4
#define LED     5
#define SV_PUSH 10
#define SV_ROLL 11

//parameters
const long initialDelay    = 20000;
const int pushDuration     = 200;
const int rollCount        = 4;
const int shootDelayMin    = 0;
const int shootDelayMax    = 3000;
const long waitingTimeMin  = 10000;
const long waitingTimeMax  = 120000;
const int pushOff          = 50;
const int pushOn           = 75;
const int blinkInterval    = 500;

//define servo
Servo servoRoll;
Servo servoPush;

//for sequence
boolean shootMode = false;
boolean waitMode = false;
long timeStampShoot = 0;
long timeStampWait = 0;
unsigned int shootDelay;
unsigned long waitingTime;

//sensor
byte sensorLevel;
byte sensorLevelDef;
unsigned int countSensing;
unsigned int countSensingThreshold;

//calibration
unsigned int countLevelLow = 0;
unsigned int countLevelHigh = 0;
unsigned long sensorValLow;
unsigned long sensorValHigh;



void setup()
{
  Serial.begin(9600);

  //Define pin mode
  pinMode(SENSOR, INPUT);
  pinMode(LED, OUTPUT);
  pinMode(SV_ROLL, OUTPUT);
  pinMode(SV_PUSH, OUTPUT);

  //Initialize servo
  servoRoll.attach(SV_ROLL);
  servoPush.attach(SV_PUSH);
  servoRoll.write(180);
  servoPush.write(pushOff);

  //Chnage the sensor mode by switch
  String sensorName;
  if(digitalRead(SWITCH)) sensorName = "MOTION";
  else sensorName = "MIC";
  calibration(sensorName);
  countSensing = 0;

  //save the battery
  set_sleep_mode(SLEEP_MODE_IDLE);
  sleep_mode();
}

void loop(){
  int val = analogRead(SENSOR);
  if(val < 1023/2) sensorLevel = 0;
  else if(val > 1023/2) sensorLevel = 1;

  if(sensorLevel == sensorLevelDef) countSensing = 0;
  else{
    countSensing++;
    Serial.println(countSensing);
  }

  //WAIT MODE //////////////////////////////////////////////////////////////
  if(!shootMode && !waitMode && countSensingThreshold < countSensing){
    Serial.println("SENCING!");
    digitalWrite(LED, HIGH);
    timeStampShoot = millis();
    shootMode = true;
  }

  //SHOOT MODE //////////////////////////////////////////////////////////////
  if(shootMode && !waitMode && timeStampShoot + shootDelay < millis()){

    while(millis() < timeStampShoot + shootDelay + pushDuration){
      servoPush.write(pushOn);
    }
    digitalWrite(LED, LOW);
    servoPush.write(pushOff);
    Serial.println("SHOOT!");

    for(int i=0; i<rollCount; i++){
      for(int j=180; j>0; j--){
        servoRoll.write(j);
        delay(3);
      }
      delay(300);
      servoRoll.write(180);
      delay(500);
    }

    timeStampWait = millis();
    waitMode = true;
    shootMode = false;
  }

  //INTREVAL MODE //////////////////////////////////////////////////////////////
  if(!shootMode && waitMode){
    if(millis() < timeStampWait + waitingTime){
      int i = int((millis() - timeStampWait) / blinkInterval);
      if(i % 2 == 0) digitalWrite(LED, LOW);
      else if(i % 2 == 1) digitalWrite(LED, HIGH);
    }
    else if(timeStampWait + waitingTime < millis()){
      waitMode = false;
      digitalWrite(LED, LOW);
      countSensing = 0;

      set_sleep_mode(SLEEP_MODE_IDLE);
      sleep_mode();
    }
  }

}


void calibration(String sensor){

  while(millis() < initialDelay){
    digitalWrite(LED, HIGH);

    int val = analogRead(SENSOR);
    if(val < 1023/2){
      countLevelLow++;
      sensorValLow = sensorValLow + val;
    }
    else if(val > 1023/2){
      countLevelHigh++;
      sensorValHigh = sensorValHigh + val;
    }
  }

  //define sensor condition
  int valLow = sensorValLow / countLevelLow;
  int valHigh = sensorValHigh / countLevelHigh;

  //set the default sensor state
  if(countLevelLow > countLevelHigh) sensorLevelDef = 0;
  else if(countLevelLow < countLevelHigh) sensorLevelDef = 1;

  //set wating duration by sensor value
  shootDelay = map(analogRead(POT0), 1023, 0, shootDelayMin, shootDelayMax);
  waitingTime = map(analogRead(POT1), 1023, 0, waitingTimeMin, waitingTimeMax);

  //set the threshold by the kind of sensor
  if(sensor == "MIC") countSensingThreshold = 10;
  else if(sensor == "MOTION") countSensingThreshold = 30;

  //sign of finished calibration
  while(millis() < initialDelay + 600){
    int i = int((millis() - initialDelay) / 100);
    if(i % 2 == 0) digitalWrite(LED, LOW);
    else if(i % 2 == 1) digitalWrite(LED, HIGH);
  }

  //for debug
  Serial.print("Count Low = ");
  Serial.print(countLevelLow);
  Serial.print("  ");
  Serial.print("Val Low = ");
  Serial.println(valLow);

  Serial.print("Count High = ");
  Serial.print(countLevelHigh);
  Serial.print("  ");
  Serial.print("Val High = ");
  Serial.println(valHigh);

  Serial.print("Level Def = ");
  Serial.println(sensorLevelDef);
  Serial.println();

  Serial.print("Shoot Delay = ");
  Serial.println(shootDelay);
  Serial.print("Wating Time = ");
  Serial.println(waitingTime);

  digitalWrite(LED, LOW);

}
