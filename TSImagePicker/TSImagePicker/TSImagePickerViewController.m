//
//  TSImagePickerViewController.m
//  TSImagePicker
//
//  Created by Tassel on 15/6/3.
//  Copyright (c) 2015年 Tassel. All rights reserved.
//

#import "TSImagePickerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#define SCALE_FRAME_Y 100.0f
#define BOUNDCE_DURATION 0.3f
#define WEAK_SELF __weak __typeof(&*self)weakSelf = self;

@interface UIView(Screenshot)

-(UIImage*)systemHQPicture;

@end


@implementation UIView(Screenshot)

-(UIImage*)systemHQPicture
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, [UIScreen mainScreen].scale);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage*image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end

@interface CropViewController:UIViewController

typedef void (^DidCropImageBlock)(CropViewController *cropViewController,UIImage *editedImage);
typedef void (^DidCancelCropBlock)(CropViewController *cropViewController);

@property (nonatomic,assign) CGRect cropFrame;

@property (nonatomic,strong) UIImage *originalImage;
@property (nonatomic,strong) UIImage *editedImage;

@property (nonatomic,strong) UIImageView *showImgView;
@property (nonatomic,strong) UIView      *overlayView;
@property (nonatomic,strong) UIView      *ratioView;

@property (nonatomic,assign) CGRect  oldFrame;
@property (nonatomic,assign) CGRect  largeFrame;
@property (nonatomic,assign) CGFloat limitRatio;

@property (nonatomic,assign) CGRect  latestFrmae;

@property (nonatomic,copy) DidCropImageBlock cropImageBlock;
@property (nonatomic,copy) DidCancelCropBlock cancelCropBlock;

- (instancetype)initWithImage:(UIImage *)originalImage
                    cropFrame:(CGRect)cropFrame
              limitScaleRatio:(NSInteger)limitRatio;

@end

@implementation CropViewController

- (void)dealloc {

    self.originalImage = nil;
    self.showImgView = nil;
    self.editedImage = nil;
    self.overlayView = nil;
    self.ratioView = nil;

}


- (instancetype)initWithImage:(UIImage *)originalImage
                    cropFrame:(CGRect)cropFrame
              limitScaleRatio:(NSInteger)limitRatio {

    self = [super init];
    
    if (self) {
        
        self.cropFrame = cropFrame;
        self.limitRatio = limitRatio;
        self.originalImage = [self fixOrientation:originalImage];
        
        
    }
    return self;

}

- (void)viewDidLoad {

    [super viewDidLoad];
    [self initView];
    [self setupControlView];
}

-(BOOL)prefersStatusBarHidden {

    return YES;

}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];
    [UIApplication sharedApplication].statusBarHidden = YES;

}

- (void)viewDidDisappear:(BOOL)animated {

    [super viewDidDisappear:animated];
    [UIApplication sharedApplication].statusBarHidden = NO;

}

- (BOOL)shouldAutorotate {

    return NO;

}
- (void)initView {

    self.view.backgroundColor = [UIColor blackColor];
    self.view.alpha = 0.8;
    
    
    self.showImgView = ({
    
       UIImageView *imageView  = [[UIImageView alloc] initWithFrame:self.view.frame];
       imageView.backgroundColor = [UIColor clearColor];
        imageView.multipleTouchEnabled = YES;
        imageView.userInteractionEnabled = YES;
        imageView;
    });
    [self.showImgView setImage:self.originalImage];
    
    // scale to fit the screen
    
    CGFloat oriWidth = self.cropFrame.size.width;
    CGFloat oriHeight = self.originalImage.size.height * (oriWidth / self.originalImage.size.width);
    CGFloat oriX = self.cropFrame.origin.x + (self.cropFrame.size.width - oriWidth)/2;
    CGFloat oriY = self.cropFrame.origin.y + (self.cropFrame.size.height - oriHeight)/2;
    
    self.oldFrame = CGRectMake(oriX, oriY, oriWidth, oriHeight);
    self.latestFrmae = self.oldFrame;
    self.showImgView.frame = self.oldFrame;
    
    
    
    self.largeFrame = CGRectMake(0, 0, self.limitRatio *self.oldFrame.size.width,self.limitRatio * self.oldFrame.size.height);
    
    [self addGestureRecognizers];
    [self.view addSubview:self.showImgView];
    
    
    self.overlayView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.overlayView.alpha = 1;
    self.overlayView.backgroundColor = [UIColor clearColor];
    self.overlayView.userInteractionEnabled = NO;
    self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.overlayView];
    
    
    self.ratioView = [[UIView alloc] initWithFrame:self.cropFrame];
    self.ratioView.layer.borderColor = [UIColor whiteColor].CGColor;
    self.ratioView.layer.borderWidth = 1.0f;
    [self.view addSubview:self.ratioView];
    
    [self overlayClipping];
    
}

