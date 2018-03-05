//
//  DataBaseManager.h
//  Sqlite3Demo
//
//  Created by baina on 2018/3/5.
//  Copyright © 2018年 ACE. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DataBaseManager : NSObject

@property (nonatomic, copy) NSString *dbName;

+ (instancetype)sharedManager;



- (void)beginTransaction:(void(^)(DataBaseManager *dataBase, BOOL *rollback))block;


- (BOOL)dealSQL:(NSString *)sql;

- (BOOL)dealSqls:(NSArray <NSString *>*)sqls;

- (NSMutableArray <NSMutableDictionary *>*)querySql:(NSString *)sql;

@end
