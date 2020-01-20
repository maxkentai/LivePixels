/* //<>//
1.03  bufBuf[][], class bufferHead, read follows write
 1.05 dead end
 1.06 copy of 1.03
 1.07 readVelo relativ zu writeVelo
 
 // Buffer.buf default buffer size is 4096
 1.02 hpd added
 1.03 r/w velo coarse + fine
 - r/w +/- 0.01% mit button , led fb rot = value > faderstellung unteres grün : value < faderstellung, gelb = match
 - resolution link/rechts
 1.04 wunderkammer
 1.05 4 channel version, signal in mit fb verbessern? faun compressor ändern? ripple effect? different convolutionX? volume control, convolvey wie x
 convolution auf buffer beschränken
 
 
 */



import beads.*;
import org.jaudiolibs.beads.AudioServerIO;
import java.util.Arrays; 
import controlP5.*;
import themidibus.*; //Import the library

MidiBus myBus; // The MidiBus
int[] midiCCs;  // control change values received from the midi controller

AudioContext ac;

IOAudioFormat audioFormat;
float sampleRate = 44100;
int buffer = 512;
int bitDepth = 16;
int inputs = 2;
int outputs = 6;
boolean stereo = true;  // stereo or quad
int numBufHeads = 4;

BufferManager bufManager;

ControlP5 cp5;

float[][] bufBuf;
int bufWidth = 1024;
int bufSize = bufWidth*bufWidth;
int resolutionExp = 3;
int resolution;

Preference myPrefs = new Preference();

WavePlayer signal;
UGen micIn; 
float signalMix=0.5;
float remainMix = 0.2;
float crossFb = 1.0;
float selfFb = 0.6;

Glide signalGainGlide;
Glide crossFbGainGlide;
Glide selfFbGainGlide;

PImage img;    // the image to display and buffer for everything
PImage imgDisp;

boolean convolve = false;
boolean convolveX = true;
boolean convolveY=false;
int convRange;
boolean dither;
int bright = 255;
boolean glitch=false;
boolean convWrap;  // convolve wrap around
int view_w = 1024;
int view_h = 1024;
boolean START_FULLSCREEN = true;
boolean limit = true;
boolean quantize = true;
boolean norm = true;
//boolean gate;

Slider remainMixSlider;
Slider signalMixSlider;
Slider crossFbSlider;
Slider selfFbSlider;
Slider resoSlider;


Slider writeXIncSliderL;
Slider writeXIncSliderR;
Slider readXIncSliderL;
Slider readXIncSliderR;

Slider hpfFilterSliderL;
Slider lpfFilterSliderL;
float lpfFilterFreqL;
float hpfFilterFreqL;
Glide lpfFilterGlideL;
Glide hpfFilterGlideL;
Glide lpfFilterQGlideL;
Glide hpfFilterQGlideL;

Slider hpfFilterSliderR;
Slider lpfFilterSliderR;
float lpfFilterFreqR;
float hpfFilterFreqR;
Glide lpfFilterGlideR;
Glide hpfFilterGlideR;
Glide lpfFilterQGlideR;
Glide hpfFilterQGlideR;

Glide outGainGlide;

Slider followSlider;
float follow = 0.5;
Slider allignSlider;
float allign = 0.5;

Slider rwVeloFactorSlider;
float rwVeloFactor = 1.0;

float writeXInc = 1.01;
float writeYInc = 0.01;

float writeXInc2 = 0.99;
float writeYInc2 = 0.05;

boolean[] incReadVelo = {false, false};
boolean[] decReadVelo = {false, false};
boolean[] incWriteVelo = {false, false};
boolean[] decWriteVelo = {false, false};

int imgXOffset;
int imgYOffset;

int guiXOffR;
int guiXOffL;
int guiYOff;


boolean printscreen = false;
boolean debug = false;
boolean setupMode = false;
boolean freeze;
boolean record;
boolean showFlowField;
boolean showKinectImage;

float testLength;

float rmsRes;
Slider rmsResSlider;

float glitchLevel = 0.0;
Slider glitchLevelSlider;

float limitVal = 1.0;
Slider limitValSlider;


PShader deform;
boolean shader;

public void settings() {
  fullScreen(P2D, 1);
}


