//
//  ViewController.m
//  TSImagePicker
//
//  Created by Tassel on 15/6/3.
//  Copyright (c) 2015年 Tassel. All rights reserved.
//

#import "ViewController.h"
#import "TSImagePickerViewController.h"

@interface ViewController ()
@property (nonatomic,strong) UIImageView *imgView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];




    _imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 300)];
    [self.view addSubview:_imgView];
    
    
    UIButton *cameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cameraButton.frame = CGRectMake(100, 310, 100, 100);
    [cameraButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [cameraButton setTitle:@"相机" forState:UIControlStateNormal];
    [cameraButton addTarget:self action:@selector(openCamera) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cameraButton];

}

- (void)openCamera {

    TSImagePickerViewController *ts = [[TSImagePickerViewController alloc] init];
    ts.showAlbum = YES;
    ts.didCropImageBlock = ^(UIImage *editedImage) {
    
        [_imgView setImage:editedImage];
        
    };
 
    ts.didCancelCropImageBlock = ^(){
    
        NSLog(@"取消相机");
    
    };
    
    
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:ts];
    nav.navigationBarHidden = YES;
    [self presentViewController:nav animated:YES completion:^{
        
    }];

}
- (BOOL)prefersStatusBarHidden {
    
    return YES;
    
}

-  (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];
    
    [UIApplication sharedApplication].statusBarHidden = YES;


}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end





