//
//  TSImagePickerViewController.h
//  TSImagePicker
//
//  Created by Tassel on 15/6/3.
//  Copyright (c) 2015年 Tassel. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^TSImagePickerCropImageBlock)(UIImage *editedImage);
typedef void (^TSImagePickerCancelCropBlock)();

@interface TSImagePickerViewController : UIViewController
@property (nonatomic) BOOL showAlbum;//是否显示相册
@property (nonatomic,copy) TSImagePickerCropImageBlock didCropImageBlock;//截取后的图片
@property (nonatomic,copy) TSImagePickerCancelCropBlock didCancelCropImageBlock;//取消选择图片
@end