// register all gestures
- (void) addGestureRecognizers
{
    // add pinch gesture
    UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchView:)];
    [self.view addGestureRecognizer:pinchGestureRecognizer];
    
    // add pan gesture
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panView:)];
    [self.view addGestureRecognizer:panGestureRecognizer];
}

// pinch gesture handler
- (void) pinchView:(UIPinchGestureRecognizer *)pinchGestureRecognizer
{
    UIView *view = self.showImgView;
    if (pinchGestureRecognizer.state == UIGestureRecognizerStateBegan || pinchGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        view.transform = CGAffineTransformScale(view.transform, pinchGestureRecognizer.scale, pinchGestureRecognizer.scale);
        pinchGestureRecognizer.scale = 1;
    }
    else if (pinchGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        CGRect newFrame = self.showImgView.frame;
        newFrame = [self handleScaleOverflow:newFrame];
        newFrame = [self handleBorderOverflow:newFrame];
        [UIView animateWithDuration:BOUNDCE_DURATION animations:^{
            self.showImgView.frame = newFrame;
            self.latestFrmae = newFrame;
        }];
    }
}

// pan gesture handler
- (void) panView:(UIPanGestureRecognizer *)panGestureRecognizer
{
    UIView *view = self.showImgView;
    if (panGestureRecognizer.state == UIGestureRecognizerStateBegan || panGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        // calculate accelerator
        CGFloat absCenterX = self.cropFrame.origin.x + self.cropFrame.size.width / 2;
        CGFloat absCenterY = self.cropFrame.origin.y + self.cropFrame.size.height / 2;
        CGFloat scaleRatio = self.showImgView.frame.size.width / self.cropFrame.size.width;
        CGFloat acceleratorX = 1 - ABS(absCenterX - view.center.x) / (scaleRatio * absCenterX);
        CGFloat acceleratorY = 1 - ABS(absCenterY - view.center.y) / (scaleRatio * absCenterY);
        CGPoint translation = [panGestureRecognizer translationInView:view.superview];
        [view setCenter:(CGPoint){view.center.x + translation.x * acceleratorX, view.center.y + translation.y * acceleratorY}];
        [panGestureRecognizer setTranslation:CGPointZero inView:view.superview];
    }
    else if (panGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        // bounce to original frame
        CGRect newFrame = self.showImgView.frame;
        newFrame = [self handleBorderOverflow:newFrame];
        [UIView animateWithDuration:BOUNDCE_DURATION animations:^{
            self.showImgView.frame = newFrame;
            self.latestFrmae = newFrame;
        }];
    }
}

- (CGRect)handleScaleOverflow:(CGRect)newFrame {
    // bounce to original frame
    CGPoint oriCenter = CGPointMake(newFrame.origin.x + newFrame.size.width/2, newFrame.origin.y + newFrame.size.height/2);
    if (newFrame.size.width < self.oldFrame.size.width) {
        newFrame = self.oldFrame;
    }
    if (newFrame.size.width > self.largeFrame.size.width) {
        newFrame = self.largeFrame;
    }
    newFrame.origin.x = oriCenter.x - newFrame.size.width/2;
    newFrame.origin.y = oriCenter.y - newFrame.size.height/2;
    return newFrame;
}

