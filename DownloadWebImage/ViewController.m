//
//  ViewController.m
//  DownloadWebImage
//
//  Created by 非整勿扰 on 16/12/16.
//  Copyright © 2016年 iHTCboy. All rights reserved.
//

#import "ViewController.h"

#import <WebKit/WebKit.h>

#import "RMBlurredView.h"
#import "MLHudAlert.h"




/**
 存在问题： js方法图片不全； 网络线程过多；
 */
@interface ViewController()<WebFrameLoadDelegate, WebResourceLoadDelegate, WebPolicyDelegate, WebDownloadDelegate>

@property (weak) IBOutlet NSTextField *textFiled;

@property (weak) IBOutlet WebView *webView;

@property (weak) IBOutlet NSTextField *savePathFiled;

@property (weak) IBOutlet NSButton *selectBtn;

//@property (nullable, copy) NSString * savePath;
@property (weak) IBOutlet RMBlurredView *bgView;

@property (weak) IBOutlet NSButton *goBackBtn;
@property (weak) IBOutlet NSButton *goForwardBtn;
@property (weak) IBOutlet NSButton *refreshBtn;
@property (weak) IBOutlet NSButton *stopBtn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    self.bgView.tintColor = [NSColor redColor]; //[NSColor colorWithSRGBRed:0.847 green:0.839 blue:0.847 alpha:1];
    
    self.bgView.layer.backgroundColor = [NSColor colorWithSRGBRed:0.949 green:0.949 blue:0.949 alpha:1].CGColor;
    
    self.webView.frameLoadDelegate = self;
    self.webView.resourceLoadDelegate = self;
    self.webView.policyDelegate = self;
    self.webView.downloadDelegate = self;

    [self loadWebViewRequest:@"http://www.gratisography.com"];
    
}


- (void)loadWebViewRequest:(NSString *)urlstr{
    NSURL * url = [NSURL URLWithString:urlstr];
    NSURLRequest *urlRequest = [ NSURLRequest requestWithURL :url];
    [[[self webView] mainFrame] loadRequest:urlRequest];
}


- (IBAction)goBackPage:(NSButton *)sender {
    if (self.webView.canGoBack) {
        if ([self.webView goBack]) {
            sender.enabled = self.webView.canGoBack;
            self.goForwardBtn.enabled = self.webView.canGoForward;
        }
    }
}


- (IBAction)goForwardPage:(NSButton *)sender {
    if (self.webView.canGoForward) {
        if ([self.webView goForward]) {
            sender.enabled = self.webView.canGoForward;
            self.goBackBtn.enabled = self.webView.canGoBack;
        }
    }
}


- (IBAction)refreshWebView:(id)sender {
    [self.webView reload:self.webView];
}

- (IBAction)stopLoadWebView:(id)sender {
    [self.webView stopLoading:self.webView];
}

- (IBAction)gotoWeb:(NSButton *)sender {
    
    if (self.textFiled.stringValue.length) {
        [self loadWebViewRequest:self.textFiled.stringValue];
    }
}


- (IBAction)saveImages:(id)sender {
    if (!self.webView.isLoading) {
        if (!self.savePathFiled.stringValue.length){
            NSOpenPanel *openPanel = [NSOpenPanel new];
            openPanel.allowsOtherFileTypes = NO;
            openPanel.treatsFilePackagesAsDirectories = NO;
            openPanel.canChooseFiles = NO;
            openPanel.canChooseDirectories = YES;
            openPanel.canCreateDirectories = YES;
            openPanel.prompt = @"Choose";
            [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
                if (result == NSFileHandlingPanelOKButton){
                    self.savePathFiled.stringValue = openPanel.URL.path;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self saveImages];
                    });
                }
            }];
        }else{
            [self saveImages];
        }
    }else{
        [MLHudAlert alertWithWindow:[self.view window] type:MLHudAlertTypeWarn message:@"网页还在加载中..."];
    }
}

