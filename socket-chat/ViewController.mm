//
//  ViewController.m
//  socket-chat
//
//  Created by 刘伟 on 15/10/26.
//  Copyright © 2015年 刘伟. All rights reserved.
//

#import "ViewController.h"
#include "sio_client.h"

@interface MessageItem : NSObject
@property NSString* nickname;
@property NSString* content;
@end

@implementation MessageItem

@end

@interface ViewController () <UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITextField *textInput;

@end

using namespace std;
using namespace sio;

@implementation ViewController
{
    NSMutableArray *dataArray;
    sio::client io;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    dataArray = [NSMutableArray new];
    [self addHandlers];
    io.connect("http://10.10.16.184:3000");
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}


void OnLogin(CFTypeRef ctrl, sio::event& ev) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [((__bridge ViewController*)ctrl) showLogin];
    });
}

void OnWelcome(CFTypeRef ctrl, sio::event& ev) {
    __block NSString* content = [NSString stringWithUTF8String:ev.get_message()->get_string().data()];
    dispatch_async(dispatch_get_main_queue(), ^{
        [((__bridge ViewController*)ctrl) addServerMessage:[NSString stringWithFormat:@"[%@] 欢迎你进入聊天室", content]];
    });
}

void OnUserJoin(CFTypeRef ctrl, sio::event& ev) {
    __block NSString* content = [NSString stringWithUTF8String:ev.get_message()->get_string().data()];
    dispatch_async(dispatch_get_main_queue(), ^{
        [((__bridge ViewController*)ctrl) addServerMessage:[NSString stringWithFormat:@"[%@] 进入了聊天室", content]];
    });
}

void OnUserQuit(CFTypeRef ctrl, sio::event& ev) {
    __block NSString* content = [NSString stringWithUTF8String:ev.get_message()->get_string().data()];
    dispatch_async(dispatch_get_main_queue(), ^{
        [((__bridge ViewController*)ctrl) addServerMessage:[NSString stringWithFormat:@"[%@] 离开了聊天室", content]];
    });
}

void OnNewMessage(CFTypeRef ctrl, sio::event& ev) {
    NSString* nickname = [NSString stringWithUTF8String:ev.get_messages()[0]->get_string().data()];
    NSString* content = [NSString stringWithUTF8String:ev.get_messages()[1]->get_string().data()];
    dispatch_async(dispatch_get_main_queue(), ^{
        [((__bridge ViewController*)ctrl) addMessage:content from:nickname];
    });
}

- (void)addHandlers {
    using std::placeholders::_1;
    
    io.socket()->on("need_nickname", std::bind(&OnLogin, (__bridge CFTypeRef)self, _1));
    
    io.socket()->on("user_welcome", std::bind(&OnWelcome, (__bridge CFTypeRef)self, _1));
    
    io.socket()->on("user_join", std::bind(&OnUserJoin, (__bridge CFTypeRef)self, _1));
    
    io.socket()->on("user_quit", std::bind(&OnUserQuit, (__bridge CFTypeRef)self, _1));
    
    io.socket()->on("user_say", std::bind(&OnNewMessage, (__bridge CFTypeRef)self, _1));
}

- (void)showLogin {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"请设置聊天昵称" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
    }];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
        UITextField *textField = alertController.textFields.firstObject;
        if (textField) {
            [self applyNickname:textField.text];
        }
    }];
    okAction.enabled = NO;
    [alertController addAction:cancelAction];
    [alertController addAction:okAction];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * textField) {
        textField.placeholder = @"请输入昵称";
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(alertTextFieldDidChange:) name:UITextFieldTextDidChangeNotification object:textField];
    }];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)applyNickname:(NSString *)nickname {
    if (nickname.length > 0) {
        io.socket()->emit("set_nickname", string_message::create([nickname UTF8String]));
    }
}

- (void)addServerMessage:(NSString *)content {
    [self addMessage:content from:@"系统消息"];
}

- (void)addMessage:(NSString *)content from:(NSString *)nickname {
    MessageItem *msg = [MessageItem new];
    msg.nickname = nickname;
    msg.content = content;
    [dataArray addObject:msg];
    [self.tableView reloadData];
    [self scrollToBottom];
}

- (void)scrollToBottom {
    if (dataArray.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:dataArray.count - 1 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

- (IBAction)send:(id)sender {
    if (self.textInput.text.length > 0) {
        io.socket()->emit("say", string_message::create([self.textInput.text UTF8String]));
        self.textInput.text = @"";
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)alertTextFieldDidChange:(NSNotification*)notification {
    UIAlertController *alertController = (UIAlertController*)self.presentedViewController;
    if (alertController) {
        UITextField *textField = alertController.textFields.firstObject;
        UIAlertAction *okAction = alertController.actions.lastObject;
        if (textField && okAction) {
            okAction.enabled = textField.text.length > 0;
        }
    }
}

- (void)keyboardWillShow:(NSNotification*)notification
{
    CGFloat height = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].origin.y;
    
    [UIView animateWithDuration:0.35 animations:^{
        self.view.frame = CGRectMake(0, 0, self.view.frame.size.width, height);
    }];
}

- (void)keyboardDidShow:(NSNotification*)notification
{
    [self scrollToBottom];
}


- (void)keyboardWillHide:(NSNotification*)notification {
    CGFloat height = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].origin.y;
    
    [UIView animateWithDuration:0.35 animations:^{
        self.view.frame = CGRectMake(0, 0, self.view.frame.size.width, height);
    }];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self.view endEditing:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"chatCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"chatCell"];
    }
    MessageItem *msg = [dataArray objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@: %@", msg.nickname, msg.content];
    return cell;
}

@end