void setup() {
  myBus = new MidiBus(this, "Launch Control XL", "Launch Control XL"); 
  midiCCs = new int[128];

  imgXOffset = (width-bufWidth)/2; // for the psoitioning of the image on the canvas
  imgYOffset = (height-bufWidth)/2;
  guiXOffR = (width + bufWidth)/2 + 20;
  guiXOffL = (width - bufWidth)/2 - 180;
  guiYOff = height/2;

  // load Preferences
  if (myPrefs.loadPref() == 0) {  // loaded ok
    //for (int i = 0; i < projectionPoints.length; i++) {
    //  projectionPoints[i] = new PVector(myPrefs.getFloat("p"+i+"x"), myPrefs.getFloat("p"+i+"y"));
    //}
    //threshold = myPrefs.getFloat("threshold");
  } else {
    //projectionPoints[0] = new PVector(10, 10);
    //projectionPoints[1] = new PVector(kinect.width - 10, 10);
    //projectionPoints[2] = new PVector(kinect.width - 10, kinect.height - 10);
    //projectionPoints[3] = new PVector(10, kinect.height - 10);
  }
  //calcProjPixels();


  if (stereo) {
    ac = new AudioContext(128);
  } else {
    audioFormat = new IOAudioFormat(sampleRate, bitDepth, inputs, outputs);
    ac = new AudioContext(new AudioServerIO.Jack(), buffer, audioFormat);
  }

  img = new PImage(bufWidth, bufWidth, RGB);
  imgDisp = new PImage(bufWidth, bufWidth, RGB);
  bufBuf = new float[bufWidth][bufWidth];
  resolution = (int)pow(2, resolutionExp);

  bufManager = new BufferManager(bufBuf, resolution, numBufHeads);

  micIn = ac.getAudioInput();
  signalGainGlide = new Glide(ac, 0, 20);
  Gain signalGain = new Gain(ac, 1, signalGainGlide);
  signalGain.addInput(micIn);

  bufManager.bufHeads.get(0).input.addInput(signalGain);
  bufManager.bufHeads.get(1).input.addInput(signalGain);

  if (numBufHeads == 4) {
    bufManager.bufHeads.get(2).input.addInput(signalGain);
    bufManager.bufHeads.get(3).input.addInput(signalGain);
  }

  Gain[] outs = new Gain[numBufHeads];
  outGainGlide = new Glide(ac, 0.1, 20);

  for (int i = 0; i<numBufHeads; i++) {
    //outs[i] = new Gain(ac, 1, 0.1);
    outs[i] = new Gain(ac, 1, outGainGlide);
    outs[i].addInput(bufManager.bufHeads.get(i).bufRead);
    if (stereo) {
      ac.out.addInput(i%2, outs[i], 0);  // connect bufferreader to output
    } else {
      ac.out.addInput(i, outs[i], 0);  // connect bufferreader to output
    }
  }




  ac.start();


  deform = loadShader("deform.glsl");
  deform.set("resolution", float(width), float(height));


  // --------------------------------------------
  cp5 = new ControlP5(this);
  if (!debug) cp5.setVisible(false);

  remainMixSlider = cp5.addSlider("remainMix")
    .setPosition(guiXOffR, guiYOff + 0)
    .setRange(0, 1.0)
    ;
  signalMixSlider = cp5.addSlider("signalMix")
    .setPosition(guiXOffR, guiYOff + 10)
    .setRange(0, 2.0)
    ;
  signalMixSlider.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        signalGainGlide.setValue(signalMix);
      }
    }
  }
  );

  crossFbSlider = cp5.addSlider("crossFb")
    .setPosition(guiXOffR, guiYOff + 20)
    .setRange(0, 1.0)
    ;
  crossFbSlider.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setCrossFbAll(crossFbSlider.getValue());
      }
    }
  }
  );

  selfFbSlider = cp5.addSlider("selfFb")
    .setPosition(guiXOffR, guiYOff + 30)
    .setRange(0, 1.0)
    ;
  selfFbSlider.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setSelfFbAll(selfFbSlider.getValue());
      }
    }
  }
  );


  resoSlider = cp5.addSlider("resolutionExp")
    .setPosition(guiXOffR, guiYOff + 40)
    .setRange(0, 10)
    ;
  resoSlider.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        resolution = (int)pow(2, (int)resoSlider.getValue());
        bufManager.setResolution(resolution);
      }
    }
  }
  );


  // -------------------------
  readXIncSliderL = cp5.addSlider("readXIncL")
    .setPosition(guiXOffL, guiYOff + 60)
    .setRange(0, 20)
    ;
  readXIncSliderL.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setReadVelocity(0, readXIncSliderL.getValue(), 0);
        if (numBufHeads == 4) {        
          bufManager.setReadVelocity(2, readXIncSliderL.getValue()*1.02, 0);
        }
      }
    }
  }
  );

  writeXIncSliderL = cp5.addSlider("writeXIncL")
    .setPosition(guiXOffL, guiYOff + 70)
    .setRange(0, 20)
    ;
  writeXIncSliderL.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setWriteVelocity(0, writeXIncSliderL.getValue(), writeYInc);
        if (numBufHeads == 4) {        
          bufManager.setWriteVelocity(2, writeXIncSliderL.getValue()*1.02, 0);
        }
      }
    }
  }
  );


  readXIncSliderR = cp5.addSlider("readXIncR")
    .setPosition(guiXOffR, guiYOff + 60)
    .setRange(0, 20)
    ;
  readXIncSliderR.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setReadVelocity(1, readXIncSliderR.getValue(), 0);
        if (numBufHeads == 4) {        
          bufManager.setReadVelocity(3, readXIncSliderR.getValue()*1.02, 0);
        }
      }
    }
  }
  );

  writeXIncSliderR = cp5.addSlider("writeXIncR")
    .setPosition(guiXOffR, guiYOff + 70)
    .setRange(0, 20)
    ;
  writeXIncSliderR.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setWriteVelocity(1, writeXIncSliderR.getValue(), writeYInc2);
        if (numBufHeads == 4) {        
          bufManager.setWriteVelocity(3, writeXIncSliderR.getValue()*1.02, 0);
        }
      }
    }
  }
  );


  followSlider = cp5.addSlider("follow")
    .setPosition(guiXOffR, guiYOff + 90)
    .setRange(-1, 1)
    ;

  rwVeloFactorSlider = cp5.addSlider("rwVeloFactor")
    .setPosition(guiXOffR, guiYOff + 100)
    .setRange(-2, 2)
    ;

  allignSlider = cp5.addSlider("allign")
    .setPosition(guiXOffR, guiYOff + 110)
    .setRange(-1, 1)
    ;


  hpfFilterSliderL = cp5.addSlider("HPF_L")
    .setPosition(guiXOffL, guiYOff + 120)
    .setRange(0, 127)
    ;
  hpfFilterSliderL.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setHpf(0, midiToFreq(hpfFilterSliderL.getValue()));
        if (numBufHeads == 4) {
          bufManager.setHpf(2, midiToFreq(hpfFilterSliderL.getValue()));
        }
      }
    }
  }
  );

  lpfFilterSliderL = cp5.addSlider("LPF_L")
    .setPosition(guiXOffL, guiYOff + 130)
    .setRange(0, 127)
    ;
  lpfFilterSliderL.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setLpf(0, midiToFreq(lpfFilterSliderL.getValue()));
        if (numBufHeads == 4) {
          bufManager.setLpf(2, midiToFreq(lpfFilterSliderL.getValue()));
        }
      }
    }
  }
  );

  hpfFilterSliderR = cp5.addSlider("HPF_R")
    .setPosition(guiXOffR, guiYOff + 120)
    .setRange(0, 127)
    ;
  hpfFilterSliderR.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setHpf(1, midiToFreq(hpfFilterSliderR.getValue()));
        if (numBufHeads == 4) {
          bufManager.setHpf(3, midiToFreq(hpfFilterSliderR.getValue()));
        }
      }
    }
  }
  );

  lpfFilterSliderR = cp5.addSlider("LPF_R")
    .setPosition(guiXOffR, guiYOff + 130)
    .setRange(0, 127)
    ;
  lpfFilterSliderR.addCallback(new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      if (theEvent.getAction()==ControlP5.ACTION_BROADCAST) {
        bufManager.setLpf(1, midiToFreq(lpfFilterSliderR.getValue()));
        if (numBufHeads == 4) {
          bufManager.setLpf(3, midiToFreq(lpfFilterSliderR.getValue()));
        }
      }
    }
  }
  );

  rmsResSlider = cp5.addSlider("rmsRes")
    .setPosition(guiXOffR, guiYOff + 140)
    .setRange(-1, 1)
    ;

  glitchLevelSlider = cp5.addSlider("glitchLevel")
    .setPosition(guiXOffR, guiYOff + 150)
    .setRange(0, 1)
    ;

  limitValSlider = cp5.addSlider("limitVal")
    .setPosition(guiXOffR, guiYOff + 160)
    .setRange(0, 1)
    ;
}