- (CGRect)handleBorderOverflow:(CGRect)newFrame {
    // horizontally
    if (newFrame.origin.x > self.cropFrame.origin.x) newFrame.origin.x = self.cropFrame.origin.x;
    if (CGRectGetMaxX(newFrame) < self.cropFrame.size.width) newFrame.origin.x = self.cropFrame.size.width - newFrame.size.width;
    // vertically
    if (newFrame.origin.y > self.cropFrame.origin.y) newFrame.origin.y = self.cropFrame.origin.y;
    if (CGRectGetMaxY(newFrame) < self.cropFrame.origin.y + self.cropFrame.size.height) {
        newFrame.origin.y = self.cropFrame.origin.y + self.cropFrame.size.height - newFrame.size.height;
    }
    // adapt horizontally rectangle
    if (self.showImgView.frame.size.width > self.showImgView.frame.size.height && newFrame.size.height <= self.cropFrame.size.height) {
        newFrame.origin.y = self.cropFrame.origin.y + (self.cropFrame.size.height - newFrame.size.height) / 2;
    }
    return newFrame;
}

-(UIImage *)getSubImage{
    CGRect squareFrame = self.cropFrame;
    CGFloat scaleRatio = self.latestFrmae.size.width / self.originalImage.size.width;
    CGFloat x = (squareFrame.origin.x - self.latestFrmae.origin.x) / scaleRatio;
    CGFloat y = (squareFrame.origin.y - self.latestFrmae.origin.y) / scaleRatio;
    CGFloat w = squareFrame.size.width / scaleRatio;
    CGFloat h = squareFrame.size.height / scaleRatio;
    if (self.latestFrmae.size.width < self.cropFrame.size.width) {
        CGFloat newW = self.originalImage.size.width;
        CGFloat newH = newW * (self.cropFrame.size.height / self.cropFrame.size.width);
        x = 0; y = y + (h - newH) / 2;
        w = newH; h = newH;
    }
    if (self.latestFrmae.size.height < self.cropFrame.size.height) {
        CGFloat newH = self.originalImage.size.height;
        CGFloat newW = newH * (self.cropFrame.size.width / self.cropFrame.size.height);
        x = x + (w - newW) / 2; y = 0;
        w = newH; h = newH;
    }
    CGRect myImageRect = CGRectMake(x, y, w, h);
    CGImageRef imageRef = self.originalImage.CGImage;
    CGImageRef subImageRef = CGImageCreateWithImageInRect(imageRef, myImageRect);
    CGSize size;
    size.width = myImageRect.size.width;
    size.height = myImageRect.size.height;
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextDrawImage(context, myImageRect, subImageRef);
    UIImage* smallImage = [UIImage imageWithCGImage:subImageRef];
    CGImageRelease(subImageRef);
    UIGraphicsEndImageContext();
    return smallImage;
}


- (void)overlayClipping {
    
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGMutablePathRef path = CGPathCreateMutable();
    
    
    //Top side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(0, 0,
                                        CGRectGetWidth(self.overlayView.frame),
                                        CGRectGetMidY(self.ratioView.frame)));
    
    
    //Bottom side of the raio view
    CGPathAddRect(path, nil, CGRectMake(0, CGRectGetMidY(self.ratioView.frame) - CGRectGetHeight(self.ratioView.frame),
                                        CGRectGetWidth(self.overlayView.frame),
                                        CGRectGetHeight(self.overlayView.frame) - CGRectGetMidY(self.ratioView.frame) - CGRectGetHeight(self.ratioView.frame)));

    
    //Left side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(0, 0,
                                        CGRectGetMaxX(self.ratioView.frame),
                                        CGRectGetHeight(self.overlayView.frame)));
    //Right side of the ratio view
    CGPathAddRect(path, nil, CGRectMake(CGRectGetMaxX(self.ratioView.frame) + CGRectGetWidth(self.ratioView.frame), 0,
                                       CGRectGetWidth(self.overlayView.frame) - CGRectGetMaxX(self.ratioView.frame) - CGRectGetWidth(self.ratioView.frame) ,
                                        CGRectGetHeight(self.overlayView.frame)));

    
    maskLayer.path = path;
    self.overlayView.layer.mask = maskLayer;
    CGPathRelease(path);
    
}