- (void)saveImages{
    
    [MLHudAlert alertWithWindow:[self.view window] type:MLHudAlertTypeLoading message:@"正在保存中..."];
    
    NSArray * array = [self getImageURLs];
    
    // 创建组
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([[obj class] isSubclassOfClass:[NSString class]]) {
        
            // 异步线程
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                dispatch_group_enter(dispatchGroup);
                // replace some especially string or coustom format
                // 如果网站的小图是 100_100.png 你可以换成大图 1000_1000.png 【需要网站支持才行】
//                NSString * urlStr = [obj stringByReplacingOccurrencesOfString:@"100_100" withString:@"1000_1000"];
                NSURL * url =[NSURL URLWithString:obj];
                NSData * data = [NSData dataWithContentsOfURL:url];
                //创建写入文件内容目录
                if (![[NSFileManager defaultManager] fileExistsAtPath:self.savePathFiled.stringValue]){
                    //创建文件夹路径
                    [[NSFileManager defaultManager] createDirectoryAtPath:self.savePathFiled.stringValue withIntermediateDirectories:YES attributes:nil error:nil];
                }
                
                NSString *savedImagePath = url.pathExtension.length? url.pathExtension : @"png";
                
                if (self.selectBtn.state) {
                    savedImagePath = [NSString stringWithFormat:@"%@/%ldimage.%@",self.savePathFiled.stringValue,idx,savedImagePath];
                } else {
                    savedImagePath = [NSString stringWithFormat:@"%@/%f_image.%@",self.savePathFiled.stringValue,[NSDate date].timeIntervalSince1970,savedImagePath];
                }
                
                NSLog(@"写入文件:%@",savedImagePath);
                [data writeToFile:savedImagePath atomically:YES];

                dispatch_group_leave(dispatchGroup);
            });
        }
    }];
    
    // 全部请求回调完成
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^(){
        [MLHudAlert alertWithWindow:[self.view window] type:MLHudAlertTypeSuccess message:@"图片保存成功！"];
    });
    
}

- (NSArray *)getImageURLs{
    //这里是js，主要目的实现对url的获取
    static  NSString * const jsGetImages =
    @"function getImages(){\
    var objs = document.getElementsByTagName(\"img\");\
    var imgScr = '';\
    for(var i=0;i<objs.length;i++){\
    imgScr = imgScr + objs[i].src + '+';\
    };\
    return imgScr;\
    };";
    
    [self.webView stringByEvaluatingJavaScriptFromString:jsGetImages];//注入js方法
    
    NSString *urlResurlt = [self.webView stringByEvaluatingJavaScriptFromString:@"getImages()"];
    NSMutableArray * mUrlArray = [NSMutableArray arrayWithArray:[urlResurlt componentsSeparatedByString:@"+"]];
    if (mUrlArray.count >= 2) {
        [mUrlArray removeLastObject];
    }
    return mUrlArray;
}



#pragma mark - WebFrameLoadDelegate
//-当页面准备加载新的的URL，调用。
//如果成功，回调 WebResourceLoadDelegate-- willSendRequest
//如果不成功，回调didFailProvisionalLoadWithError
- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
    
    NSLog(@"fonction==%s\n",__FUNCTION__);
    
}


//加载WebResourceLoadDelegate willSendRequest 不成功 出错回调
-(void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    
    NSLog(@"fonction==%s\n",__FUNCTION__);
    
}

//-页面完成加载里调用
- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    NSLog(@"fonction==%s\n",__FUNCTION__);
    
}

//-系统无法自身完成webView UI加载调用
-(void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    NSLog(@"fonction==%s\n",__FUNCTION__);
    
}

- (void)webView:(WebView *)sender didCancelClientRedirectForFrame:(WebFrame *)frame{
    NSLog(@"fonction==%s\n",__FUNCTION__);
}


