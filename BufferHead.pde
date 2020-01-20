class BufferHead {
  float[][] bufBuf;

  PVector readLocation;
  PVector readVelocity;
  PVector readAcceleration;
  int readX;
  int readY;

  PVector writeLocation;
  PVector writeVelocity;
  PVector writeAcceleration;
  int writeX;
  int writeY;

  int resolution;  // 1-1024 buffer stepsize
  int bufWidth;

  PVector minLocation;
  PVector maxLocation;

  Gain input;
  Gain[] fbGains;          // read signal of all bufHeads
  Glide[] fbGainGlides;    // read signal of all bufHeads

  Function bufRead;
  Function bufWrite;

  RMS rms;

  BiquadFilter hpf; 
  Glide hpfGlide;
  BiquadFilter lpf; 
  Glide lpfGlide;
  Glide hpfQGlide; 
  Glide lpfQGlide; 



  float tempReadVal;
  float tempReadValPrev;
  float tempWriteVal;

  int id;

  float rmsVal;
  float readVal;

  BufferHead(float[][] _buf, int _res, int _id) {
    id = _id;
    bufBuf = _buf;
    bufWidth = bufBuf.length;
    resolution = _res;

    readLocation = new PVector(0, 0);
    readVelocity = new PVector(0, 0);
    readAcceleration = new PVector(0, 0);
    writeLocation = new PVector(0, 0);
    writeVelocity = new PVector(0, 0);
    writeAcceleration = new PVector(0, 0);

    if (numBufHeads == 2) {
      if (id==0) {
        minLocation = new PVector(0, 0);
        maxLocation = new PVector(bufWidth/2, bufWidth);
      } else {
        minLocation = new PVector(bufWidth/2, 0);
        maxLocation = new PVector(bufWidth, bufWidth);
      }
    } else {
      if (id==0) {
        minLocation = new PVector(0, 0);
        maxLocation = new PVector(bufWidth/2, bufWidth/2);
      } else if (id == 1) {
        minLocation = new PVector(bufWidth/2, 0);
        maxLocation = new PVector(bufWidth, bufWidth/2);
      } else if (id == 2) {
        minLocation = new PVector(0, bufWidth/2);
        maxLocation = new PVector(bufWidth/2, bufWidth);
      } else if (id == 3) {
        minLocation = new PVector(bufWidth/2, bufWidth/2);
        maxLocation = new PVector(bufWidth, bufWidth);
      }
    }

    input = new Gain(ac, 1);

    bufRead = new Function(input) {
      public float calculate() {
        // get current buffer value 
        readX =  constrain((int)readLocation.x/resolution*resolution, 0, bufWidth-1);
        readY = constrain((int)readLocation.y, 0, bufWidth-1);

        tempReadValPrev = tempReadVal;
        tempReadVal = constrain(bufBuf[readX][readY], -2, 2);
        
        updateLocation(readLocation, readVelocity); 
        readVal = tempReadVal;

        //return constrain(tempReadVal - tempReadValPrev, -2, 2);  // ableitung
        return tempReadVal;
      }
    };

    rms = new RMS(ac, 1, 44);
    //rms = new RMS(ac, 1, 441);
    rms.addInput(bufRead);
    
    Function getRMS = new Function(rms) {
      public float calculate() {
        rmsVal = min(1.0, x[0]);
        return x[0];
      }
    };
    ac.out.addDependent(getRMS);


    bufWrite = new Function(input) {

      public float calculate() {
        // get current buffer value and mix with input signal 
        writeX =  constrain((int)writeLocation.x/resolution*resolution, 0, bufWidth-1);
        writeY = constrain((int)writeLocation.y, 0, bufWidth-1);
        tempWriteVal = bufBuf[writeX][writeY]*remainMix + x[0];

        //tempWriteVal =  pow(2, -2.0 * abs(tempWriteVal) + 0.1) * tempWriteVal ;  
        //tempWriteVal *= (float)Math.atan(tempWriteVal) * 0.63662 ; 
        tempWriteVal =  pow(2, -1.2 * abs(tempWriteVal) + 0.2) * tempWriteVal ;  
        //
        if (limit) {      // limiter 
          tempWriteVal = constrain(tempWriteVal, -limitVal, limitVal);
        } 

        bufBuf[writeX][writeY] = tempWriteVal;
        updateLocation(writeLocation, writeVelocity);

        return tempWriteVal;
      }
    };
    ac.out.addDependent(bufWrite);

    lpfGlide = new Glide(ac, 10000, 20);
    hpfGlide = new Glide(ac, 20, 20);
    hpfQGlide = new Glide(ac, 1, 20);
    lpfQGlide = new Glide(ac, 1, 20);


    hpf = new BiquadFilter(ac, BiquadFilter.HP, hpfGlide, hpfQGlide);
    hpf.addInput(bufRead);
    lpf = new BiquadFilter(ac, BiquadFilter.LP, lpfGlide, lpfQGlide);
    lpf.addInput(hpf);


    fbGainGlides = new Glide[numBufHeads];
    fbGains = new Gain[numBufHeads];
    for (int i=0; i<numBufHeads; i++) {
      fbGainGlides[i] = new Glide(ac, 0, 20);
      fbGains[i] = new Gain(ac, 1, fbGainGlides[i]);
      input.addInput(fbGains[i]);
    }
  }

  void followWriteHead() {
    float veloDiff = writeVelocity.x - readVelocity.x;
    if (follow > 0) {
      readVelocity.x += 0.01 * sqrt(follow) * veloDiff;
    } else {
      if (veloDiff > 0) {
        readVelocity.x -= 0.01 * sqrt(abs(follow)) * max(0.001, veloDiff);
      } else {
        readVelocity.x += 0.01 * sqrt(abs(follow)) * min(-0.001, veloDiff);
      }
    }
  }



  void updateLocation(PVector location, PVector velocity) {  // audio rate
    location.x += velocity.x ;
    //
    while (location.x >= maxLocation.x) {
      location.x -= maxLocation.x - minLocation.x; 
      location.y += resolution;
      while (location.y >= maxLocation.y) {
        location.y -= maxLocation.y - minLocation.y;
      }
    } 
    while (location.x < minLocation.x) {
      location.x += maxLocation.x - minLocation.x; 
      location.y -= resolution;
      while (location.y < minLocation.y) {
        location.y += maxLocation.y - minLocation.y;
      }
    }
  }


  //
}