- (void)setupControlView {


    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.frame)-50.f, CGRectGetWidth(self.view.frame), 50)];
    bottomView.backgroundColor = [UIColor colorWithRed:16/255.0 green:16/255.0 blue:16/255.0 alpha:1];
    [self.view addSubview:bottomView];

    
    UIButton *cancelBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    cancelBtn.titleLabel.textColor = [UIColor whiteColor];
    [cancelBtn setTitle:@"重拍" forState:UIControlStateNormal];
    cancelBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
    [cancelBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:18.0f]];
    [cancelBtn.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [cancelBtn.titleLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [cancelBtn.titleLabel setNumberOfLines:0];
    [cancelBtn setTitleEdgeInsets:UIEdgeInsetsMake(5.0f, 5.0f, 5.0f, 5.0f)];
    [cancelBtn addTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:cancelBtn];
    
    UIButton *confirmBtn = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(bottomView.frame) - 100.0f,0, 100, 50)];
    confirmBtn.titleLabel.textColor = [UIColor whiteColor];
    [confirmBtn setTitle:@"使用图片" forState:UIControlStateNormal];
    [confirmBtn.titleLabel setFont:[UIFont boldSystemFontOfSize:18.0f]];
    [confirmBtn.titleLabel setTextAlignment:NSTextAlignmentCenter];
    confirmBtn.titleLabel.textColor = [UIColor whiteColor];
    [confirmBtn.titleLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [confirmBtn.titleLabel setNumberOfLines:0];
    [confirmBtn setTitleEdgeInsets:UIEdgeInsetsMake(5.0f, 5.0f, 5.0f, 5.0f)];
    [confirmBtn addTarget:self action:@selector(confirm:) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:confirmBtn];



}

- (void)cancel:(UIButton *)sender {

    self.cancelCropBlock(self);
    [self.navigationController popViewControllerAnimated:NO];
}

- (void)confirm:(UIButton *)sender {


    self.cropImageBlock(self,[self getSubImage]);
    [self dismissViewControler];


}