void draw() {
  background(0);


  if (setupMode) {
    //
  } else {  // not setupMode
    bufManager.followWriteHead();
    bufManager.allignWriteHeadVelocities();
    updateLEDs();
    updateGUI();

    if (quantize) quantizePixels();
    if (numBufHeads == 2) {
      if (convolve || sqrt(bufManager.bufHeads.get(0).rmsVal) < glitchLevel || sqrt(bufManager.bufHeads.get(1).rmsVal) < glitchLevel) convolve();
    } else {
      if (convolve || sqrt(bufManager.bufHeads.get(0).rmsVal) < glitchLevel || sqrt(bufManager.bufHeads.get(1).rmsVal) < glitchLevel ||
        sqrt(bufManager.bufHeads.get(2).rmsVal) < glitchLevel || sqrt(bufManager.bufHeads.get(3).rmsVal) < glitchLevel) convolve();
    }
    // display the image
    image(img, imgXOffset, imgYOffset);

    if (incReadVelo[0]) bufManager.incReadVelocity(0);
    else if (decReadVelo[0]) bufManager.decReadVelocity(0);
    if (incReadVelo[1]) bufManager.incReadVelocity(1);
    else if (decReadVelo[1]) bufManager.decReadVelocity(1);

    if (incWriteVelo[0]) bufManager.incWriteVelocity(0);
    else if (decWriteVelo[0]) bufManager.decWriteVelocity(0);
    if (incWriteVelo[1]) bufManager.incWriteVelocity(1);
    else if (decWriteVelo[1]) bufManager.decWriteVelocity(1);
  }


  if (debug) {

    fill(255);
    textSize(13);
    text("readVelo0.x: "+ String.format("%.5f", bufManager.bufHeads.get(0).readVelocity.x), guiXOffL, guiYOff + 220);
    text("writeVelo0.x: "+ String.format("%.5f", bufManager.bufHeads.get(0).writeVelocity.x), guiXOffL, guiYOff + 230);

    text("readVelo1.x: "+ String.format("%.5f", bufManager.bufHeads.get(1).readVelocity.x), guiXOffR, guiYOff + 220);
    text("writeVelo1.x: "+ String.format("%.5f", bufManager.bufHeads.get(1).writeVelocity.x), guiXOffR, guiYOff + 230);

    if (numBufHeads == 4) {
      text("readVelo2.x: "+ String.format("%.5f", bufManager.bufHeads.get(2).readVelocity.x), guiXOffL, guiYOff + 250);
      text("writeVelo2.x: "+ String.format("%.5f", bufManager.bufHeads.get(2).writeVelocity.x), guiXOffL, guiYOff + 260);

      text("readVelo3.x: "+ String.format("%.5f", bufManager.bufHeads.get(3).readVelocity.x), guiXOffR, guiYOff + 250);
      text("writeVelo3.x: "+ String.format("%.5f", bufManager.bufHeads.get(3).writeVelocity.x), guiXOffR, guiYOff + 260);
    }

    text("Resolution: " + resolution, guiXOffR, guiYOff + 280);
    text("convolve: "+convolve+" X: "+convolveX+" Y: "+convolveY + " dither: "+ dither, guiXOffR, guiYOff + 290);
    text("glitch: "+glitch, guiXOffR, guiYOff + 300);
    text("framerate: "+floor(frameRate)+ " quantize: "+quantize+" limit: "+limit+ " norm: "+ norm, guiXOffR, guiYOff + 310);
    textSize(40);
    text("Pixels", guiXOffR, 80);
    text("(live version)", guiXOffR, 120);
  }

  if (shader) {
    //deform.set("time", millis() / 1000.0);
    deform.set("mouse", float(mouseX), float(mouseY));
    shader(deform);
    imageToBuffer();
  } else resetShader();
} // end draw



