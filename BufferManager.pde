class BufferManager {
  ArrayList <BufferHead> bufHeads;

  BufferManager(float[][] _buf, int _res, int _numBufHeads) {
    bufHeads = new ArrayList();
    for (int i=0; i<_numBufHeads; i++) {
      bufHeads.add(new BufferHead(_buf, _res, i));
    }
    // connect all fbs
    for (int i=0; i<numBufHeads; i++) {
      for (int j=0; j<numBufHeads; j++) {
        bufHeads.get(i).fbGains[j].addInput(bufHeads.get(j).lpf);
      }
    }
  }

  void setResolution(int _res) {
    for (BufferHead bH : bufHeads) {
      bH.resolution = _res;
      bH.writeLocation.x = (int)bH.writeLocation.x / _res * _res;
      bH.writeLocation.y = (int)bH.writeLocation.y / _res * _res;
    }
  }

  void setReadVelocityAll(float x, float y) {
    for (BufferHead bH : bufHeads) {
      bH.readVelocity = new PVector(x, y);
    }
  }

  void setReadVelocity(int which, float x, float y) {
    bufHeads.get(which).readVelocity = new PVector(x, y);
  }

  void incReadVelocity(int which) {
    if (bufHeads.get(which).readVelocity.x == 0) bufHeads.get(which).readVelocity.x = 0.001;
    bufHeads.get(which).readVelocity.x *= 1.0005;
    //bufHeads.get(which).readVelocity.x += 0.001;
  }

  void decReadVelocity(int which) {
    bufHeads.get(which).readVelocity.x *= 0.9995;
    //bufHeads.get(which).readVelocity.x -= 0.001;
  }

  void setWriteVelocityAll(float x, float y) {
    for (BufferHead bH : bufHeads) {
      bH.writeVelocity = new PVector(x, y);
    }
  }

  void setWriteVelocity(int which, float x, float y) {
    bufHeads.get(which).writeVelocity = new PVector(x, y);
  }

  void incWriteVelocity(int which) {
    if (bufHeads.get(which).writeVelocity.x == 0) bufHeads.get(which).writeVelocity.x = 0.001;
    bufHeads.get(which).writeVelocity.x *= 1.0005;
  }

  void decWriteVelocity(int which) {
    bufHeads.get(which).writeVelocity.x *= 0.9995;
  }


  //void setRemainMix(int which, float mix) {
  //  bufHeads.get(which).remainMixGlide.setValue(mix);
  //}

  //void setRemainMixAll(float mix) {
  //  for (BufferHead bH : bufHeads) {
  //    bH.remainMixGlide.setValue(mix);
  //  }
  //}


  void setSelfFb(int which, float fb) {
    bufHeads.get(which).fbGainGlides[which].setValue(fb);
  }

  void setSelfFbAll(float fb) {
    for (int i=0; i<numBufHeads; i++) {
      bufHeads.get(i).fbGainGlides[i].setValue(fb);
    }
  }


  void setFb(int bufHead, int which, float fb) {
    bufHeads.get(bufHead).fbGainGlides[which].setValue(fb);
  }

  void setCrossFbAll(float fb) {
    for (int i=0; i<numBufHeads; i++) {
      for (int j=0; j<numBufHeads; j++) {
        if (i!=j) bufHeads.get(i).fbGainGlides[j].setValue(fb);
      }
    }
  }


  void setHpf(int which, float freq) {
    bufHeads.get(which).hpfGlide.setValue(freq);
  }

  void setHpfQ(int which, float q) {
    bufHeads.get(which).hpfQGlide.setValue(q);
  }

  void setHpfAll(float freq) {
    for (BufferHead bH : bufHeads) {
      bH.hpfGlide.setValue(freq);
    }
  }


  void setLpf(int which, float freq) {
    bufHeads.get(which).lpfGlide.setValue(freq);
  }

  void setLpfQ(int which, float q) {
    bufHeads.get(which).lpfQGlide.setValue(q);
  }

  void setLpfAll(float freq) {
    for (BufferHead bH : bufHeads) {
      bH.lpfGlide.setValue(freq);
    }
  }


  void followWriteHead() {
    for (BufferHead bH : bufHeads) {
      bH.followWriteHead();
    }
  }

  void allignWriteHeadVelocities() {
    for (int i=0; i<bufHeads.size(); i++) {
      float otherVelos = 0;
      float veloDiff = 0;
      for (int j=0; j<bufHeads.size(); j++) {
        if (i!=j) otherVelos += bufHeads.get(j).writeVelocity.x;
      }
      otherVelos = otherVelos / (bufHeads.size()-1);
      veloDiff = otherVelos - bufHeads.get(i).writeVelocity.x;
      if (allign > 0) {
        bufHeads.get(i).writeVelocity.x += 0.001 * sqrt(allign) * veloDiff;
      } else {
        if (veloDiff > 0) {
          bufHeads.get(i).writeVelocity.x -= 0.001 * sqrt(abs(allign)) * max(0.001, veloDiff);
        } else {
          bufHeads.get(i).writeVelocity.x -= 0.001 * sqrt(abs(allign)) * min(-0.001, veloDiff);
        }
      }
    }
  }
}
