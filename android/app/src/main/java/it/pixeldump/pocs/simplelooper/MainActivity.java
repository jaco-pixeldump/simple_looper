package it.pixeldump.pocs.simplelooper;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.util.Log;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import org.puredata.android.io.AudioParameters;
import org.puredata.android.io.PdAudio;
import org.puredata.android.service.PdPreferences;
import org.puredata.core.PdBase;
import org.puredata.core.PdReceiver;
import org.puredata.core.utils.IoUtils;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;

public class MainActivity extends FlutterActivity {

  private static String LOG_TAG = "SIMPLE_LOOPER";
  private static final String METHOD_CHANNEL = "it.pixeldump.pocs.simplelooper";
  public static final String EVENT_VUMETER = "it.pixeldump.pocs.simplelooper/vumeter";

  private PdReceiver receiver = new PdReceiver() {

    private void pdPost(String msg) {
      print(msg);
    }

    @Override
    public void print(String s) {
      Log.v(LOG_TAG, "received: " +s);
    }

    @Override
    public void receiveBang(String source) {
      pdPost("bang");
    }

    @Override
    public void receiveFloat(String source, float x) {

      pdPost(source +" - float: " + x);

      if(source.equals("vuDrum")){
        onVUMeter("drum", x);
      }
      else if(source.equals("vuBass")){
        onVUMeter("bass", x);
      }
    }

    @Override
    public void receiveList(String source, Object... args) {
      pdPost("list: " + Arrays.toString(args));
    }

    @Override
    public void receiveMessage(String source, String symbol, Object... args) {
      pdPost("message: " + Arrays.toString(args));
    }

    @Override
    public void receiveSymbol(String source, String symbol) {
      pdPost("symbol: " + symbol);
    }
  };


  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);

    AudioParameters.init(this);
    PdPreferences.initPreferences(getApplicationContext());

    GeneratedPluginRegistrant.registerWith(this);

    initPd();
    initMethodHandlers();
    initEventHandlers();
  }

  private void initPd() {
    //dispatcher = new PdUiDispatcher();
    PdBase.setReceiver(receiver);
    PdBase.subscribe("vuDrum");
    PdBase.subscribe("vuBass");

    int sampleRate = AudioParameters.suggestSampleRate();

    try {
      PdAudio.initAudio(sampleRate, 0, 2, 8, true);
      loadPdPatch();
      PdAudio.startAudio(this);
      PdBase.sendFloat("dspToggle", 0.0f);
      PdBase.sendFloat("vuToggle", 0.0f);
    } catch (IOException e) {
      Log.v(LOG_TAG, "failed to init pd audio");
    }
  }

  private void onVUMeter(String track, float v) {
    //Log.v(LOG_TAG, "vu drum: " + Float.toString(v));
    Intent intent = new Intent("onVuMeter", null);
    HashMap result = new HashMap();
    result.put("track", track);
    result.put("value", v);
    intent.putExtra("vuMeter", result);
    sendBroadcast(intent);
  }

  private void loadPdPatch() throws IOException {
    File dir = getFilesDir();
    IoUtils.extractZipResource(getResources().openRawResource(R.raw.inlet_loopers), dir, true);
    File patchFile = new File(dir, "inlet_loopers.pd");
    PdBase.openPatch(patchFile.getAbsolutePath());
  }

  private void initMethodHandlers() {

    new MethodChannel(getFlutterView(), METHOD_CHANNEL).setMethodCallHandler(
            new MethodChannel.MethodCallHandler() {
              @Override
              public void onMethodCall(MethodCall call, MethodChannel.Result result) {

                if (call.method.equals("dspToggle")) {
                  double dspToggle = call.argument("toggle");
                  PdBase.sendFloat("dspToggle", (float) dspToggle);
                  PdBase.sendFloat("vuToggle", 0.0f);
                }
                else if (call.method.equals("bangStart")) {
                  PdBase.sendFloat("vuToggle", 1.0f);
                  PdBase.sendBang("bangStart");
                }
                else if (call.method.equals("bangStop")) {
                  PdBase.sendFloat("vuToggle", 0.0f);
                  PdBase.sendBang("bangStop");
                }
                else if(call.method.equals("looperSliderSet")){
                  String slider = call.argument("source") +"Volume";
                  double value = call.argument("value");
                  PdBase.sendFloat(slider, (float) value);
                }
              }
            });
  }

  private void initEventHandlers() {
    new EventChannel(getFlutterView(), EVENT_VUMETER).setStreamHandler(
            new EventChannel.StreamHandler() {
              private BroadcastReceiver vuMeterBroadcastReceiver;

              @Override
              public void onListen(Object args, final EventChannel.EventSink events) {
                Log.w(LOG_TAG, "adding listener");
                vuMeterBroadcastReceiver = createVuMeterReceiver(events);
                registerReceiver(vuMeterBroadcastReceiver, new IntentFilter("onVuMeter"));
              }

              @Override
              public void onCancel(Object args) {
                Log.w(LOG_TAG, "cancelling listener");
              }
            }
    );
  }

  private BroadcastReceiver createVuMeterReceiver(final EventChannel.EventSink events) {
    return new BroadcastReceiver() {
      @Override
      public void onReceive(Context context, Intent intent) {
        HashMap intentResult = (HashMap) intent.getSerializableExtra("vuMeter");
        events.success(intentResult);
      }
    };
  }

  @Override
  protected void onPause() {
    super.onPause();
    PdAudio.stopAudio();
  }

  @Override
  protected void onResume() {
    super.onResume();
    PdAudio.startAudio(this);
  }
}