void savePrefs() {
  //for (int i = 0; i < projectionPoints.length; i++) {
  //  myPrefs.setNumber("p"+i+"x", projectionPoints[i].x, false);
  //  myPrefs.setNumber("p"+i+"y", projectionPoints[i].y, false);
  //}
  //myPrefs.setNumber("threshold", threshold, false);
  myPrefs.savePref();
}


void convolve() {
  int xstart = 0; 
  int ystart = resolution;
  int xend = img.width;
  int yend = img.height-(2*resolution);
  int matrixsize = 3;

  img.loadPixels();

  if (convolveX) { 
    // Begin our loop for every pixel
    for (int x = xstart; x < xend; x+=resolution ) {
      for (int y = 0; y < img.height; y+=resolution ) {
        //for (int y = ystart; y < yend; y+=bufManager1.resolution ) {
        // Each pixel location (x,y) gets passed into a function called convolution()
        // The convolution() function returns a new color to be displayed.
        color c = convolutionX2(x, y, img); 
        int loc = x + y*img.width;
        img.pixels[loc] = c;
        bufBuf[x][y] = colorToSignal(c);
      }
    }
  }

  if (convolveY) {
    for (int x = xstart; x < xend; x+=resolution ) {
      for (int y = ystart; y < yend; y+=resolution ) {
        // Each pixel location (x,y) gets passed into a function called convolution()
        // The convolution() function returns a new color to be displayed.
        color c = convolutionY2(x, y, img); 
        //color c = convolutionY(x, y, matrixsize, img); 
        int loc = x + y*img.width;
        img.pixels[loc] = c;
        bufBuf[x][y] = colorToSignal(c);
      }
    }
  }

  if (dither) {
    for (int y = 0; y < img.width; y+=resolution ) {
      for (int x = 0; x < img.width; x+=resolution ) {

        int index = index(x, y );
        color pix = img.pixels[index];
        float oldR = red(pix);
        float oldG = green(pix);
        float oldB = blue(pix);
        int factor = 7;
        int newR = round(factor * oldR / 255) * (255/factor);
        int newG = round(factor * oldG / 255) * (255/factor);
        int newB = round(factor * oldB / 255) * (255/factor);
        img.pixels[index] = color(newR, newG, newB);
        bufBuf[x][y] = colorToSignal(img.pixels[index]);

        float errR = oldR - newR;
        float errG = oldG - newG;
        float errB = oldB - newB;


        index = index(x+resolution, y  );
        color c = img.pixels[index];
        float r = red(c);
        float g = green(c);
        float b = blue(c);
        r = r + errR * 7/16.0;
        g = g + errG * 7/16.0;
        b = b + errB * 7/16.0;
        img.pixels[index] = color(r, g, b);
        bufBuf[(x+resolution)%img.width][y] = colorToSignal(img.pixels[index]);

        index = index(x-resolution, y+resolution  );
        c = img.pixels[index];
        r = red(c);
        g = green(c);
        b = blue(c);
        r = r + errR * 3/16.0;
        g = g + errG * 3/16.0;
        b = b + errB * 3/16.0;
        img.pixels[index] = color(r, g, b);
        int n =0;
        if (x-resolution < 0) n = img.width;
        bufBuf[x-resolution + n][(y+resolution)%img.width] = colorToSignal(img.pixels[index]);

        index = index(x, y+resolution);
        c = img.pixels[index];
        r = red(c);
        g = green(c);
        b = blue(c);
        r = r + errR * 5/16.0;
        g = g + errG * 5/16.0;
        b = b + errB * 5/16.0;
        img.pixels[index] = color(r, g, b);
        bufBuf[x][(y+resolution)%img.width] = colorToSignal(img.pixels[index]);


        index = index(x+resolution, y+resolution);
        c = img.pixels[index];
        r = red(c);
        g = green(c);
        b = blue(c);
        r = r + errR * 1/16.0;
        g = g + errG * 1/16.0;
        b = b + errB * 1/16.0;
        img.pixels[index] = color(r, g, b);
        bufBuf[(x+resolution)%img.width][(y+resolution)%img.width] = colorToSignal(img.pixels[index]);
      }
    }
  }

  img.updatePixels();
}

