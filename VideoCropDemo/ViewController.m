//
//  ViewController.m
//  VideoCropDemo
//
//  Created by vinsent on 2020/9/1.
//  Copyright © 2020 vintsingle. All rights reserved.
//

#import "ViewController.h"
#import "VideoCropViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    VideoCropViewController *vc = [VideoCropViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}


@end
