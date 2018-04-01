//
//  SQLiteStorage.m
//  AWAREFramework
//
//  Created by Yuuki Nishiyama on 2018/03/30.
//

#import "SQLiteStorage.h"
#import "AWAREDelegate.h"
#import "SyncExecutor.h"

@implementation SQLiteStorage{
    NSString * entityName;
    InsertEntityCallBack inertEntityCallBack;
    NSString * baseSyncDataQueryIdentifier;
    NSString * timeMarkerIdentifier;
    BOOL isUploading;
    int currentRepetitionCount;
    int requiredRepetitionCount;
    NSNumber * previousUploadingProcessFinishUnixTime; // unixtimeOfUploadingData;
    NSNumber * tempLastUnixTimestamp;
    BOOL cancel;
    SyncExecutor * executor;
    int retryCurrentCount;
}

- (instancetype)initWithStudy:(AWAREStudy *)study sensorName:(NSString *)name{
    NSLog(@"Please use -initWithStudy:sensorName:entityName:converter!!!");
    return [self initWithStudy:study sensorName:name entityName:nil insertCallBack:nil];
}

- (instancetype)initWithStudy:(AWAREStudy *)study sensorName:(NSString *)name entityName:(NSString *)entity insertCallBack:(InsertEntityCallBack)insertCallBack{
    self = [super initWithStudy:study sensorName:name];
    if(self != nil){
        currentRepetitionCount = 0;
        requiredRepetitionCount = 0;
        isUploading = NO;
        cancel = NO;
        self.retryLimit = 3;
        retryCurrentCount = 0;
        entityName = entity;
        inertEntityCallBack = insertCallBack;
        baseSyncDataQueryIdentifier = [NSString stringWithFormat:@"sync_data_query_identifier_%@", name];
        timeMarkerIdentifier = [NSString stringWithFormat:@"uploader_coredata_timestamp_marker_%@", name];
        tempLastUnixTimestamp = @0;
        AWAREDelegate *delegate=(AWAREDelegate*)[UIApplication sharedApplication].delegate;
        self.mainQueueManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [self.mainQueueManagedObjectContext setPersistentStoreCoordinator:delegate.persistentStoreCoordinator];
        previousUploadingProcessFinishUnixTime = [self getTimeMark];
        if([previousUploadingProcessFinishUnixTime isEqualToNumber:@0]){
            NSDate * now = [NSDate new];
            [self setTimeMark:now];
        }
        executor = [[SyncExecutor alloc] initWithAwareStudy:self.awareStudy sensorName:self.sensorName];
    }
    return self;
}

- (BOOL)saveDataWithDictionary:(NSDictionary * _Nullable)dataDict buffer:(BOOL)isRequiredBuffer saveInMainThread:(BOOL)saveInMainThread {
    [self saveDataWithArray:@[dataDict] buffer:isRequiredBuffer saveInMainThread:saveInMainThread];
    return YES;
}


- (BOOL)saveDataWithArray:(NSArray * _Nullable)dataArray buffer:(BOOL)isRequiredBuffer saveInMainThread:(BOOL)saveInMainThread {

    [self.buffer addObjectsFromArray:dataArray];
    // NSLog(@"%ld",self.buffer.count);
    if (self.buffer.count < [self getBufferSize]) {
        return YES;
    }
    // NSLog(@"%@", self.sensorName);
    NSArray * copiedArray = [self.buffer copy];
    [self.buffer removeAllObjects];
    
    AWAREDelegate * delegate=(AWAREDelegate*)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext* parentContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [parentContext setPersistentStoreCoordinator:delegate.persistentStoreCoordinator];
    
    NSManagedObjectContext* childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [childContext setParentContext:parentContext];
    
    [childContext performBlock:^{
        
        for (NSDictionary * bufferedData in copiedArray) {
            // [self insertNewEntityWithData:bufferedData managedObjectContext:childContext entityName:entityName];
            if(self->inertEntityCallBack != nil){
                self->inertEntityCallBack(bufferedData,childContext,self->entityName);
            }
        }
        
        NSError *error = nil;
        if (![childContext save:&error]) {
            // An error is occued
            NSLog(@"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
            // [self->buffer addObjectsFromArray:array];
            [self unlock];
        }else{
            // sucess to marge diff to the main context manager
            [parentContext performBlock:^{
                if(![parentContext save:nil]){
                    // An error is occued
                    NSLog(@"Error saving context");
                    // [self.buffer addObjectsFromArray:array];
                }
                if(self.isDebug) NSLog(@"[%@] Data is saved", self.sensorName);
                [self unlock];
            }];
        }
    }];
    
    return YES;
}


- (void)startSyncStorageWithCallBack:(SyncProcessCallBack)callback{
    self.syncProcessCallBack = callback;
    [self startSyncStorage];
}

- (void)startSyncStorage {
    [executor.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
        if (dataTasks.count == 0){
            // check wifi state
            if(self->isUploading){
                NSString * message= [NSString stringWithFormat:@"[%@] Now sendsor data is uploading.", self.sensorName];
                NSLog(@"%@", message);
                return;
            }
            
            [self setRepetationCountAfterStartToSyncDB:[self getTimeMark]];
            ////
            if (self.isDebug) NSLog(@"[%@] isUpload = YES", self.sensorName);
            self-> isUploading = YES;
        }else{
            if (self.isDebug) NSLog(@"tasks => %ld",dataTasks.count);
        }
    }];
}

