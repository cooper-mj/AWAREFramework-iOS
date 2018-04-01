//
//  AWARESensorManager.m
//  AWARE
//
//  Created by Yuuki Nishiyama on 11/19/15.
//  Copyright © 2015 Yuuki NISHIYAMA. All rights reserved.
//
// This class manages AWARESensors' start and stop operation.
// And also, you can upload sensor data manually by using this class.
//
//

#import "AWARESensorManager.h"
#import "AWAREStudy.h"
#import "AWAREKeys.h"

// AWARE Sensors
#import "Accelerometer.h"
#import "Gyroscope.h"
#import "Magnetometer.h"
#import "Rotation.h"
#import "Battery.h"
#import "Barometer.h"
#import "Locations.h"
#import "Network.h"
#import "Wifi.h"
#import "Processor.h"
#import "Gravity.h"
#import "LinearAccelerometer.h"
#import "Bluetooth.h"
// #import "AmbientNoise.h"
#import "Screen.h"
#import "NTPTime.h"
#import "Proximity.h"
#import "Timezone.h"
#import "Calls.h"
#import "ESM.h"
#import "PushNotification.h"

// AWARE Plugins
#import "IOSActivityRecognition.h"
#import "OpenWeather.h"
#import "DeviceUsage.h"
#import "GoogleLogin.h"
#import "FusedLocations.h"
#import "Pedometer.h"
#import "BLEHeartRate.h"
#import "Memory.h"
#import "IOSESM.h"

#import "Contacts.h"
#import "Fitbit.h"
#import "BasicSettings.h"
#import "AmbientNoise.h"

@implementation AWARESensorManager{
    /** upload timer */
    NSTimer * uploadTimer;
    /** sensor manager */
    NSMutableArray* awareSensors;
    /** aware study */
    AWAREStudy * awareStudy;
    /** lock state*/
    BOOL lock;
    /** progress of manual upload */
    int manualUploadProgress;
    int numberOfSensors;
    BOOL manualUploadResult;
    NSTimer * manualUploadMonitor;
    NSObject * observer;
    NSMutableDictionary * progresses;
    int manualUploadTime;
    BOOL alertState;
    NSDictionary * previousProgresses;
}

/**
 * Init a AWARESensorManager with an AWAREStudy
 * @param   AWAREStudy  An AWAREStudy content
 */
- (instancetype)initWithAWAREStudy:(AWAREStudy *) study {
    self = [super init];
    if (self) {
        awareSensors = [[NSMutableArray alloc] init];
        awareStudy = study;
        lock = false;

        manualUploadProgress = 0;
        numberOfSensors = 0;
        manualUploadTime = 0;
        alertState = NO;
        previousProgresses = [[NSDictionary alloc] init];
    }
    return self;
}


- (void)lock{
    lock = YES;
}

- (void)unlock{
    lock = NO;
}

- (BOOL)isLocked{
    return lock;
}

- (BOOL) startAllSensors{
    if(awareSensors != nil){
        for (AWARESensor * sensor in awareSensors) {
            [sensor startSensor];
        }
    }
    return YES;
}

- (BOOL) addSensorsWithStudy:(AWAREStudy *) study{
    //return [self startAllSensorsWithStudy:study dbType:AwareDBTypeSQLite];
    NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger dbType = [userDefaults integerForKey:SETTING_DB_TYPE];
    return [self addSensorsWithStudy:study dbType:dbType];
}