- (void)dismissViewControler {

    [self dismissViewControllerAnimated:NO completion:^{
        
    }];

}
- (UIImage *)fixOrientation:(UIImage *)srcImg {
    if (srcImg.imageOrientation == UIImageOrientationUp) return srcImg;
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (srcImg.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.width, srcImg.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, srcImg.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (srcImg.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
    
    CGContextRef ctx = CGBitmapContextCreate(NULL, srcImg.size.width, srcImg.size.height,
                                             CGImageGetBitsPerComponent(srcImg.CGImage), 0,
                                             CGImageGetColorSpace(srcImg.CGImage),
                                             CGImageGetBitmapInfo(srcImg.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (srcImg.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            CGContextDrawImage(ctx, CGRectMake(0,0,srcImg.size.height,srcImg.size.width), srcImg.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,srcImg.size.width,srcImg.size.height), srcImg.CGImage);
            break;
    }
    
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

@end






#define  ORIGINAL_MAX_WIDTH 640.f
#define  CONTROLBACK_ALPHA 0.9
@interface TSImagePickerViewController ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate>

@property (nonatomic,strong) AVCaptureSession *captureSession;//
@property (nonatomic,strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic,strong) AVCaptureDevice   *captureDevice;
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic,assign) BOOL isCapturingImage;
@property (nonatomic,strong) UIImageView *capturedImageView;
@property (nonatomic,strong) UIImagePickerController *picker;
@property (nonatomic,strong) UIView *imageSelectedView;
@property (nonatomic,strong) UIImage *selectedImage;



@end

@implementation TSImagePickerViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {


    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;

}
- (void)loadView {

    self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

}
- (BOOL)prefersStatusBarHidden {

    return YES;

}

- (BOOL)shouldAutorotate {

    return NO;
}


- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [self.captureSession startRunning];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    [self.captureSession stopRunning];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupCamera];

}



- (void)setupCamera {


    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    
    self.captureVideoPreviewLayer = ({
    
        AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        previewLayer.frame = self.view.frame;
        previewLayer;
    
    });

    [self.view.layer addSublayer:_captureVideoPreviewLayer];
    
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    if (devices.count > 0) {
        
        self.captureDevice = devices.firstObject;
        
        NSError *error = nil;
        
        AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:&error];
        
        [self.captureSession addInput:captureInput];
        
        
        self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
        [self.stillImageOutput setOutputSettings:outputSettings];
        [self.captureSession addOutput:self.stillImageOutput];
        
        
     UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        if (orientation == UIInterfaceOrientationLandscapeLeft) {
            
            _captureVideoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
        }else if (orientation == UIInterfaceOrientationLandscapeRight) {
        
            _captureVideoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;

        
        }
        
        [self setupTopBarView];
        [self setupBottomBarView];
        
        
    }
    
    //[self setupSelectImageView];

    [self flashSwitch:nil];

}


- (void)setupTopBarView {

    
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,CGRectGetWidth(self.view.frame), 44)];
    topView.backgroundColor = [UIColor blackColor];
    topView.alpha = CONTROLBACK_ALPHA;
    [self.view addSubview:topView];
    
    
    
    //flash
    UIButton *flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [flashButton addTarget:self action:@selector(flashSwitch:) forControlEvents:UIControlEventTouchUpInside];
    [flashButton setImage:[UIImage imageNamed:[self getBundleName:@"flashing_auto"]] forState:UIControlStateNormal];
    flashButton.frame = CGRectMake(15, 8,28, 28);
    [topView addSubview:flashButton];
    
    //switch capture device
    
    UIButton *switchCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [switchCameraButton addTarget:self action:@selector(cameraSwitch:) forControlEvents:UIControlEventTouchUpInside];

    [switchCameraButton setImage:[UIImage imageNamed:[self getBundleName:@"switch_camera"]] forState:UIControlStateNormal];
    switchCameraButton.frame = CGRectMake(CGRectGetWidth(self.view.frame)-15-28, 5, 28,28);
    [topView addSubview:switchCameraButton];


}


- (void)setupBottomBarView {


    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.frame)-80, CGRectGetWidth(self.view.frame), 80)];
    bottomView.backgroundColor = [UIColor blackColor];
    bottomView.alpha = CONTROLBACK_ALPHA;
    [self.view addSubview:bottomView];

    if (_showAlbum) {
        
        UIButton *albumButton = [UIButton buttonWithType:UIButtonTypeCustom];
        albumButton.frame = CGRectMake(CGRectGetWidth(bottomView.frame)-40-15, 20, 40, 40);
        [albumButton setImage:[UIImage imageNamed:[self getBundleName:@"library"]] forState:UIControlStateNormal];
        [albumButton addTarget:self action:@selector(showAlbum:) forControlEvents:UIControlEventTouchUpInside];
        [bottomView addSubview:albumButton];
    }
 
    
    
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancelButton setFrame:CGRectMake(15, 20,40 , 40)];
    [cancelButton setImage:[UIImage imageNamed:[self getBundleName:@"close"]] forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelControl:) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:cancelButton];
    
    
    UIButton *takeSnapButton = [UIButton buttonWithType:UIButtonTypeCustom];
    takeSnapButton.frame = CGRectMake(0, 0, 70, 70);
    [takeSnapButton setBackgroundImage:[UIImage imageNamed:[self getBundleName:@"capture"]] forState:UIControlStateNormal];
    takeSnapButton.center = CGPointMake(CGRectGetWidth(bottomView.frame)/2, CGRectGetHeight(bottomView.frame)/2)
