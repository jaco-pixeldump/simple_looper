import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen/screen.dart';

import './VUPainter.dart';

void main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setEnabledSystemUIOverlays([]);

  Screen.keepOn(true);
  runApp(new MyApp(title: 'simple looper'));
}

class MyApp extends StatefulWidget {
  final String title;

  MyApp({Key key, this.title}) : super(key: key);

  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const METHOD_CHANNEL = 'it.pixeldump.pocs.simplelooper';
  static const platformChannel = const MethodChannel(METHOD_CHANNEL);

  static const EVENT_VUMETER = 'it.pixeldump.pocs.simplelooper/vumeter';
  static const EventChannel eventVuMeter = const EventChannel(EVENT_VUMETER);

  bool _bangStatus = false;
  bool _playStatus = false;

  double _drumVolume = 0;
  double _bassVolume = 0;

  double _drumLevel = -100;
  double _bassLevel = -100;

  //
  void _clearVuMeters({index: 3}) {
    double dLevel = index & 1 > 0 ? -100 : _drumLevel;
    double bLevel = index & 2 > 0 ? -100 : _bassLevel;

    setState(() {
      _drumLevel = dLevel;
      _bassLevel = bLevel;
    });
  }

  void _toggleAudio(newValue) {
    double dspToggle = newValue ? 1.0 : 0.0;

    if (_playStatus && !newValue) {
      _onBangToggle();
    }

    setState(() {
      _clearVuMeters();
      _playStatus = newValue;
    });

    platformChannel.invokeMethod('dspToggle', {'toggle': dspToggle});
  }

  void _onBangToggle() {
    bool bStatus = !_bangStatus;

    if (bStatus) {
      if (!_playStatus) {
        if (_drumVolume == 0 && _bassVolume == 0) {
          _onDrumVolumeChange(.25);
          _onBassVolumeChange(.25);
        }

        _toggleAudio(true);
      }

      platformChannel.invokeMethod('bangStart');
    } else {
      platformChannel.invokeMethod('bangStop');
    }

    setState(() {
      _bangStatus = bStatus;
      _clearVuMeters();
    });
  }

  void _onDrumVolumeChange(newValue) {
    platformChannel.invokeMethod('looperSliderSet', {'source': 'drum', 'value': newValue});

    if (newValue < .1) _clearVuMeters(index: 1);

    setState(() {
      _drumVolume = newValue;
    });
  }

  void _onBassVolumeChange(newValue) {
    platformChannel.invokeMethod('looperSliderSet', {'source': 'bass', 'value': newValue});

    if (newValue < .1) _clearVuMeters(index: 2);

    setState(() {
      _bassVolume = newValue;
    });
  }

  @override
  void initState() {
    super.initState();
    platformChannel.invokeMethod('dspToggle', {'toggle': 0.0});

    eventVuMeter.receiveBroadcastStream().listen((dynamic evt) {
      _updateVuMeter(evt);
    });
  }

  void _updateVuMeter(evt) {
    if (!_bangStatus || !_playStatus) {
      _clearVuMeters();
      return;
    }

    if (evt['track'] == 'drum' && _drumVolume > 0) {
      setState(() {
        _drumLevel = evt['value'];
      });
    } else if (_bassVolume > 0) {
      setState(() {
        _bassLevel = evt['value'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/app_bck_01.png'),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(48),
                child: Text(
                  widget.title,
                  style: TextStyle(fontFamily: 'VDub-Regular', color: Colors.white, fontSize: 22),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 64,
                      child: Text(
                        'drum',
                        style: TextStyle(color: Colors.white, fontFamily: 'VDub-Regular'),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                          activeColor: Colors.white,
                          inactiveColor: Colors.blue[900],
                          min: 0,
                          max: 1,
                          divisions: 10,
                          value: _drumVolume,
                          onChanged: _onDrumVolumeChange),
                    ),
                  ],
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                  child: CustomPaint(
                    foregroundPainter: VUPainter(
                      lineColor: Colors.cyan,
                      level: _drumLevel,
                    ),
                  ),
                ),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 64,
                      child: Text(
                        'bass',
                        style: TextStyle(color: Colors.white, fontFamily: 'VDub-Regular'),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                          activeColor: Colors.white,
                          inactiveColor: Colors.blue[900],
                          min: 0,
                          max: 1,
                          divisions: 10,
                          value: _bassVolume,
                          onChanged: _onBassVolumeChange),
                    )
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 48),
                    child: CustomPaint(
                      foregroundPainter: VUPainter(
                        lineColor: Colors.blue,
                        level: _bassLevel,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(60.0)),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          'dsp',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontFamily: 'VDub-Regular',
                          ),
                        ),
                        Switch(
                          activeColor: Colors.blue[900],
                          inactiveThumbColor: Colors.blue[200],
                          value: _playStatus,
                          onChanged: _toggleAudio,
                        ),
                        FloatingActionButton(
                          backgroundColor: Colors.blue[900],
                          onPressed: _onBangToggle,
                          child: new Icon(_bangStatus ? Icons.stop : Icons.play_arrow),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