int index(int x, int y) {
  x %= img.width;
  y %= img.width;
  if (x<0) x+= img.width;
  if (y<0) y+= img.width;
  return x + y * bufWidth;
}

color convolutionX(int x, int y, PImage img) {
  float rtotal = 0.0;
  float val1 = 0;
  float val2 = 0;
  float val = 0;

  for (int i = 0; i < 3*resolution; i+=resolution ) {
    int xloc = x + i*resolution-resolution;
    if (xloc < 0) xloc += img.width;
    else if (xloc > img.width-resolution) xloc = xloc - img.width;  
    int loc = constrain(xloc + img.width*y, 0, img.pixels.length-1);

    rtotal += (red(img.pixels[loc]) * 1.0);

    if (i == 0) {
      val1 = red(img.pixels[loc]);
    } else if (i==1) {
      val = red(img.pixels[loc]);
    } else {
      val2 = red(img.pixels[loc]);
    }
  }
  if (val < max(val1, val2)) {
    rtotal = (max(val1, val2) - val) * 0.05 + val;
  } else if (val < max(val1, val2)) {
    //rtotal = val - (max(val1, val2) - val) * 0.05;
  }

  // Make sure RGB is within range
  rtotal = constrain(rtotal, 0, 255);

  // Return the resulting color
  return color(rtotal, rtotal, rtotal);
}


color convolutionX2(int x, int y, PImage img) {
  float rtotal = 0.0;
  float val1 = 0;
  float val2 = 0;
  float val = 0;

  for (int i = 0; i < 3; i++ ) {
    int xloc = x + i*resolution*convRange-resolution*convRange;
    if (xloc < 0) xloc += img.width;
    else if (xloc > img.width-resolution) xloc = xloc - img.width;  
    int loc = constrain(xloc + img.width*y, 0, img.pixels.length-1);

    rtotal += (red(img.pixels[loc]) * 1.0);

    if (i == 0) {
      val1 = red(img.pixels[loc]);
    } else if (i==1) {
      //val = red(img.pixels[loc]);
    } else {
      val2 = red(img.pixels[loc]);
    }
  }
  if (val < max(val1, val2)) {
    rtotal = (max(val1, val2) - val) * 0.05 + val;
  } else if (val < max(val1, val2)) {
    //rtotal = val - (max(val1, val2) - val) * 0.05;
  }

  // Make sure RGB is within range
  rtotal = constrain(rtotal, 0, 255);

  // Return the resulting color
  return color(rtotal, rtotal, rtotal);
}


color convolutionX3(int x, int y, PImage img) {
  float rtotal = 0.0;

  for (int i = 0; i < 3; i++ ) {
    int xloc = x + i*resolution*convRange-resolution*convRange;
    if (xloc < 0) xloc += img.width;
    else if (xloc > img.width-resolution) xloc = xloc - img.width;  
    int loc = constrain(xloc + img.width*y, 0, img.pixels.length-1);

    rtotal += (red(img.pixels[loc]) * 1.0);
  }

  // Make sure RGB is within range
  rtotal = constrain(rtotal / 3, 0, 255);

  // Return the resulting color
  return color(rtotal, rtotal, rtotal);
}


