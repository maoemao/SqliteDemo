//
//  ViewController.m
//  Sqlite3Demo
//
//  Created by baina on 2018/3/5.
//  Copyright © 2018年 ACE. All rights reserved.
//

#import "ViewController.h"
#import "DataBaseManager.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [[DataBaseManager sharedManager] beginTransaction:^(DataBaseManager *dataBase, BOOL *rollback) {
        for (int i = 0; i<10000; i++) {
            [dataBase dealSQL:@"insert into t_stu( name, age, score) values ('sz', 18, 0)"];
        }
    }];
    
    
   
    [[DataBaseManager sharedManager] beginExecSQL:^(DataBaseManager *dataBase, BOOL *rollback) {
        for (int i = 0; i<10000; i++) {
            [dataBase dealSQL:@"insert into t_stu( name, age, score) values ('sz', 18, 0)"];
        }
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
