import std.stdio;
import derelict.openal.al;
import std.container;

immutable FREQ = 22050;   // Sample rate
immutable CAP_SIZE = 2048; // How much to capture at a time (affects latency)

void main() {
  // Load the OpenAL library.
  DerelictAL.load();
  writeln("Loaded OpenAL");
    
  // A quick and dirty queue of buffer objects
  //ALuint[] bufferQueue; 
  DList!ALuint bufferQueue; 

  ALenum errorCode=0;
  ALuint[16] helloBuffer;
  ALuint[1] helloSource;

  ALCdevice* audioDevice = alcOpenDevice(null); // Request default audio device
  errorCode = alcGetError(audioDevice);
  ALCcontext* audioContext = alcCreateContext(audioDevice,null); // Create the audio context
  alcMakeContextCurrent(audioContext);
  errorCode = alcGetError(audioDevice);
  // Request the default capture device with a half-second buffer
  ALCdevice* inputDevice = alcCaptureOpenDevice(null, FREQ, AL_FORMAT_MONO16, FREQ/2);
  errorCode = alcGetError(inputDevice);
  alcCaptureStart(inputDevice); // Begin capturing
  errorCode = alcGetError(inputDevice);

  alGenBuffers(16,&helloBuffer[0]); // Create some buffer-objects
  errorCode = alGetError();

  // Queue our buffers onto an STL list
  for (int ii=0;ii<16;++ii) {
    bufferQueue.insertBack(helloBuffer[ii]);
  }

  alGenSources (1, &helloSource[0]); // Create a sound source
  errorCode = alGetError();

  short[FREQ*2] buffer;
  // A buffer to hold captured audio
  ALCint samplesIn=0;  // How many samples are captured
  ALint availBuffers=0; // Buffers to be recovered
  ALuint myBuff; // The buffer we're using
  ALuint[16] buffHolder; // An array to hold catch the unqueued buffers
  bool done = false;
  while (!done) { // Main loop
    // Poll for recoverable buffers
    alGetSourcei(helloSource[0],AL_BUFFERS_PROCESSED,&availBuffers);
    if (availBuffers>0) {
      alSourceUnqueueBuffers(helloSource[0], availBuffers, cast(uint *) buffHolder);
      for (int ii=0;ii<availBuffers;++ii) {
        // Push the recovered buffers back on the queue
        bufferQueue.insertBack(buffHolder[ii]);
      }
    }
    // Poll for captured audio
    alcGetIntegerv(inputDevice,ALC_CAPTURE_SAMPLES,1,&samplesIn);
    if (samplesIn>CAP_SIZE) {
      // Grab the sound
      alcCaptureSamples(inputDevice, cast(void*) buffer, CAP_SIZE);

      //***** Process/filter captured data here *****//
      //for (int ii=0;ii<CAP_SIZE;++ii) {
      //  buffer[ii]*=0.1; // Make it quieter
      //}

      // Stuff the captured data in a buffer-object
      if (!bufferQueue.empty()) { // We just drop the data if no buffers are available
        myBuff = bufferQueue.front(); 
        bufferQueue[].popFront();
        alBufferData(myBuff, AL_FORMAT_MONO16, cast(void *) buffer, CAP_SIZE * short.sizeof, FREQ);

        // Queue the buffer
        alSourceQueueBuffers(helloSource[0],1,&myBuff);

        // Restart the source if needed
        // (if we take too long and the queue dries up,
        //  the source stops playing).
        ALint sState=0;
        alGetSourcei(helloSource[0],AL_SOURCE_STATE,&sState);
        if (sState!=AL_PLAYING) {
          alSourcePlay(helloSource[0]);
        }
      }
    }
  }
  // Stop capture
  alcCaptureStop(inputDevice);
  alcCaptureCloseDevice(inputDevice);

  // Stop the sources
  alSourceStopv(1,&helloSource[0]);
  for (int ii=0;ii<1;++ii) {
    alSourcei(helloSource[ii],AL_BUFFER,0);
  }
  // Clean-up
  alDeleteSources(1, &helloSource[0]);
  alDeleteBuffers(16, &helloBuffer[0]);
  errorCode = alGetError();
  alcMakeContextCurrent(null);
  errorCode = alGetError();
  alcDestroyContext(audioContext);
  alcCloseDevice(audioDevice);
}
