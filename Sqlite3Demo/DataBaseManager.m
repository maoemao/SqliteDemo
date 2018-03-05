//
//  DataBaseManager.m
//  Sqlite3Demo
//
//  Created by baina on 2018/3/5.
//  Copyright © 2018年 ACE. All rights reserved.
//

#import "DataBaseManager.h"
#import <sqlite3.h>

#define kCachePath NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject

@interface DataBaseManager ()
    
@end

@implementation DataBaseManager
{
    dispatch_queue_t    _queue;
    sqlite3 *_db;
    NSString *_path;
}

- (BOOL)databaseQueueWithPath:(NSString *)aPath {
    return true;
}

+ (instancetype)sharedManager {
    static DataBaseManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[DataBaseManager alloc] init];
    });
    return manager;
}

- (instancetype) init {
    if(self = [super init]) {
        _path = nil;
        _db = nil;
        _queue = dispatch_queue_create("com.database.queue", DISPATCH_QUEUE_SERIAL);
        [self openDB];
    }
    return self;
}

- (void)openDB {
    if(_db) {
        return;
    }
    
    if(self.dbName == nil) {
        self.dbName = @"common.db";
    }
    
    _path = [kCachePath stringByAppendingPathComponent:self.dbName];
    NSLog(@"path:%@",_path);
    if(sqlite3_open(_path.UTF8String, &_db) != SQLITE_OK){
        NSLog(@"打开数据库失败");
        return;
    }

    [self createTable];
}

- (void)createTable {
    // 1.编写SQL语句
    // 建议: 在开发中编写SQL语句, 如果语句过长, 不要写在一行
    // 开发技巧: 在做数据库开发时, 如果遇到错误, 可以先将SQL打印出来, 拷贝到PC工具中验证之后再进行调试
    NSString *sql = @"CREATE TABLE IF NOT EXISTS t_stu( id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, age INTEGER ,score INTEGER);";
    // 2.执行SQL语句
     [self execSQL:sql];
}

- (void)beginTransaction:(void(^)(DataBaseManager *dataBase, BOOL *rollback))block {
    dispatch_sync(_queue, ^{
        CFAbsoluteTime time= CFAbsoluteTimeGetCurrent();
        BOOL shouldRollback = NO;
        
        [self beginTransaction];
        
        block(self,&shouldRollback);
        
        if(shouldRollback) {
            [self rollBackTransaction];
        } else {
            [self commitTransaction];
        }
       NSLog(@"事务: %f",(CFAbsoluteTimeGetCurrent() - time));
    });
}

- (void)beginExecSQL:(void(^)(DataBaseManager *dataBase, BOOL *rollback))block{
    dispatch_sync(_queue, ^{
        CFAbsoluteTime time= CFAbsoluteTimeGetCurrent();
        BOOL shouldRollback = NO;
        block(self,&shouldRollback);
         NSLog(@"非事务: %f",(CFAbsoluteTimeGetCurrent() - time));
    });
}

- (BOOL)execSQL:(NSString *)sql {
    NSAssert(sql != nil, @"sql 不能为空");
    return sqlite3_exec(_db, sql.UTF8String, nil, nil, nil) == SQLITE_OK;
}

- (BOOL)dealSQL:(NSString *)sql{
    
    BOOL result = sqlite3_exec(_db, sql.UTF8String, nil, nil, nil) == SQLITE_OK;
 
    return result;
}

- (BOOL)dealSqls:(NSArray<NSString *> *)sqls{
    // 准备语句
    
    // 2. 执行事务, 如果有一条执行失败, 则终止执行并执行回滚操作
    for (NSString *sql in sqls) {
        //       BOOL result = [self deal:sql uid:uid];
        BOOL result = sqlite3_exec(_db, sql.UTF8String, nil, nil, nil) == SQLITE_OK;
        if (result == NO) {
            return NO;
        }
    }
    // 3. 提交事务
    NSString *commit = @"commit transaction";
    sqlite3_exec(_db, commit.UTF8String, nil, nil, nil);
  
    return YES;
}

- (NSMutableArray<NSMutableDictionary *> *)querySql:(NSString *)sql{
   
    // 准备语句(预处理语句)
    
    // 1. 创建准备语句
    // 参数1: 一个已经打开的数据库
    // 参数2: 需要中的sql
    // 参数3: 参数2取出多少字节的长度 -1 自动计算 \0
    // 参数4: 准备语句
    // 参数5: 通过参数3, 取出参数2的长度字节之后, 剩下的字符串
    sqlite3_stmt *ppStmt = nil;
    if (sqlite3_prepare_v2(_db, sql.UTF8String, -1, &ppStmt, nil) != SQLITE_OK) {
        NSLog(@"准备语句编译失败");
        return nil;
    }
    
    // 2. 绑定数据(省略)
    
    // 3. 执行
    // 大数组
    NSMutableArray *rowDicArray = [NSMutableArray array];
    while (sqlite3_step(ppStmt) == SQLITE_ROW) {
        // 一行记录 -> 字典
        // 1. 获取所有列的个数
        int columnCount = sqlite3_column_count(ppStmt);
        
        NSMutableDictionary *rowDic = [NSMutableDictionary dictionary];
        [rowDicArray addObject:rowDic];
        // 2. 遍历所有的列
        for (int i = 0; i < columnCount; i++) {
            // 2.1 获取列名
            const char *columnNameC = sqlite3_column_name(ppStmt, i);
            NSString *columnName = [NSString stringWithUTF8String:columnNameC];
            
            // 2.2 获取列值
            // 不同列的类型, 使用不同的函数, 进行获取
            // 2.2.1 获取列的类型
            int type = sqlite3_column_type(ppStmt, i);
            // 2.2.2 根据列的类型, 使用不同的函数, 进行获取
            id value = nil;
            switch (type) {
                case SQLITE_INTEGER:
                    value = @(sqlite3_column_int(ppStmt, i));
                    break;
                case SQLITE_FLOAT:
                    value = @(sqlite3_column_double(ppStmt, i));
                    break;
                case SQLITE_BLOB:
                    value = CFBridgingRelease(sqlite3_column_blob(ppStmt, i));
                    break;
                case SQLITE_NULL:
                    value = @"";
                    break;
                case SQLITE3_TEXT:
                    value = [NSString stringWithUTF8String: (const char *)sqlite3_column_text(ppStmt, i)];
                    break;
                    
                default:
                    break;
            }
            
            [rowDic setValue:value forKey:columnName];
            
        }
    }
    
    // 4. 重置(省略)
    
    // 5. 释放资源
    sqlite3_finalize(ppStmt);
    
    return rowDicArray;
}


/**
 关闭数据库
 */
- (void)closeDB {
    sqlite3_close(_db);
}

/**
 开始事务
 */
- (void)beginTransaction {
     [self execSQL:@"begin transaction"];
}


/**
 提交事务
 */
- (void)commitTransaction{
    [self execSQL:@"commit transaction"];
}


/**
 回滚事务
 */
- (void)rollBackTransaction {
    [self execSQL:@"rollback transaction"];
}
@end