;
   // NSLog(@"-[------ %@",NSStringFromCGPoint(takeSnapButton.center));
    [takeSnapButton addTarget:self action:@selector(capturePhoto:) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:takeSnapButton];


}

- (void)setupSelectImageView {

    self.capturedImageView = ({
    
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        imageView.frame = self.view.frame;
        imageView.backgroundColor = [UIColor clearColor];
        imageView.userInteractionEnabled = YES;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView;
    
    });
    
    _imageSelectedView = [[UIView alloc] initWithFrame:self.view.frame];
    _imageSelectedView.backgroundColor = [UIColor clearColor];
    [_imageSelectedView addSubview:self.capturedImageView];
    
    
    
    UIView *overlayView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.frame)-60, CGRectGetWidth(self.view.frame), 60)];
    overlayView.backgroundColor = [UIColor blackColor]
    ;
    overlayView.alpha = 0.8;
    [self.imageSelectedView addSubview:overlayView];
    
    
    
    UIButton *selectPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    selectPhotoButton.frame = CGRectMake(CGRectGetWidth(overlayView.frame)-40, 20, 32, 32);
    [selectPhotoButton addTarget:self action:@selector(selectPhoto:) forControlEvents:UIControlEventTouchUpInside];
    [selectPhotoButton setImage:[UIImage imageNamed:[self getBundleName:@"photoSelected"]] forState:UIControlStateNormal];

    [overlayView addSubview:selectPhotoButton];
    
    
    UIButton *cancelSelectPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelSelectPhotoButton.frame = CGRectMake(5, 20, 32, 32);
    [cancelSelectPhotoButton addTarget:self action:@selector(cancelSelectPhoto:) forControlEvents:UIControlEventTouchUpInside];
    [cancelSelectPhotoButton setImage:[UIImage imageNamed:[self getBundleName:@"close"]] forState:UIControlStateNormal];
    [overlayView addSubview:cancelSelectPhotoButton];
    
    



}

- (NSString *)getBundleName:(NSString *)imageName {

    return [NSString stringWithFormat:@"TSImages.bundle/%@",imageName];

};

#pragma mark - Control

- (void)flashSwitch:(UIButton *)sender {

    if ([self.captureDevice isFlashAvailable]) {

        [_captureDevice lockForConfiguration:nil];
         NSString *imgStr= @"";
       
            if (!sender) {
                
                //defult flash mode
                _captureDevice.flashMode = AVCaptureFlashModeAuto;
                
            }else {
            
            
                if (_captureDevice.flashMode == AVCaptureFlashModeOff) {
                    _captureDevice.flashMode = AVCaptureFlashModeOn;
                    imgStr = @"flashing_on.png";
                    
                } else if (_captureDevice.flashMode == AVCaptureFlashModeOn) {
                    _captureDevice.flashMode = AVCaptureFlashModeAuto;
                    imgStr = @"flashing_auto.png";
                    
                } else if (_captureDevice.flashMode == AVCaptureFlashModeAuto) {
                    _captureDevice.flashMode = AVCaptureFlashModeOff;
                    imgStr = @"flashing_off.png";
                    
                }

            }
        
            if (sender) {
                [sender setImage:[UIImage imageNamed:[self getBundleName:imgStr]] forState:UIControlStateNormal];
            }

        [self.captureDevice unlockForConfiguration];
    }
    

}

- (void)cameraSwitch:(UIButton *)sender {


    if (!self.isCapturingImage) {
        
        
        if (self.captureDevice == [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][0]) {
            
            //front

            [self configCaptureSession:[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][1]];
            
        } else  if (self.captureDevice == [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][1]) {
        
            //rear
            [self configCaptureSession:[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][0]];

        }
        
        //reset flash btn
        
    }
    

}