- (BOOL) addSensorsWithStudy:(AWAREStudy *)study dbType:(AwareDBType)dbType{

    if (study != nil){
        awareStudy = study;
    }else{
        return NO;
    }

    // sensors settings
    NSArray *sensors = [awareStudy getSensors];
    
    // plugins settings
    NSArray *plugins = [awareStudy  getPlugins];
    
    AWARESensor* awareSensor = nil;
    
    /// start and make a sensor instance
    if(sensors != nil){

        for (int i=0; i<sensors.count; i++) {
            
            awareSensor = nil;
            
            NSString * setting = [[sensors objectAtIndex:i] objectForKey:@"setting"];
            NSString * value = [[sensors objectAtIndex:i] objectForKey:@"value"];
            
            if ([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_ACCELEROMETER]]) {
                awareSensor= [[Accelerometer alloc] initWithAwareStudy:awareStudy dbType:dbType ];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_BAROMETER]]){
                awareSensor = [[Barometer alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_GYROSCOPE]]){
                awareSensor = [[Gyroscope alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_MAGNETOMETER]]){
                awareSensor = [[Magnetometer alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_BATTERY]]){
                awareSensor = [[Battery alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_LOCATIONS]]){
                awareSensor = [[Locations alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_NETWORK]] ||
                     [setting isEqualToString:@"status_network_events"]){
                awareSensor = [[Network alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_WIFI]]){
                awareSensor = [[Wifi alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if ([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_PROCESSOR]]){
                awareSensor = [[Processor alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if ([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_GRAVITY]]){
                awareSensor = [[Gravity alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_LINEAR_ACCELEROMETER]]){
                awareSensor = [[LinearAccelerometer alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_BLUETOOTH]]){
                awareSensor = [[Bluetooth alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_SCREEN]]){
                awareSensor = [[Screen alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_PROXIMITY]]){
                awareSensor = [[Proximity alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_TIMEZONE]]){
                awareSensor = [[Timezone alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_ESMS]]){
                /** ESM and WebESM plugin are replaced to iOS ESM ( = IOSESM class) plugin */
                // awareSensor = [[ESM alloc] initWithAwareStudy:awareStudy dbType:dbType];
                // awareSensor = [[WebESM alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_CALLS]]){
                awareSensor = [[Calls alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_ROTATION]]){
                awareSensor = [[Rotation alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }else if([setting isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_IOS_ESM]]){
                awareSensor = [[IOSESM alloc] initWithAwareStudy:awareStudy dbType:dbType];
            }
            
            if (awareSensor != nil) {
                // Start the sensor
                if ([value isEqualToString:@"true"]) {
                    [awareSensor setParameters:sensors];
                }
                // [awareSensor trackDebugEvents];
                // Add the sensor to the sensor manager
                [self addSensor:awareSensor];
            }
        }
    }
    
    if(plugins != nil){
        // Start and make a plugin instance
        for (int i=0; i<plugins.count; i++) {
            NSDictionary *plugin = [plugins objectAtIndex:i];
            NSArray *pluginSettings = [plugin objectForKey:@"settings"];
            for (NSDictionary* pluginSetting in pluginSettings) {
                
                awareSensor = nil;
                NSString *pluginName = [pluginSetting objectForKey:@"setting"];
                NSLog(@"%@", pluginName);
                if ([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_PLUGIN_GOOGLE_ACTIVITY_RECOGNITION]]){
                    // NOTE: This sensor is not longer supported. The sensor will move to iOS activity recognition plugin.
                    // awareSensor = [[ActivityRecognition alloc] initWithAwareStudy:awareStudy dbType:dbType];
                    
                    // iOS Activity Recognition API
                    NSString * pluginState = [pluginSetting objectForKey:@"value"];
                    if ([pluginState isEqualToString:@"true"]) {
                        AWARESensor * iosActivityRecognition = [[IOSActivityRecognition alloc] initWithAwareStudy:awareStudy dbType:dbType];
                        // [iosActivityRecognition startSensorWithSettings:pluginSettings];
                        [iosActivityRecognition setParameters:pluginSettings];
                        [iosActivityRecognition.storage setDebug:YES];
                        [self addSensor:iosActivityRecognition];
                    }
                    
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_IOS_ACTIVITY_RECOGNITION ]] ) {
                    awareSensor = [[IOSActivityRecognition alloc] initWithAwareStudy:awareStudy dbType:dbType];
                } else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_PLUGIN_OPEN_WEATHER]]){
                    awareSensor = [[OpenWeather alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_PLUGIN_DEVICE_USAGE]]){
                    awareSensor = [[DeviceUsage alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_PLUGIN_NTPTIME]]){
                    awareSensor = [[NTPTime alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_PLUGIN_GOOGLE_LOGIN]]){
                    awareSensor = [[GoogleLogin alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_GOOGLE_FUSED_LOCATION]]){
                    awareSensor = [[FusedLocations alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_AMBIENT_NOISE]]){
                    awareSensor = [[AmbientNoise alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_PLUGIN_BLE_HR]]){
                    awareSensor = [[BLEHeartRate alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@",SENSOR_PLUGIN_IOS_ESM]]){
                    awareSensor = [[IOSESM alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@", SENSOR_PLUGIN_FITBIT]]){
                    awareSensor = [[Fitbit alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@", SENSOR_PLUGIN_CONTACTS]]){
                    awareSensor = [[Contacts alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@", SENSOR_PLUGIN_PEDOMETER]]){
                    awareSensor = [[Pedometer alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }else if([pluginName isEqualToString:[NSString stringWithFormat:@"status_%@", SENSOR_BASIC_SETTINGS]]){
                    awareSensor = [[BasicSettings alloc] initWithAwareStudy:awareStudy dbType:dbType];
                }
                
                if(awareSensor != nil){
                    NSString * pluginState = [pluginSetting objectForKey:@"value"];
                    if ([pluginState isEqualToString:@"true"]) {
                        // [awareSensor startSensorWithSettings:pluginSettings];
                        [awareSensor setParameters:pluginSettings];
                    }
                    // [awareSensor trackDebugEvents];
                    [self addSensor:awareSensor];
                }
            }
        }
    }
    
    /**
     * [Additional hidden sensors]
     * You can add your own AWARESensor to AWARESensorManager directly using following source code.
     * The "-addNewSensor" method is versy userful for testing and debuging a AWARESensor without registlating a study.
     */
    
    // Push Notification
    AWARESensor * pushNotification = [[PushNotification alloc] initWithAwareStudy:awareStudy dbType:dbType];
    [self addSensor:pushNotification];
    
    
    /**
     * Debug Sensor
     * NOTE: don't remove this sensor. This sensor collects debug messages.
     */
//    AWARESensor * debug = [[Debug alloc] initWithAwareStudy:awareStudy dbType:AwareDBTypeJSON];
//    [self addSensor:debug];
    
    return YES;
}


- (BOOL)createDBTablesOnAwareServer{
    for(AWARESensor * sensor in awareSensors){
        [sensor createTable];
    }
    return YES;
}


/**
 * Check an existance of a sensor by a sensor name
 * You can find and edit the keys on AWAREKeys.h and AWAREKeys.m
 *
 * @param   key A NSString key for a sensor
 * @return  An existance of the target sensor as a boolean value
 */
- (BOOL) isExist :(NSString *) key {
    if([key isEqualToString:@"location_gps"] || [key isEqualToString:@"location_network"]){
        key = @"locations";
    }
    
    if([key isEqualToString:@"esm"]){
        key = @"esms";
    }
    
    for (AWARESensor* sensor in awareSensors) {
        if([[sensor getSensorName] isEqualToString:key]){
            return YES;
        }
    }
    return NO;
}

- (void)addSensors:(NSArray<AWARESensor *> *)sensors{
    if (sensors != nil) {
        for (AWARESensor * sensor in sensors){
            [self addSensor:sensor];
        }
    }
}

/**
 * Add a new sensor to a aware sensor manager
 *
 * @param sensor An AWARESensor object (A null value is not an acceptable)
 */
- (void)addSensor:(AWARESensor *)sensor{
    if (sensor == nil) return;
    for(AWARESensor* storedSensor in awareSensors){
        if([storedSensor.getSensorName isEqualToString:sensor.getSensorName]){
            return;
        }
    }
    [awareSensors addObject:sensor];
}



/**
 * Remove all sensors from the manager after stop the sensors
 */
- (void) stopAndRemoveAllSensors {
    [self lock];
    NSString * message = nil;
    @autoreleasepool {
        for (AWARESensor* sensor in awareSensors) {
            message = [NSString stringWithFormat:@"[%@] Stop %@ sensor",[sensor getSensorName], [sensor getSensorName]];
            NSLog(@"%@", message);
            // [sensor saveDebugEventWithText:message type:DebugTypeInfo label:@"stop"];
            [sensor stopSensor];
            [sensor.storage cancelSyncStorage];
        }
        [awareSensors removeAllObjects];
    }
    [self unlock];
}

- (AWARESensor *) getSensorWithKey:(NSString *)sensorName {
    for (AWARESensor* sensor in awareSensors) {
        if([[sensor getSensorName] isEqualToString:sensorName]){
            return sensor;
        }
    }
    return nil;
}

- (void)quitAllSensor{
    // TODO
    for (AWARESensor* sensor in awareSensors) {
        [sensor stopSensor];
    }
}

/**
 * Stop a sensor with the sensor name.
 * You can find the sensor name (key) on AWAREKeys.h and .m.
 * 
 * @param sensorName A NSString sensor name (key)
 */
- (void) stopSensor:(NSString *)sensorName{
    for (AWARESensor* sensor in awareSensors) {
        if ([sensor.getSensorName isEqualToString:sensorName]) {
            [sensor stopSensor];
        }
        [sensor stopSensor];
    }
}


/**
 * Stop all sensors
 *
 */
- (void) stopAllSensors{
    if(awareSensors == nil) return;
    for (AWARESensor* sensor in awareSensors) {
        [sensor stopSensor];
    }
}


/**
 * Provide latest sensor data by each sensor as NSString value.
 * You can access the data by using sensor names (keys) on AWAREKeys.h and .m.
 *
 * @param sensorName A NSString sensor name (key)
 * @return A latest sensor value as
 */
- (NSString*) getLatestSensorValue:(NSString *) sensorName {
    if ([self isLocked]) return @"";
    
    if([sensorName isEqualToString:@"location_gps"] || [sensorName isEqualToString:@"location_network"]){
        sensorName = @"locations";
    }
    
    
    for (AWARESensor* sensor in awareSensors) {
        if (sensor.getSensorName != nil) {
            if ([sensor.getSensorName isEqualToString:sensorName]) {
                NSString *sensorValue = [sensor getLatestValue];
                return sensorValue;
            }
        }
    }
    return @"";
}


- (NSDictionary * ) getLatestSensorData:(NSString *) sensorName {
    if ([self isLocked])
        return [[NSDictionary alloc] init];
    
    if([sensorName isEqualToString:@"location_gps"] || [sensorName isEqualToString:@"location_network"]){
        sensorName = @"locations";
    }
    
    for (AWARESensor* sensor in awareSensors) {
        if (sensor.getSensorName != nil) {
            if ([sensor.getSensorName isEqualToString:sensorName]) {
                return [sensor getLatestData];
            }
        }
    }
    return [[NSDictionary alloc] init];
}


/**
 *
 */
- (NSArray *) getAllSensors {
    return awareSensors;
}


- (void)syncAllSensors {
    [self syncAllSensorsForcefully];
}

- (void)syncAllSensorsForcefully{
    dispatch_async(dispatch_get_main_queue(), ^{
        for (AWARESensor * sensor in awareSensors ) {
            [sensor startSyncDB];
        }
    });
    
//    for ( int i=0; i < awareSensors.count; i++) {
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, i * 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
//            @try {
//                if (i < self->awareSensors.count ) {
//                    AWARESensor* sensor = [self->awareSensors objectAtIndex:i];
//                    [sensor startSyncDB];
//                }else{
//                    NSLog(@"error");
//                }
//            } @catch (NSException *e) {
//                NSLog(@"An exception was appeared: %@",e.name);
//                NSLog(@"The reason: %@",e.reason);
//            }
//        });
//    }
}



- (void) startUploadTimerWithInterval:(double) interval {
    if (uploadTimer != nil) {
        [uploadTimer invalidate];
        uploadTimer = nil;
    }
    uploadTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                   target:self
                                                 selector:@selector(syncAllSensorsWithDBInBackground)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void) stopUploadTimer{
    [uploadTimer invalidate];
    uploadTimer = nil;
}

- (void)runBatteryStateChangeEvents{
//    if(awareSensors == nil) return;
//    for (AWARESensor * sensor in awareSensors) {
//        [sensor changedBatteryState];
//    }
}


//////////////////////////////////////////////////////
//////////////////////////////////////////////////////


- (void) saveAllDummyDate {
//    for (AWARESensor * sensor in awareSensors) {
//        [sensor saveDummyData];
//    }
}

- (void) showAllLatestSensorDataFromServer:(NSNumber *) startTimestamp {
    for (AWARESensor * sensor in [self getAllSensors]) {
        NSData * data = [sensor getLatestData];
        if(data != nil){
            // NSLog(@"[%@] sucess: %@", [sensor getSensorName], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] );
            NSError *error = nil;
            NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &error];
            if(error != nil){
                NSLog(@"error: %@", error.debugDescription);
            }
            if(jsonArray != nil){
                for (NSDictionary * dict in jsonArray) {
                    NSNumber * timestamp = [dict objectForKey:@"timestamp"];
                    if(startTimestamp.longLongValue < timestamp.longLongValue){
                        NSLog(@"[Exist] %@ (%@ <---> %@)",[sensor getSensorName], timestamp, startTimestamp);
                    }else{
                        NSLog(@"[ None] %@ (%@ <---> %@)",[sensor getSensorName], timestamp, startTimestamp);
                    }
                }
            }else{
                NSLog(@"[Error] %@", [sensor getSensorName]);
            }
        }else{
            NSLog(@"[Error] %@'s data is null...", [sensor getSensorName]);
        }
    }
}

- (void) checkLocalDBs {
    for (AWARESensor * sensor in awareSensors) {
        NSFileManager   *fileManager    = [NSFileManager defaultManager];
        NSArray         *ducumentDir    =  NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString        *docRoot        = [ducumentDir objectAtIndex:0];
        NSError * error = nil;
        bool result = false;
        for ( NSString *dirName  in [fileManager contentsOfDirectoryAtPath:docRoot error:&error] ){
            // NSLog(@"%@", dirName);
            if([dirName isEqualToString:[NSString stringWithFormat:@"%@.json",[sensor getSensorName]]]){
                NSLog(@"[Exist] %@", [sensor getSensorName]);
                result = true;
                break;
            }
        }
        if(!result){
            NSLog(@"[ None] %@", [sensor getSensorName]);
        }
    }
}

- (void) resetAllMarkerPositionsInDB {
    NSLog(@"------- Start to reset marker Position in DB -------");
    for (AWARESensor * sensor in awareSensors) {
//        int preMark = [sensor.storage getMarkerPosition];
//        [sensor.storage resetMarkerPosition];
//        int currentMark = [sensor.storage getMarkerPosition];
//        NSLog(@"[%@] %d -> %d", [sensor getSensorName], preMark, currentMark);
    }
    NSLog(@"------- Finish to reset marker Position in DB -------");
}

- (void)removeAllFilesFromDocumentRoot{
    NSFileManager   *fileManager    = [NSFileManager defaultManager];
    NSArray         *ducumentDir    =  NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString        *docRoot        = [ducumentDir objectAtIndex:0];
    NSError * error = nil;
    for ( NSString *dirName  in [fileManager contentsOfDirectoryAtPath:docRoot error:&error] ){
        if([dirName isEqualToString:@"AWARE.sqlite"] ||
           [dirName isEqualToString:@"AWARE.sqlite-shm"] ||
           [dirName isEqualToString:@"AWARE.sqlite-wal"] ||
           [dirName isEqualToString:@"BandSDK"]){
            
        }else{
            [self removeFilePath:[NSString stringWithFormat:@"%@/%@",docRoot, dirName]];
        }
    }
}

- (BOOL)removeFilePath:(NSString*)path {
    NSLog(@"Remove => %@", path);
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    return [fileManager removeItemAtPath:path error:NULL];
}


///////////////////////////////////////////////////////////////////
-  (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
  completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                              NSURLCredential * _Nullable credential)) completionHandler{
    // http://stackoverflow.com/questions/19507207/how-do-i-accept-a-self-signed-ssl-certificate-using-ios-7s-nsurlsession-and-its
    
    if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
        
        NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
        SecTrustRef trust = [protectionSpace serverTrust];
        NSURLCredential *credential = [NSURLCredential credentialForTrust:trust];
        
        // NSArray *certs = [[NSArray alloc] initWithObjects:(id)[[self class] sslCertificate], nil];
        // int err = SecTrustSetAnchorCertificates(trust, (CFArrayRef)certs);
        // SecTrustResultType trustResult = 0;
        // if (err == noErr) {
        //    err = SecTrustEvaluate(trust, &trustResult);
        // }
        
        // if ([challenge.protectionSpace.host isEqualToString:@"aware.ht.sfc.keio.ac.jp"]) {
        //credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // } else if ([challenge.protectionSpace.host isEqualToString:@"r2d2.hcii.cs.cmu.edu"]) {
        //credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // } else if ([challenge.protectionSpace.host isEqualToString:@"api.awareframework.com"]) {
        //credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // } else {
        //credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        // }
        
        completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
    }
}

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

- (BOOL) checkFileExistance:(NSString *)name {
    /**
     * NOTE: Switch to CoreData to TextFile DB if this device is using TextFile DB
     */
    BOOL textFileExistance = NO;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString * path = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json",name]];
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:path]) {
        textFileExistance = YES;
    }else{
        textFileExistance = NO;
    }
    return textFileExistance;
}


- (void)setSensorEventCallbackToAllSensors:(SensorEventCallBack)callback{
    for (AWARESensor * sensor in awareSensors) {
        [sensor setSensorEventCallBack:callback];
    }
}

- (void)setSyncProcessCallbackToAllSensorStorages:(SyncProcessCallBack)callback{
    for (AWARESensor * sensor in awareSensors) {
        [sensor.storage setSyncProcessCallBack:callback];
    }
}

@end