- (void)cancelSyncStorage {
    // NSLog(@"Please overwirte -cancelSyncStorage");
    cancel = YES;
}


/////////////////////////



/**
 * start sync db with timestamp
 * @discussion Please call this method in the background
 */
- (BOOL) setRepetationCountAfterStartToSyncDB:(NSNumber *) startTimestamp {
    
    @try {
        if (entityName == nil) {
            NSLog(@"***** [%@] Error: Entity Name is nil! *****", self.sensorName);
            return NO;
        }
        
        if ([self isLock]) {
            return NO;
        }else{
            [self lock];
        }
        
        NSFetchRequest* request = [[NSFetchRequest alloc] init];
        NSManagedObjectContext *private = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [private setParentContext:self.mainQueueManagedObjectContext];
        
        [private performBlock:^{
            // NSLog(@"start time is ... %@",startTimestamp);
            [request setEntity:[NSEntityDescription entityForName:self->entityName inManagedObjectContext:self.mainQueueManagedObjectContext]];
            [request setIncludesSubentities:NO];
            [request setPredicate:[NSPredicate predicateWithFormat:@"timestamp >= %@", startTimestamp]];
            
            NSError* error = nil;
            // Get count of category
            NSInteger count = [private countForFetchRequest:request error:&error];
            // NSLog(@"[%@] %ld records", self->entityName , count);
            if (count == NSNotFound) {
                [self unlock]; // Unlock DB
                if (self.isDebug) NSLog(@"[%@] There are no data in this database table",self->entityName);
                return;
            } else if(error != nil){
                [self unlock]; // Unlock DB
                NSLog(@"%@", error.description);
                count = 0;
                return;
            } else if( count== 0){
                [self unlock];
                if (self.isDebug) NSLog(@"[%@] There are no data in this database table",self->entityName);
                return;
            }
            // Set repetationCount
            self->currentRepetitionCount = 0;
            self->requiredRepetitionCount = (int)count/(int)self.awareStudy.getMaxFetchSize;
            
            if (self.isDebug) NSLog(@"[%@] %d times of sync tasks are required", self.sensorName, self->requiredRepetitionCount);
            
            // set db condition as normal
            [self unlock]; // Unlock DB
            
            // start upload
            [self syncTask];
            
        }];
    } @catch (NSException *exception) {
        NSLog(@"%@", exception.reason);
        [self unlock]; // Unlock DB
    } @finally {
        return YES;
    }
}


/**
 * Upload method
 */