color convolutionY2(int x, int y, PImage img) {
  float rtotal = 0.0;
  float val1 = 0;
  float val2 = 0;
  float val = 0;


  for (int j = 0; j < 3; j++ ) {
    int yloc = y + j*resolution * convRange - resolution * convRange;
    if (yloc < 0) yloc += img.height;
    else if (yloc >= img.height-resolution) yloc = yloc - img.height+resolution;  

    int loc = x + img.width*yloc;
    rtotal += (red(img.pixels[loc]) * 1.0);

    //if (j == 0) {
    //  val1 = red(img.pixels[loc]);
    //} else if (j==1) {
    //  val = red(img.pixels[loc]);
    //} else {
    //  val2 = red(img.pixels[loc]);
    //}
  }


  //if (val < max(val1, val2)) {
  //  rtotal = (max(val1, val2) - val) * 0.05 + val;
  //} else if (val < max(val1, val2)) {
  //  //rtotal = val - (max(val1, val2) - val) * 0.05;
  //}

  // Make sure RGB is within range
  //rtotal = constrain(rtotal, 0, 255);
  rtotal = constrain(rtotal / 3, 0, 255);

  // Return the resulting color
  return color(rtotal, rtotal, rtotal);
}


color convolutionY(int x, int y, int matrixsize, PImage img) {
  float rtotal = 0.0;
  float gtotal = 0.0;
  float btotal = 0.0;
  int offset = matrixsize / 2;

  //for (int j = 0; j < matrixsize; j++ ) {
  for (int j = 0; j < 3*resolution; j+=resolution ) {
    int yloc = y + j*resolution-offset*resolution;
    if (yloc < 0) yloc += img.height;
    else if (yloc > img.height-resolution) yloc = yloc - img.height+resolution;  

    int loc = x + img.width*yloc;
    rtotal += (red(img.pixels[loc]) * 1.0);
    gtotal += (green(img.pixels[loc]) * 1.0);
    btotal += (blue(img.pixels[loc]) * 1.0);
  }

  // Make sure RGB is within range
  rtotal = constrain(rtotal / 3, 0, 255);
  gtotal = constrain(gtotal / 3, 0, 255);
  btotal = constrain(btotal / 3, 0, 255);

  // Return the resulting color
  return color(rtotal, gtotal, btotal);
}




void updateImage() {  // transfer values from buffer to the imgage's pixels array
  img.loadPixels();
  for (int x = 0; x < bufWidth; x++) {
    for (int y = 0; y < bufWidth; y++) {
      img.pixels[y*bufWidth+x] = signalToColor(bufBuf[x][y]);
    }
  }
  img.updatePixels();
}


void quantizePixels() {  // quantise buffer and transfer values to the imgage's pixels array
  img.loadPixels();
  float val;
  color col;
  int res = resolution;
  float resExp;
  for (int x = 0; x < bufWidth; x+=res) {
    //res = randomRes();
    for (int y = 0; y < bufWidth; y+=res) {
      val  = bufBuf[x][y];
      col = signalToColor(val);
      //res = (int)pow(2, round(resolutionExp - sqrt(bufManager.bufHeads.get(0).rmsVal)*resolutionExp* rmsRes));
      if (numBufHeads == 2) {
        resExp =  round(resolutionExp + sqrt(bufManager.bufHeads.get((int)(x/(bufWidth*0.5))).rmsVal) * 10 * rmsRes);
      } else {
        resExp =  round(resolutionExp + sqrt(bufManager.bufHeads.get((int)(y / (int)(bufWidth*0.5) * 2 + x / (int)(bufWidth*0.5))).rmsVal) * 10 * rmsRes);
      }

      //resExp =  round(resolutionExp + sqrt(bufManager.bufHeads.get((int)(x/(bufWidth*0.5))).readVal) * 10 * rmsRes);
      if (resExp < 0) resExp += 10;
      else if (resExp > 10) resExp -= 10;
      res = (int)pow(2, resExp);
      for (int i = 0; i < res; i++) {
        //res = randomRes();
        for (int j = 0; j < res; j++) {
          if ( (x+i) < bufWidth && (y+j) < bufWidth) {
            bufBuf[x+i][y+j] = val;
            //if (i>0 || j>0) bufBuf[x+i][y+j] = val;
            img.pixels[(y+j)*bufWidth+x+i] = col;
          }
        }
      }
    }
  }
  img.updatePixels();
}

void imageToBuffer() {  // transfer values from the imgage's pixels array to the buffer
  img.loadPixels();
  for (int x = 0; x < bufWidth; x++) {
    for (int y = 0; y < bufWidth; y++) {
      bufBuf[x][y] = colorToSignal(img.pixels[y * bufWidth + x]);
    }
  }
}

int randomRes() {
  if (random(100) > 99) {
    return (int)pow(2, round(random(resolutionExp)));
  } else return resolution;
}

