# bd_map
#Flutter 集成 百度定位、地图、鹰眼SDK
## Flutter ,配置百度地图后运行报错:
BDMapSDKException: you have not supplyed the global app context info from SDKInitializer.initialize(Context) function.

需要在kotlin目录下的example新建MyApplication.java文件,在AndroidManifest.xml引用

<application
android:name=".MyApplication"
android:label=" .... "
</application>