- (void)configCaptureSession:(AVCaptureDevice *)avCaptureDevice {


    self.captureDevice = avCaptureDevice;
    [self.captureSession beginConfiguration];
    
    AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:nil];
    
    for (AVCaptureDeviceInput *oldInput in self.captureSession.inputs) {
        
        [self.captureSession removeInput:oldInput];
    }
    
    [self.captureSession addInput:newInput];
    [self.captureSession commitConfiguration];



}

- (void)capturePhoto:(UIButton *)sender {

    self.isCapturingImage = YES;
    
    AVCaptureConnection *videoConnection = nil;
    
    for (AVCaptureConnection *connection in _stillImageOutput.connections) {
        
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                
                videoConnection = connection;
                break;
            }
        }
        
        if (videoConnection) {break;}
        
    }
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
       
        if (imageDataSampleBuffer != NULL) {
            
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *capturedImage = [[UIImage alloc] initWithData:imageData scale:1 ];
            
            
            WEAK_SELF
            //前置摄像头
            if (self.captureDevice == [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][1]) {
                
                capturedImage = [[UIImage alloc] initWithCGImage:capturedImage.CGImage scale:1 orientation:UIImageOrientationLeftMirrored];
            }
            
            self.isCapturingImage = NO;
//            //self.capturedImageView.image = capturedImage;
//            _imageSelectedView.backgroundColor = [UIColor clearColor];
//            [self.view addSubview:_imageSelectedView];
//            self.selectedImage = capturedImage;
            imageData = nil;
            

            

            [weakSelf showCropViewController:capturedImage];
           

        }
        
        
    }];

    


}



- (void)showCropViewController:(UIImage *)capturedImage {

    WEAK_SELF
    CropViewController *imgCropperVC = [[CropViewController alloc] initWithImage:[self imageByScalingToMaxSize:capturedImage] cropFrame:CGRectMake(0, 100.0f, self.view.frame.size.width, self.view.frame.size.width) limitScaleRatio:3.0];
    imgCropperVC.cropImageBlock = ^(CropViewController *cropViewController,UIImage *editedImage) {
        
        [weakSelf saveImageToPhotoAlbum:editedImage];
        weakSelf.didCropImageBlock(editedImage);
        //[_imageSelectedView removeFromSuperview];
    };
    imgCropperVC.cancelCropBlock = ^(CropViewController *cropViewController) {
        
        //                [_imageSelectedView removeFromSuperview];
        
    };
    [weakSelf.navigationController pushViewController:imgCropperVC animated:NO];




}


- (void)cancelControl:(UIButton *)sender {
   
    self.didCancelCropImageBlock();
    [self dismissViewControlerWithAnimated:YES];

}

- (void)showAlbum:(UIButton *)sender {

    
    if ([self isPhotoLibraryAvailable]) {
        
        if (!_picker) {
            
            self.picker = [[UIImagePickerController alloc]init];
            self.picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            NSMutableArray *mediaTypes = [[NSMutableArray alloc] init];
            [mediaTypes addObject:(__bridge NSString *)kUTTypeImage];
            _picker.mediaTypes = mediaTypes;
            self.picker.delegate = self;
            
        }
        
        [self presentViewController:_picker animated:NO completion:^{
            
        }];

        
    }
  
}

- (void)dismissViewControlerWithAnimated:(BOOL)flag {

    [self dismissViewControllerAnimated:flag completion:^{
        
        
    }];

}


- (void)cancelSelectPhoto:(UIButton *)sender {
    
    //[self.imageSelectedView removeFromSuperview];


}


- (void)selectPhoto:(UIButton *)sender {

    


}


- (void)saveImageToPhotoAlbum:(UIImage*)image {
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error != NULL) {
        NSLog(@"保存失败");
    } else {
        NSLog(@"保存成功");
    }
}