color signalToColor(float val) {
  //return color((val+1.0) * 127.5);
  return color((constrain(val, -0.5, 0.5) + 0.5) * 255);
}

float colorToSignal(color col) {
  return red(col)/127.5-1.0;
}

float midiToFreq(float pitch) { // 8-12000 Hz
  return 440 * pow(2, (pitch - 69.0) / 12.0);
}

// MIDI --------------------------------------------
void noteOn(int channel, int pitch, int velocity) {
  switch(pitch) {
  case 41:
    incReadVelo[0] = true;
    break;
  case 42:
    incWriteVelo[0] = true;
    break;
  case 73:
    decReadVelo[0] = true;
    break;
  case 74:
    decWriteVelo[0] = true;
    break;
  case 57:
    incReadVelo[1] = true;
    break;
  case 58:
    incWriteVelo[1] = true;
    break;
  case 89:
    decReadVelo[1] = true;
    break;
  case 90:
    decWriteVelo[1] = true;
    break;
  }
  // Receive a noteOn
  println();
  println("Note On:");
  println("--------");
  println("Channel:"+channel);
  println("Pitch:"+pitch);
  println("Velocity:"+velocity);
}

void noteOff(int channel, int pitch, int velocity) {
  switch(pitch) {
  case 41:
    incReadVelo[0] = false;
    break;
  case 42:
    incWriteVelo[0] = false;
    break;
  case 73:
    decReadVelo[0] = false;
    break;
  case 74:
    decWriteVelo[0] = false;
    break;
  case 57:
    incReadVelo[1] = false;
    break;
  case 58:
    incWriteVelo[1] = false;
    break;
  case 89:
    decReadVelo[1] = false;
    break;
  case 90:
    decWriteVelo[1] = false;
    break;
  }
  // Receive a noteOff
  println();
  println("Note Off:");
  println("--------");
  println("Channel:"+channel);
  println("Pitch:"+pitch);
  println("Velocity:"+velocity);
}


void controllerChange(int channel, int number, int value) {
  // Receive a controllerChange
  midiCCs[number] = value;

  switch (number) {

  case 13: // 1/1 x/y
    remainMixSlider.setValue(value/127.0);
    break;

  case 14: // 2/1
    signalMixSlider.setValue(value/63.5);
    break;

  case 15: // 3/1
    crossFbSlider.setValue(value/127.0);
    break;

  case 16: // 4/1
    selfFbSlider.setValue(value/127.0);
    break;

  case 17: // 5/1
    //followSlider.setValue(value/127.0);
    break;

  case 18: // 6/1
    //allignSlider.setValue(value/127.0);
    break;

  case 20: // 8/1
    outGainGlide.setValue(value/127.0*0.4);
    break;

  case 29:  // 1/2 
    resoSlider.setValue(round(value/12.7));
    break;

  case 30:  // 2/2 
    rmsResSlider.setValue(max(-63, (value - 64)) / 63.0);
    break;

  case 31:  // 3/2 
    glitchLevelSlider.setValue(value/127.0);
    break;

  case 32:  // 4/2 
    convRange = (int)(value/127.0*resolution);
    break;

  case 33:  // 5/2 

    break;

  case 34:  // 6/2 

    break;

  case 36:  // 8/2 
    break;

  case 49:  // 1/3 
    followSlider.setValue(max(-63, (value - 64)) / 63.0);
    break;

  case 50:  // 2/3 
    allignSlider.setValue(max(-63, (value - 64)) / 63.0);
    break;

  case 51:  // 3/3 
    bufManager.setHpfQ(0, max(0.01, value / 63.0));
    if (numBufHeads == 4) {        
      bufManager.setHpfQ(2, max(0.01, value / 63.0));
    }
    break;

  case 52:  // 4/3 
    bufManager.setLpfQ(0, max(0.01, value / 63.0));
    if (numBufHeads == 4) {        
      bufManager.setLpfQ(2, max(0.01, value / 63.0));
    }
    break;

  case 53:  // 5/3 
    break;

  case 54:  // 6/3 
    break;

  case 55:  // 7/3 
    bufManager.setHpfQ(1, max(0.01, value / 63.0));
    if (numBufHeads == 4) {        
      bufManager.setHpfQ(3, max(0.01, value / 63.0));
    }
    break;

  case 56:  // 8/3 
    bufManager.setLpfQ(1, max(0.01, value / 63.0));
    if (numBufHeads == 4) {        
      bufManager.setLpfQ(3, max(0.01, value / 63.0));
    }
    break;

    // sliders
  case 77: // slider 1
    //readXIncSliderL.setValue(value/6.35);
    bufManager.setReadVelocity(0, value/6.35, 0);
    break;

  case 78: // slider 2
    writeXIncSliderL.setValue(value/6.35);
    break;

  case 79: // slider 3
    hpfFilterSliderL.setValue(value);  // hpf
    break;

  case 80: // slider 4
    lpfFilterSliderL.setValue(value);
    break;

  case 81: // slider 5
    readXIncSliderR.setValue(value/6.35);
    break;

  case 82: // slider 6
    writeXIncSliderR.setValue(value/6.35);
    break;

  case 83: // slider 7
    hpfFilterSliderR.setValue(value);  // hpf
    break;

  case 84: // slider 8
    lpfFilterSliderR.setValue(value);
    break;
  }

  println();
  println("Controller Change:");
  println("--------");
  println("Channel:"+channel);
  println("Number:"+number);
  println("Value:"+value);
}