- (void) syncTask{
    previousUploadingProcessFinishUnixTime = [self getTimeMark];
    
    if (cancel) {
        [self dataSyncIsFinishedCorrectly];
        return;
    }
    // NSLog(@"[%@] marker   end: %@", sensorName, [NSDate dateWithTimeIntervalSince1970:previousUploadingProcessFinishUnixTime.longLongValue/1000]);
    
    if ([self isLock]) {
        // [self dataSyncIsFinishedCorrectly];
        [self performSelector:@selector(syncTask) withObject:nil afterDelay:1];
        return;
    }else{
        [self lock];
    }
    
    if(entityName == nil){
        NSLog(@"Entity Name is 'nil'. Please check the initialozation of this class.");
    }
    
    @try {
        // NSLog(@"[pretime:%@] %@", sensorName, previousUploadingProcessFinishUnixTime);
        
        NSManagedObjectContext *private = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [private setParentContext:self.mainQueueManagedObjectContext];
        [private performBlock:^{
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:self->entityName];
            [fetchRequest setFetchLimit: self.awareStudy.getMaxFetchSize ]; // <-- set a fetch limit for this query
            [fetchRequest setEntity:[NSEntityDescription entityForName:self->entityName inManagedObjectContext:self.mainQueueManagedObjectContext]];
            [fetchRequest setIncludesSubentities:NO];
            [fetchRequest setResultType:NSDictionaryResultType];
            if([self->entityName isEqualToString:@"EntityESMAnswer"] ){
                [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"double_esm_user_answer_timestamp >= %@",
                                            self->previousUploadingProcessFinishUnixTime]];
            }else{
                [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"timestamp >= %@", self->previousUploadingProcessFinishUnixTime]];
            }
            
            //Set sort option
            NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:YES];
            NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
            [fetchRequest setSortDescriptors:sortDescriptors];
            
            //Get NSManagedObject from managedObjectContext by using fetch setting
            NSArray *results = [private executeFetchRequest:fetchRequest error:nil] ;
            // NSLog(@"%ld",results.count); //TODO
            
            [self unlock];
            
            if (results != nil) {
                if (results.count == 0 || results.count == NSNotFound) {
                    [self dataSyncIsFinishedCorrectly];
                    return;
                }
                
                // Save current timestamp as a maker
                NSDictionary * lastDict = [results lastObject];//[results objectAtIndex:results.count-1];
                self->tempLastUnixTimestamp = [lastDict objectForKey:@"timestamp"];
                if([self->entityName isEqualToString:@"EntityESMAnswer"] ){
                    self->tempLastUnixTimestamp = [lastDict objectForKey:@"double_esm_user_answer_timestamp"];
                }
                if (self->tempLastUnixTimestamp == nil) {
                    self->tempLastUnixTimestamp = @0;
                }
                
                // Convert array to json data
                NSError * error = nil;
                NSData * jsonData = nil;
                @try {
                    jsonData = [NSJSONSerialization dataWithJSONObject:results options:0 error:&error];
                } @catch (NSException *exception) {
                    NSLog(@"[%@] %@",self.sensorName, exception.debugDescription);
                }
                
                if (error == nil && jsonData != nil) {
                    // Set HTTP/POST session on main thread
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ( jsonData.length == 0 || jsonData.length == 2 ) {
                            NSString * message = [NSString stringWithFormat:@"[%@] Data is Null or Length is Zero", self.sensorName];
                            if (self.isDebug) NSLog(@"%@", message);
                            [self dataSyncIsFinishedCorrectly];
                            return;
                        }
                        
                        NSMutableData * mutablePostData = [[NSMutableData alloc] init];
                        if([self->entityName isEqualToString:@"EntityESMAnswer"]){
                            NSString * jsonDataStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                            [mutablePostData appendData:[[self stringByAddingPercentEncodingForAWARE:jsonDataStr] dataUsingEncoding:NSUTF8StringEncoding]];
                        }else{
                            [mutablePostData appendData:jsonData];
                        }

                        @try {
                            self->executor.debug = self.isDebug;
                            [self->executor syncWithData:mutablePostData callback:^(NSDictionary *result) {
                                
                                if (result!=nil) {
                                    if (self.isDebug) NSLog(@"%@",result.debugDescription);
                                    NSNumber * isSuccess = [result objectForKey:@"result"];
                                    if (isSuccess != nil) {
                                        if((BOOL)isSuccess.intValue){
                                            // set a repetation count
                                            self->currentRepetitionCount++;
                                            [self setTimeMarkWithTimestamp:self->tempLastUnixTimestamp];
                                            if (self->requiredRepetitionCount<self->currentRepetitionCount) {
                                                ///////////////// Done ////////////
                                                if (self.isDebug) NSLog(@"[%@] Done", self.sensorName);
                                                [self dataSyncIsFinishedCorrectly];
                                                if (self.isDebug) NSLog(@"[%@] Clear old data", self.sensorName);
                                                [self clearOldData];
                                            }else{
                                                ///////////////// continue ////////////
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    if (self.syncProcessCallBack!=nil) {
                                                        self.syncProcessCallBack(self.sensorName, (double)self->currentRepetitionCount/(double)self->requiredRepetitionCount, nil);
                                                    }
                                                    if (self.isDebug) NSLog(@"[%@] Do the next sync task (%d/%d)", self.sensorName, self->currentRepetitionCount, self->requiredRepetitionCount);
                                                    // [self syncTask];
                                                    [self performSelector:@selector(syncTask) withObject:nil afterDelay:self.syncTaskIntervalSecond];
                                                });
                                            }
                                        }else{
                                            ///////////////// retry ////////////
                                            
                                            if (self->retryCurrentCount < self.retryLimit ) {
                                                self->retryCurrentCount++;
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    if (self.isDebug) NSLog(@"[%@] Do the next sync task (%d/%d)", self.sensorName, self->currentRepetitionCount, self->requiredRepetitionCount);
                                                    // [self syncTask];
                                                    [self performSelector:@selector(syncTask) withObject:nil afterDelay:self.syncTaskIntervalSecond];
                                                });
                                            }else{
                                                [self dataSyncIsFinishedCorrectly];
                                            }
                                        }

                                    }
                                }
                            }];

                        } @catch (NSException *exception) {
                            NSLog(@"[%@] %@",self.sensorName, exception.debugDescription);
                            [self dataSyncIsFinishedCorrectly];
                        }
                        
                    });
                }else{
                    NSLog(@"%@] %@", self.sensorName, error.debugDescription);
                    [self dataSyncIsFinishedCorrectly];
                }
            }
        }];
    } @catch (NSException *exception) {
        NSLog(@"%@", exception.reason);
        [self dataSyncIsFinishedCorrectly];
        [self unlock];
    }
}

