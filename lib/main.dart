import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter_baidu_mapapi_map/flutter_baidu_mapapi_map.dart';
import 'package:flutter_baidu_yingyan_trace/flutter_baidu_yingyan_trace.dart';
import 'package:flutter_bmflocation/flutter_bmflocation.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  late BMFMapController myMapController;
  late LocationFlutterPlugin myLocPlugin;

  bool _suc = false;
  double? latitude;
  double? longitude;

  late BMFPolyline _colorsPolyline;
  List<BMFCoordinate> coordinates = [];
  List<int> indexs = [];
  List<Color> colors = [];

  int sum = 0;

  /// 开启鹰眼服务请求类
  final Trace _trace = Trace(serviceId: 240260, entityName: 'sptest');
  BMFMarker? _curLocation;

  // bool isFirst = true;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    TraceSDK.setAgreePrivacy(true);

    /// 动态申请定位权限
    requestLocationPermission();

    BMFMapSDK.setAgreePrivacy(true);
    myLocPlugin = LocationFlutterPlugin();
    myLocPlugin.setAgreePrivacy(true);

    ///接受定位回调
    myLocPlugin.seriesLocationCallback(callback: (BaiduLocation result) {
      // if(result.latitude != null && result.longitude != null) {
        setState(() {
          // isFirst = false;
          latitude = result.latitude;
          longitude = result.longitude;
        });
        print('连续定位回调===$latitude/$longitude');
        myMapController.updateLocationData(BMFUserLocation(
            location: BMFLocation(coordinate: BMFCoordinate(latitude ?? 0, longitude ?? 0))
        ));
      // }
      locationFinish();
      // if(latitude != null && longitude != null) {
      //   addColorsPolyline(BMFCoordinate(latitude!, longitude!));
      // }
    });

    initLocation();
    initMap();

    initTrack();
    startService();
  }

  initLocation() {
    _locationAction();
    _startLocation();
  }

  void _locationAction() async {
    /// 设置android端和ios端定位参数
    /// android 端设置定位参数
    /// ios 端设置定位参数
    Map iosMap = initIOSOptions().getMap();
    Map androidMap = _initAndroidOptions().getMap();

    _suc = await myLocPlugin.prepareLoc(androidMap, iosMap);
    print('设置定位参数：$iosMap');
  }

  /// 启动定位
  Future<void> _startLocation() async {
    if (Platform.isIOS) {
      _suc = await myLocPlugin
          .singleLocation({'isReGeocode': true, 'isNetworkState': true});
      print('开始单次定位：$_suc');
    } else if (Platform.isAndroid) {
      _suc = await myLocPlugin.startLocation();
    }
  }

  /// 设置地图参数
  BaiduLocationAndroidOption _initAndroidOptions() {
    BaiduLocationAndroidOption options = BaiduLocationAndroidOption(
        coorType: 'bd09ll',
        locationMode: BMFLocationMode.hightAccuracy,
        isNeedAddress: true,
        isNeedAltitude: true,
        isNeedLocationPoiList: true,
        isNeedNewVersionRgc: true,
        isNeedLocationDescribe: true,
        openGps: true,
        scanspan: 4000,
        coordType: BMFLocationCoordType.bd09ll);
    return options;
  }

  BaiduLocationIOSOption initIOSOptions() {
    BaiduLocationIOSOption options = BaiduLocationIOSOption(
        coordType: BMFLocationCoordType.bd09ll,
        BMKLocationCoordinateType: 'BMKLocationCoordinateTypeBMK09LL',
        desiredAccuracy: BMFDesiredAccuracy.best);
    return options;
  }

  ///定位完成添加mark
  void locationFinish() {
    /// 创建BMFMarker
    // BMFMarker marker = BMFMarker.icon(
    //     position: BMFCoordinate(
    //         latitude ?? 39.917215, longitude ?? 116.380341),
    //     title: 'flutterMaker',
    //     identifier: 'flutter_marker',
    //     icon: 'resoures/icon_mark.png');
    // print('定位完成添加mark $latitude$longitude');
    //
    // /// 添加Marker
    // myMapController.addMarker(marker);
    addColorsPolyline(BMFCoordinate(latitude!, longitude!));
    ///设置中心点
    myMapController.setCenterCoordinate(BMFCoordinate(latitude ?? 39.917215, longitude ?? 116.380341), false);
  }

  initMap() async {

    /// 设置用户是否同意SDK隐私协议
    /// since 3.1.0 开发者必须设置

    // 百度地图sdk初始化鉴权
    if (Platform.isIOS) {
      // myLocPlugin.authAK('2nYNd7zkBfkdPgZoW58ifsfidxgp8eGd');
      BMFMapSDK.setApiKeyAndCoordType(
          '2nYNd7zkBfkdPgZoW58ifsfidxgp8eGd', BMF_COORD_TYPE.BD09LL);
    } else if (Platform.isAndroid) {
      /// 初始化获取Android 系统版本号，如果低于10使用TextureMapView 等于大于10使用Mapview
      await BMFAndroidVersion.initAndroidVersion();
      // Android 目前不支持接口设置Apikey,
      // 请在主工程的Manifest文件里设置，详细配置方法请参考官网(https://lbsyun.baidu.com/)demo
      BMFMapSDK.setCoordType(BMF_COORD_TYPE.BD09LL);
    }
  }

  Future<bool> requestLocationPermission() async {
    //获取当前的权限
    var status = await Permission.location.status;
    if (status == PermissionStatus.granted) {
      //已经授权
      return true;
    } else {
      //未授权则发起一次申请
      status = await Permission.location.request();
      if (status == PermissionStatus.granted) {
        return true;
      } else {
        return false;
      }
    }
  }

  initTrack() async {
    // 设置鹰眼SDK的基础信息
    // 每次调用startService开启轨迹服务之前，可以重新设置这些信息。
    if (Platform.isIOS) {
      /// iOS端初始化鹰眼sdk发起鉴权 since 2.2.0
      bool suc = await TraceSDK.setApiKey('');
      if (suc) {
        // print("ios-鹰眼启动引擎成功");
      }

      /// 鹰眼配置
      ServiceOption serviceOption = ServiceOption(
        ak: 'YnZqCThnS1wzKnnhOfsrIa5g7MUi7nWA',
        mcode: 'mcode',
        serviceId: 240260,
        keepAlive: true,
      );

      /// 设置SDK运行所需的基础信息，调用任何方法之前都需要先调用此方法
      /// true代表设置成功，false代表设置失败
      /// ios 独有
      bool flag =
          await TraceController.shareInstance.configServerInfo(serviceOption);
      print('--百度鹰眼服务配置 flag = $flag');

      /// 百度地图sdk初始化鉴权
      BMFMapSDK.setApiKeyAndCoordType('YnZqCThnS1wzKnnhOfsrIa5g7MUi7nWA', BMF_COORD_TYPE.BD09LL);
    } else if (Platform.isAndroid) {
      /// Android 目前不支持接口设置Apikey,
      /// 请在主工程的Manifest文件里设置，详细配置方法请参考官网(https://lbsyun.baidu.com/)demo
      BMFMapSDK.setCoordType(BMF_COORD_TYPE.BD09LL);
    }
  }

  /// 开启服务 tap
  void startService() async {

      if (Platform.isIOS) {
        /// 鹰眼采集的轨迹点上传结果回调 仅支持iOS端
        TraceController.shareInstance.onTraceDataUploadCallback(
            callback: TraceCallback(
              onGetTraceDataUploadResultCallBack: (Map map) {
                print(map);
              },
            ));
      }

      // 开始
      bool flag = await TraceController.shareInstance.startTraceService(
        trace: _trace,
        traceCallback: TraceCallback(
          onStartTraceServiceCallBack: (TraceResult result) {
            print('--开启鹰眼服务回调 result = ${result.toMap()}');
            if(result.status == 0) startGather();
          },
          onPushCallBack: (PushResult result) {
            // 推送报警回调
            print('--推送报警回调 result = ${result.toMap()}');
            // 此处开发者对服务推送的报警信息进行处理
            print('${result.toMap()}');
          },
        ),
      );
      print('--开启鹰眼服务 flag = $flag');

  }

  stopService() async {
    // 停止
    bool flag = await TraceController.shareInstance.stopTraceService(
      trace: _trace,
      traceCallback: TraceCallback(
        onStopTraceServiceCallBack: (TraceResult result) {
          print('--停止鹰眼服务回调 result = ${result.toMap()}');
          print('${result.toMap()}');
        },
      ),
    );
    print('--停止鹰眼服务 flag = $flag');
  }

  /// 开始采集
  void startGather() async {
    TraceController.shareInstance.setInterval(gatherInterval: 2, packInterval: 4,
      traceCallback: TraceCallback(
        onSetIntervalCallBack: (SetIntervalErrorCode setIntervalErrorCode) {
          print('--设置采集周期和打包上传周期回调 result = ${setIntervalErrorCode.index}');
        }),);
      // 开始
      bool flag = await TraceController.shareInstance.startGather(traceCallback:
      TraceCallback(onStartGatherCallBack: (GatherResult result) {
        print('--开始采集回调 result = ${result.toMap()}');
        print('${result.toMap()}');
      }));

      print('--开始采集 flag = $flag');
      if (Platform.isAndroid) {
        await TraceController.shareInstance.queryRealTimeLoc(
            realTimeLocationOption:
            RealTimeLocationOption(tag: 1, serviceId: 240260),
            entityCallBack: EntityCallBack(onQueryRealTimeLocationCallBack:
                (RealTimeLocationResult realTimeLocationResult) {
              setState(() {
                sum++;
              });
              print('--实时定位回调 result = ${realTimeLocationResult.toMap()}');
              if (realTimeLocationResult.latitude == null ||
                  realTimeLocationResult.longitude == null) return;
              addColorsPolyline(BMFCoordinate(realTimeLocationResult.latitude!, realTimeLocationResult.longitude!), isTrack: true);
              // if (realTimeLocationResult.status == 0) {
              //   addColorsPolyline(BMFCoordinate(realTimeLocationResult.latitude!, realTimeLocationResult.longitude!), isTrack: true);
              //   // if (_curLocation == null) {
              //   //   _curLocation = BMFMarker.icon(
              //   //     position: BMFCoordinate(
              //   //       realTimeLocationResult.latitude!,
              //   //       realTimeLocationResult.longitude!,
              //   //     ),
              //   //     icon: "resoures/icon_cur_location.png",
              //   //   );
              //   //   myMapController.addMarker(_curLocation!);
              //   // } else {
              //   //   _curLocation!.updatePosition(BMFCoordinate(
              //   //       realTimeLocationResult.latitude!,
              //   //       realTimeLocationResult.longitude!));
              //   // }
              // }
            }));
      }
      
      TraceController.shareInstance.queryTrackLatestPoint(
          queryTrackLatestPointOption: QueryTrackLatestPointOption(tag: 1, serviceId: 240260, entityName: 'sptest'),
      trackCallBack: TrackCallBack(onQueryTrackLatestPointCallBack: (queryTrackLatestPointResult) {
        print('查询某终端实体的实时位置${queryTrackLatestPointResult.latestPoint!.location!.toMap()}');
      }));

  }

  stopGather() async {
    // 停止
    bool flag = await TraceController.shareInstance.stopGather(traceCallback:
    TraceCallback(onStopGatherCallBack: (GatherResult result) {
      print('--停止采集回调 result = ${result.toMap()}');
      print('${result.toMap()}');
    }));
    print('--停止采集 flag = $flag');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          SizedBox(
            height: double.infinity,
            width: double.infinity,
            child: BMFMapWidget(
              onBMFMapCreated: onBMFMapCreated,
              mapOptions: initMapOptions(),
            ),
          ),
          Positioned(
            left: 40,
              bottom: 40,
              child: Row(
                children: [
                  GestureDetector(
                      onTap: () {
                        stopService();
                        stopGather();
                      },
                      child: Container(alignment: Alignment.center,width: 40, height: 40, color: Colors.red,child: Text('停止采集'),),
                  ),
                  GestureDetector(
                    onTap: () { myMapController.setCenterCoordinate(BMFCoordinate(latitude!, longitude!), false); },
                    child:  Container(alignment: Alignment.center,width: 40, height: 40, margin: EdgeInsets.only(left: 20), color: Colors.red,child: Text('当前位置'),),
                  ),
                  GestureDetector(
                    // onTap: () { myMapController.setCenterCoordinate(BMFCoordinate(latitude!, longitude!), false); },
                    child:  Container(alignment: Alignment.center,width: 40, height: 40, margin: EdgeInsets.only(left: 20), color: Colors.red,child: Text(sum.toString()),),
                  )
                ],
              ))
        ],
      )
    );
  }

  /// 设置地图参数
  BMFMapOptions initMapOptions() {
    BMFMapOptions mapOptions = BMFMapOptions(
      center: BMFCoordinate(latitude ?? 39.917215, longitude ?? 116.380341),
      zoomLevel: 16,
    );
    return mapOptions;
  }

  /// 创建完成回调
  void onBMFMapCreated(BMFMapController controller) async {
    myMapController = controller;

    // Map? map1 = await myMapController.getNativeMapCopyright();
    // print('获取原生地图版权信息：$map1');
    // Map? map2 = await myMapController.getNativeMapApprovalNumber();
    // print('获取原生地图审图号：$map2');
    // Map? map3 = await myMapController.getNativeMapQualification();
    // print('获取原生地图测绘资质：$map3');

    /// 地图加载回调
    myMapController.setMapDidLoadCallback(callback: () {
      print('mapDidLoad-地图加载完成');
      myMapController.setCenterCoordinate(BMFCoordinate(latitude ?? 39.917215, longitude ?? 116.380341), false);
      myMapController.showUserLocation(true);
      myMapController.updateMapOptions( BMFMapOptions(scrollEnabled:true));
      myMapController.updateMapOptions(BMFMapOptions(zoomEnabled: true));
    });
  }
  /// 添加颜色渲染polyline
  void addColorsPolyline(BMFCoordinate bMFCoordinate, {bool isTrack = false}) {
    indexs.add(coordinates.length);
    coordinates.add(bMFCoordinate);

    if(isTrack) {
      colors.add(Colors.green);
    }else{
      colors.add(Colors.red);
    }

    if(coordinates.length <= 1) return;

    _colorsPolyline = BMFPolyline.multiColorline(
        coordinates: coordinates,
        colors: colors,
        indexs: indexs,
        width: 8,
        lineBloomMode: BMFLineBloomMode.LineBLUR,
        lineBloomBlurTimes: 2,
        lineBloomWidth: 32,
        lineBloomAlpha: 250,
        lineBloomGradientASPeed: 5,
        lineDashType: BMFLineDashType.LineDashTypeNone,
        lineCapType: BMFLineCapType.LineCapButt,
        lineJoinType: BMFLineJoinType.LineJoinRound);
    myMapController.addPolyline(_colorsPolyline);
  }
  // /// 添加颜色渲染polyline
  // void addColorsPolyline(BMFCoordinate bMFCoordinate, {Color color = Colors.red}) {
  //
  //   coordinates.add(bMFCoordinate);
  //   if(coordinates.length > 1) {
  //     _colorsPolyline = BMFPolyline.colorline(coordinates: coordinates, strokerColor: color);
  //     myMapController.addPolyline(_colorsPolyline);
  //   }
  //
  //   // _colorsPolyline = BMFPolyline.colorline(coordinates: coordinates, strokerColor: color);
  //
  //   // _colorsPolyline = BMFPolyline.colorline(
  //   //     coordinates: coordinates,
  //   //     width: 8,
  //   //     lineBloomMode: BMFLineBloomMode.LineBLUR,
  //   //     lineBloomBlurTimes: 2,
  //   //     lineBloomWidth: 32,
  //   //     lineBloomAlpha: 250,
  //   //     lineBloomGradientASPeed: 5,
  //   //     lineDashType: BMFLineDashType.LineDashTypeNone,
  //   //     lineCapType: BMFLineCapType.LineCapButt,
  //   //     lineJoinType: BMFLineJoinType.LineJoinRound, strokerColor: color);
  //   // myMapController.addPolyline(_colorsPolyline);
  //   print('折线点个数===---' + coordinates.length.toString());
  // }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();

    stopService();
    stopGather();
  }
}