#pragma mark - ImagePickerControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {


    [self dismissViewControllerAnimated:YES completion:^{
        
    }];

}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {

    WEAK_SELF
    
    [picker dismissViewControllerAnimated:NO completion:^{
        
        [weakSelf showCropViewController:info[@"UIImagePickerControllerOriginalImage"]];
        
    }];


}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {

}


#pragma mark - Camera utility
- (BOOL) isCameraAvailable{
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

- (BOOL) isRearCameraAvailable{
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
}

- (BOOL) isFrontCameraAvailable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
}

- (BOOL) doesCameraSupportTakingPhotos {
    return [self cameraSupportsMedia:(__bridge NSString *)kUTTypeImage sourceType:UIImagePickerControllerSourceTypeCamera];
}

- (BOOL) isPhotoLibraryAvailable{
    return [UIImagePickerController isSourceTypeAvailable:
            UIImagePickerControllerSourceTypePhotoLibrary];
}
- (BOOL) canUserPickVideosFromPhotoLibrary{
    return [self
            cameraSupportsMedia:(__bridge NSString *)kUTTypeMovie sourceType:UIImagePickerControllerSourceTypePhotoLibrary];
}
- (BOOL) canUserPickPhotosFromPhotoLibrary{
    return [self
            cameraSupportsMedia:(__bridge NSString *)kUTTypeImage sourceType:UIImagePickerControllerSourceTypePhotoLibrary];
}

- (BOOL) cameraSupportsMedia:(NSString *)paramMediaType sourceType:(UIImagePickerControllerSourceType)paramSourceType{
    __block BOOL result = NO;
    if ([paramMediaType length] == 0) {
        return NO;
    }
    NSArray *availableMediaTypes = [UIImagePickerController availableMediaTypesForSourceType:paramSourceType];
    [availableMediaTypes enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *mediaType = (NSString *)obj;
        if ([mediaType isEqualToString:paramMediaType]){
            result = YES;
            *stop= YES;
        }
    }];
    return result;
}


#pragma mark - Image scale utility
- (UIImage *)imageByScalingToMaxSize:(UIImage *)sourceImage {
    if (sourceImage.size.width < ORIGINAL_MAX_WIDTH) return sourceImage;
    CGFloat btWidth = 0.0f;
    CGFloat btHeight = 0.0f;
    if (sourceImage.size.width > sourceImage.size.height) {
        btHeight = ORIGINAL_MAX_WIDTH;
        btWidth = sourceImage.size.width * (ORIGINAL_MAX_WIDTH / sourceImage.size.height);
    } else {
        btWidth = ORIGINAL_MAX_WIDTH;
        btHeight = sourceImage.size.height * (ORIGINAL_MAX_WIDTH / sourceImage.size.width);
    }
    CGSize targetSize = CGSizeMake(btWidth, btHeight);
    return [self imageByScalingAndCroppingForSourceImage:sourceImage targetSize:targetSize];
}

- (UIImage *)imageByScalingAndCroppingForSourceImage:(UIImage *)sourceImage targetSize:(CGSize)targetSize {
    UIImage *newImage = nil;
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
    if (CGSizeEqualToSize(imageSize, targetSize) == NO)
    {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        
        if (widthFactor > heightFactor)
            scaleFactor = widthFactor; // scale to fit height
        else
            scaleFactor = heightFactor; // scale to fit width
        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        
        // center the image
        if (widthFactor > heightFactor)
        {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
        }
        else
            if (widthFactor < heightFactor)
            {
                thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
            }
    }
    UIGraphicsBeginImageContext(targetSize); // this will crop
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    
    [sourceImage drawInRect:thumbnailRect];
    
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    if(newImage == nil) NSLog(@"could not scale image");
    
    //pop the context to get back to the default
    UIGraphicsEndImageContext();
    return newImage;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
@end