- (void) dataSyncIsFinishedCorrectly {
    isUploading = NO;
    cancel = NO;
    requiredRepetitionCount = 0;
    currentRepetitionCount = 0;
    retryCurrentCount = 0;
}


- (void) clearOldData{
    NSFetchRequest* request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:entityName inManagedObjectContext:self.mainQueueManagedObjectContext]];
    [request setIncludesSubentities:NO];
    
    NSManagedObjectContext *private = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [private setParentContext:self.mainQueueManagedObjectContext];
    [private performBlock:^{
        
        cleanOldDataType cleanType = [self.awareStudy getCleanOldDataType];
        NSDate * clearLimitDate = nil;
        bool skip = YES;
        switch (cleanType) {
            case cleanOldDataTypeNever:
                skip = YES;
                break;
            case cleanOldDataTypeDaily:
                skip = NO;
                clearLimitDate = [[NSDate alloc] initWithTimeIntervalSinceNow:-1*60*60*24];
                break;
            case cleanOldDataTypeWeekly:
                skip = NO;
                clearLimitDate = [[NSDate alloc] initWithTimeIntervalSinceNow:-1*60*60*24*7];
                break;
            case cleanOldDataTypeMonthly:
                clearLimitDate = [[NSDate alloc] initWithTimeIntervalSinceNow:-1*60*60*24*31];
                skip = NO;
                break;
            case cleanOldDataTypeAlways:
                clearLimitDate = nil;
                skip = NO;
                break;
            default:
                skip = YES;
                break;
        }
        
        if(!skip){
            /** ========== Delete uploaded data ============= */
            if(![self isLock]){
                [self lock];
                NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:self->entityName];
                NSNumber * limitTimestamp = @0;
                if(clearLimitDate == nil){
                    limitTimestamp = self->tempLastUnixTimestamp;
                }else{
                    limitTimestamp = @([clearLimitDate timeIntervalSince1970]*1000);
                }
                
                if([self->entityName isEqualToString:@"EntityESMAnswer"] ){
                    [request setPredicate:[NSPredicate predicateWithFormat:@"(double_esm_user_answer_timestamp <= %@)", limitTimestamp]];
                }else{
                    [request setPredicate:[NSPredicate predicateWithFormat:@"(timestamp <= %@)", limitTimestamp]];
                }
                
                NSBatchDeleteRequest *delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
                NSError *deleteError = nil;
                [private executeRequest:delete error:&deleteError];
                if (deleteError != nil) {
                    NSLog(@"%@", deleteError.description);
                }else{
                    if(self.isDebug){
                        NSLog(@"[%@] Sucess to clear the data from DB (timestamp <= %@ )", self.sensorName, [NSDate dateWithTimeIntervalSince1970:limitTimestamp.longLongValue/1000]);
                    }
                }
                [self unlock];
            }
        }
    }];
}


//////////////////////////////////

- (void) resetMark {
    [self setTimeMarkWithTimestamp:@0];
}

- (void) setTimeMark:(NSDate *) timestamp {
    NSNumber * unixtimestamp = @0;
    if (timestamp != nil) {
        unixtimestamp = @([timestamp timeIntervalSince1970]);
    }
    [self setTimeMarkWithTimestamp:unixtimestamp];
}


- (void) setTimeMarkWithTimestamp:(NSNumber *)timestamp  {
    if(timestamp == nil){
        // NSLog(@"===============[%@] timestamp is nil============================", sensorName);
        timestamp = @0;
    }
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:timestamp forKey:timeMarkerIdentifier];
    [userDefaults synchronize];
}


- (NSNumber *) getTimeMark {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSNumber * timestamp = [userDefaults objectForKey:timeMarkerIdentifier];
    
    if(timestamp != nil){
        return timestamp;
    }else{
        // NSLog(@"===============timestamp is nil============================");
        return @0;
    }
}

- (NSString *)stringByAddingPercentEncodingForAWARE:(NSString *) string {
    // NSString *unreserved = @"-._~/?{}[]\"\':, ";
    NSString *unreserved = @"";
    NSMutableCharacterSet *allowed = [NSMutableCharacterSet
                                      alphanumericCharacterSet];
    [allowed addCharactersInString:unreserved];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

@end