void updateLEDs() {
  float val = bufManager.bufHeads.get(0).readVelocity.x;
  if (val >  midiCCs[77]/6.35 + 1) {  // actual value > fader position
    myBus.sendNoteOn(8, 41, 15); // red led full
    myBus.sendNoteOn(8, 73, 0);  // green led off
  } else if (val >  midiCCs[77]/6.35 + 0.5) {
    myBus.sendNoteOn(8, 41, 14); // red led mid
    myBus.sendNoteOn(8, 73, 0);  // green led off
  } else if (val >  midiCCs[77]/6.35 + 0.1) {
    myBus.sendNoteOn(8, 41, 13); // red led low
    myBus.sendNoteOn(8, 73, 0);  // green led off
  } else if (val <  midiCCs[77]/6.35 - 1) {
    myBus.sendNoteOn(8, 41, 0);   // red led off
    myBus.sendNoteOn(8, 73, 60);  // green full
  } else if (val <  midiCCs[77]/6.35 - 0.5) {
    myBus.sendNoteOn(8, 41, 0);   // red led off
    myBus.sendNoteOn(8, 73, 44);  // green mid
  } else if (val <  midiCCs[77]/6.35 - 0.1) {
    myBus.sendNoteOn(8, 41, 0);   // red led off
    myBus.sendNoteOn(8, 73, 28);  // green low
  } else {
    myBus.sendNoteOn(8, 41, 63);   // amber
    myBus.sendNoteOn(8, 73, 63);   // amber
  }
}


void updateGUI() {
  readXIncSliderL.setValue(bufManager.bufHeads.get(0).readVelocity.x);
  writeXIncSliderL.setValue(bufManager.bufHeads.get(0).writeVelocity.x);
  readXIncSliderR.setValue(bufManager.bufHeads.get(1).readVelocity.x);
  writeXIncSliderR.setValue(bufManager.bufHeads.get(1).writeVelocity.x);
}

// mouse & keys ----------------------------------------------
void mousePressed() { 
  //if (showKinectImage) {
  //  float recDist = 10000;
  //  int recIndex = 0;
  //  PVector mouse = new PVector(mouseX-(width-kinect.width)/2, mouseY-(height-kinect.height)/2);
  //  for (int i = 0; i < projectionPoints.length; i++) {
  //    float dist = PVector.dist(projectionPoints[i], mouse);
  //    if (dist < recDist) { 
  //      recDist = dist;
  //      recIndex = i;
  //    }
  //  }
  //  projectionPoints[recIndex] = mouse;
  //  calcProjPixels();
  //}
}


void keyPressed() {
  if (key == CODED) {
    if (keyCode == UP) {
    } else if (keyCode == DOWN) {
    }
  } else if (key == 'i') {
    //irMode = !irMode;
    //kinect.enableIR(irMode);
  } else if (key == 't') {
    //tpNbr = (tpNbr+1) % 3;
  } else if (key == 'k') {
    showKinectImage = !showKinectImage;
    if (!showKinectImage) savePrefs();
  } else if (key == 'r') {
    //maxDepthU = constrain(maxDepthU+1, minDepth, 2047);
  } else if (key == 'e') {
    //maxDepthU = constrain(maxDepthU-1, minDepth, 2047);
  } else if (key == 'w') {
    //maxDepthL = constrain(maxDepthL+1, minDepth, 2047);
  } else if (key =='q') {
    //maxDepthL = constrain(maxDepthL-1, minDepth, 2047);
  } else  if (key == 'x') {
    convolveX = !convolveX;
  } else  if (key == 'y') {
    convolveY = !convolveY;
  } else  if (key == 'c') {
    convolve = !convolve;
  } else  if (key == 'g') {
    glitch = !glitch;
  } else  if (key == 'l') {
    limit = !limit;
  } else  if (key == 'n') {
    norm = !norm;
  } else  if (key == 'd') {
    //dither = !dither;
    debug = !debug;
    if (debug) {
      cp5.setVisible(true);
      cursor();
    } else {
      cp5.setVisible(false);
      noCursor();
    }
  } else  if (key == 's') {
    shader = !shader;
  } else  if (key == 'f') {
    showFlowField = !showFlowField;
  } else  if (key == 'm') {
    quantize = !quantize;
  }
}