#pragma mark - WebResourceLoadDelegate
//- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource{
//    NSLog(@"fonction==%s\n",__FUNCTION__);
//    
//    re
//}

//-保存当前请求的 Http地址
-(NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
    
    if ([request.URL.absoluteString hasPrefix:@"http"])
    {
        // 在这里保存 请求的图片链接
        NSLog(@"---- %@  ---- %@",request.URL.absoluteString, request.URL.relativeString);
//        histroyURL = request.URL;
    }
    NSLog(@"fonction==%s\n",__FUNCTION__);
    
    return request;
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource
{
    NSLog(@"fonction==%s\n",__FUNCTION__);
    self.goBackBtn.enabled = sender.canGoBack;
    self.goForwardBtn.enabled = sender.canGoForward;
    self.textFiled.stringValue = dataSource.request.URL.absoluteString;
    
}


//当资源未能加载时调用
- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource
{
    
    NSLog(@"fonction==%s\n",__FUNCTION__);
    //忽略未加载完成URL错误
    if (error.code == NSURLErrorCancelled)
    {
        return ;
    }
    

    
}

- (void)webView:(WebView *)sender plugInFailedWithError:(NSError *)error dataSource:(WebDataSource *)dataSource
{
    NSLog(@"fonction==%s\n",__FUNCTION__);
    
}

- (void)webView:(WebView *)sender resource:(id)identifier didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)dataSource{
        NSLog(@"fonction==%s\n",__FUNCTION__);
}


- (void)webView:(WebView *)sender resource:(id)identifier didReceiveResponse:(NSURLResponse *)response fromDataSource:(WebDataSource *)dataSource{
        NSLog(@"fonction==%s\n",__FUNCTION__);
}

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveContentLength:(NSInteger)length fromDataSource:(WebDataSource *)dataSource{
        NSLog(@"fonction==%s\n",__FUNCTION__);
}

#pragma mark - WebPolicyDelegate
- (void)webView:(WebView *)webView unableToImplementPolicyWithError:(NSError *)error frame:(WebFrame *)frame
{
    NSLog(@"fonction==%s\n",__FUNCTION__);
}


- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
          frame:(WebFrame *)frame
decisionListener:(id<WebPolicyDecisionListener>)listener;{
    NSLog(@"request---%@", request.URL.absoluteString);
    if (request.URL.absoluteString.length) {
        [listener use];
//        [[webView mainFrame] loadRequest:request];
//        [self loadWebViewRequest:request.URL.absoluteString];
    }
    NSLog(@"fonction==%s\n",__FUNCTION__);
}


- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
   newFrameName:(NSString *)frameName
decisionListener:(id<WebPolicyDecisionListener>)listener{
    NSLog(@"request---%@", request);
    [listener ignore];
    [self loadWebViewRequest:request.URL.absoluteString];
    NSLog(@"fonction==%s\n",__FUNCTION__);
}


- (void)webView:(WebView *)webView decidePolicyForMIMEType:(NSString *)type
        request:(NSURLRequest *)request
          frame:(WebFrame *)frame
decisionListener:(id<WebPolicyDecisionListener>)listener{
    NSLog(@"fonction==%s\n",__FUNCTION__);
}


#pragma mark 
- (NSWindow *)downloadWindowForAuthenticationSheet:(WebDownload *)download{
    NSLog(@"fonction==%s\n",__FUNCTION__);
    return nil;
}


- (void)savePDF:(id)sender {
    NSData *pdfData = [[[[self.webView mainFrame] frameView] documentView] dataWithPDFInsideRect:[[[self.webView mainFrame] frameView] documentView].frame];
//    PDFDocument *document = [[PDFDocument alloc] initWithData:pdfData];
//    
//    [self setSaveDirectory];
//    
//    NSString *fileName = [NSString stringWithFormat:@"%@/testing.pdf",saveDir];
//    NSLog(@"Save location: %@",fileName);
//    
//    [document writeToFile:fileName];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
