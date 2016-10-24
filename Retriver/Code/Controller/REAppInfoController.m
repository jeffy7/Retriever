//
//  REAppInfoController.m
//  Retriver
//
//  Created by cyan on 2016/10/21.
//  Copyright © 2016年 cyan. All rights reserved.
//

#import "REAppInfoController.h"
#import "RETableView.h"
#import "REAppInfoCell.h"
#import "REInfoCodeController.h"

typedef NS_ENUM(NSInteger, REInfoType) {
    REInfoTypeDictionary    = 0,
    REInfoTypeArray,
    REInfoTypeKeyDict,
    REInfoTypeValue
};

typedef void (^REItemInfoFetchBlock)(UITableViewCellAccessoryType accessoryType, NSString *title, NSString *subtitle);

@interface REAppInfoController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, assign) BOOL isRoot;
@property (nonatomic, strong) NSDictionary *propertyList;
@property (nonatomic, strong) NSArray *keyList;
@property (nonatomic, strong) RETableView *tableView;

@end

@implementation REAppInfoController

- (instancetype)initWithInfo:(id)info {
    if (self = [super init]) {
        NSArray *allKeys;
        if ([info isKindOfClass:NSClassFromString(@"LSApplicationProxy")]) {
            _isRoot = YES;
            _propertyList = [info valueForKeyPath:kREPropertyListKeyPath];
            allKeys = [_propertyList allKeys];
        } else if ([info isKindOfClass:NSClassFromString(@"LSPlugInKitProxy")]) {
            _isRoot = YES;
            _propertyList = [info valueForKey:kREPluginPropertyKey];
            allKeys = [_propertyList allKeys];
        } else if ([info isKindOfClass:NSDictionary.class]) {
            _propertyList = info;
            allKeys = [_propertyList allKeys];
        } else if ([info isKindOfClass:NSArray.class]) {
            allKeys = info;
        }
        _keyList = [allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [[obj1 description] compare:[obj2 description]];
        }];
    }
    return self;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    if (self.isRoot) {
        UIBarButtonItem *shareItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                   target:self
                                                                                   action:@selector(share:)];
        UIBarButtonItem *toggleItem = [[UIBarButtonItem alloc] initWithTitle:@"Code"
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(viewCode:)];
        self.navigationItem.rightBarButtonItems = @[shareItem, toggleItem];
    }
    
    self.tableView = [[RETableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
}

- (void)share:(UIBarButtonItem *)sender {
    NSString *path = AppDocumentPath([NSString stringWithFormat:@"%@.plist", self.title]);
    [self.propertyList writeToFile:path atomically:YES];
    NSURL *fileUrl = [NSURL fileURLWithPath:path];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[fileUrl]
                                                                                         applicationActivities:nil];
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (void)viewCode:(UIBarButtonItem *)sender {
    REInfoCodeController *codeController = [[REInfoCodeController alloc] initWithAppInfo:self.propertyList];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:codeController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - UITableView

- (REInfoType)infoTypeAtIndexPath:(NSIndexPath *)indexPath {
    id key = self.keyList[indexPath.row];
    id value = self.propertyList[key];
    if ([value isKindOfClass:NSDictionary.class]) {
        return REInfoTypeDictionary;
    } else if ([value isKindOfClass:NSArray.class]) {
        return REInfoTypeArray;
    } else if ([key isKindOfClass:NSDictionary.class]) {
        return REInfoTypeKeyDict;
    } else {
        return REInfoTypeValue;
    }
}

- (void)fetchInfoWithIndexPath:(NSIndexPath *)indexPath completionHandler:(REItemInfoFetchBlock)block {
    id key = self.keyList[indexPath.row];
    REInfoType type = [self infoTypeAtIndexPath:indexPath];
    if (type == REInfoTypeValue) {
        block(UITableViewCellAccessoryNone, [key description], [self.propertyList[key] description] ?: @"");
    } else {
        NSString *title;
        if (type == REInfoTypeKeyDict) {
            title = [NSString stringWithFormat:@"Item %d", (int)indexPath.row];
        } else {
            title = [key description];
        }
        block(UITableViewCellAccessoryDisclosureIndicator, title, @"");
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.keyList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"REInfoCell";
    REAppInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[REAppInfoCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    @weakify(cell)
    [self fetchInfoWithIndexPath:indexPath completionHandler:^(UITableViewCellAccessoryType accessoryType, NSString *title, NSString *subtitle) {
        @strongify(cell)
        [cell setAccessoryType:accessoryType title:title subtitle:subtitle];
    }];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    id key = self.keyList[indexPath.row];
    if ([self infoTypeAtIndexPath:indexPath] != REInfoTypeValue) {
        id info = self.propertyList ? self.propertyList[key] : key;
        REAppInfoController *infoController = [[REAppInfoController alloc] initWithInfo:info];
        [self fetchInfoWithIndexPath:indexPath completionHandler:^(UITableViewCellAccessoryType accessoryType, NSString *title, NSString *subtitle) {
            infoController.title = title;
        }];
        [self.navigationController pushViewController:infoController animated:YES];
    }
}

#pragma mark - Menu

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return (action == @selector(copy:));
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    [self fetchInfoWithIndexPath:indexPath completionHandler:^(UITableViewCellAccessoryType accessoryType, NSString *title, NSString *subtitle) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if (isNotBlankText(subtitle)) {
            pasteboard.string = subtitle;
        } else if (isNotBlankText(title)) {
            pasteboard.string = title;
        }
    }];
}

@end