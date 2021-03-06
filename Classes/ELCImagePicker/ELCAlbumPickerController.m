//
//  AlbumPickerController.m
//
//  Created by ELC on 2/15/11.
//  Copyright 2011 ELC Technologies. All rights reserved.
//

#import "ELCAlbumPickerController.h"
#import "ELCImagePickerController.h"
#import "ELCAssetTablePicker.h"
#import "ViewRouter.h"

@interface ELCAlbumPickerController ()

@property (nonatomic, strong) ALAssetsLibrary *library;
@property (nonatomic, strong) ALAssetsGroup *recentsGroup;

@end

@implementation ELCAlbumPickerController

//Using auto synthesizers

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	[self.navigationItem setTitle:@"Loading..."];

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self.parent action:@selector(cancelImagePicker)];
	[self.navigationItem setRightBarButtonItem:cancelButton];

    NSMutableArray *tempArray = [[NSMutableArray alloc] init];
	self.assetGroups = tempArray;
    
    NSMutableArray *nameArray = [[NSMutableArray alloc] init];
    
    ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
    self.library = assetLibrary;

    // Load Albums into assetGroups
    dispatch_async(dispatch_get_main_queue(), ^
    {
        @autoreleasepool {
        
        // Group enumerator Block
            void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) = ^(ALAssetsGroup *group, BOOL *stop) 
            {
                if (group == nil) {
                    ELCAssetTablePicker *picker = [[ELCAssetTablePicker alloc] initWithNibName: nil bundle: nil];
                    picker.parent = self;

                    picker.assetGroup = self.recentsGroup;
                    if (self.recentsGroup) {
                        [picker.assetGroup setAssetsFilter:[ALAssetsFilter allPhotos]];
                        
                        picker.assetPickerFilterDelegate = self.assetPickerFilterDelegate;
                        
                        [self.navigationController pushViewController:picker animated:NO];
                    }
                    return;
                }
                
                // added fix for camera albums order
                NSString *sGroupPropertyName = (NSString *)[group valueForProperty:ALAssetsGroupPropertyName];
                NSUInteger nType = [[group valueForProperty:ALAssetsGroupPropertyType] intValue];
                
                if([sGroupPropertyName isEqualToString:@"All Photos"] ||
                        [sGroupPropertyName isEqualToString:@"Todas las fotos"] ||
                        [sGroupPropertyName isEqualToString:@"Recents"] ||
                        [sGroupPropertyName isEqualToString:@"Recientes"]){
                    self.recentsGroup = group;
                }

                if (group.numberOfAssets > 0 && ![nameArray containsObject:sGroupPropertyName] &&
                    ![sGroupPropertyName isEqualToString:@"Videos"] &&
                    ![sGroupPropertyName isEqualToString:@"Vídeos"] &&
                    ![sGroupPropertyName isEqualToString:@"Slo-mo"] &&
                    ![sGroupPropertyName isEqualToString:@"Screen Recordings"] &&
                    ![sGroupPropertyName isEqualToString:@"Cámara lenta"] &&
                    ![sGroupPropertyName isEqualToString:@"Grabaciones de pantalla"])
                {
                    [self.assetGroups addObject:group];
                    [nameArray addObject:sGroupPropertyName];
                }
                
                // Reload albums
                [self performSelectorOnMainThread:@selector(reloadTableView) withObject:nil waitUntilDone:YES];
            };
            
            // Group Enumerator Failure Block
            void (^assetGroupEnumberatorFailure)(NSError *) = ^(NSError *error) {
                
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"To upload a photo, the App needs your permission. Tap Settings and change the access to Photos.", @"")
                                                                            message:nil
                                                                     preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"")
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction *action){
                    [self.parentViewController dismissViewControllerAnimated:YES
                    completion:nil];
                }]];
                [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Settings", @"")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action){
                    [self.parentViewController dismissViewControllerAnimated:YES
                                                                  completion:nil];
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                }]];
                [self presentViewController:ac animated:YES completion:nil];
            };
            
            
                    
            // Enumerate Albums
            [self.library enumerateGroupsWithTypes:ALAssetsGroupAll
                                        usingBlock:assetGroupEnumerator
                                      failureBlock:assetGroupEnumberatorFailure];
        }
    });    
}

- (void)reloadTableView
{
	[self.tableView reloadData];
	[self.navigationItem setTitle:@"Select an Album"];
}

- (BOOL)shouldSelectAsset:(ELCAsset *)asset previousCount:(NSUInteger)previousCount
{
    return [self.parent shouldSelectAsset:asset previousCount:previousCount];
}

- (void)selectedAssets:(NSArray*)assets
{
	[_parent selectedAssets:assets];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.assetGroups count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Get count
    ALAssetsGroup *g = (ALAssetsGroup*)[self.assetGroups objectAtIndex:indexPath.row];
    [g setAssetsFilter:[ALAssetsFilter allPhotos]];
    NSInteger gCount = [g numberOfAssets];
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%ld)",[g valueForProperty:ALAssetsGroupPropertyName], (long)gCount];
    [cell.imageView setImage:[UIImage imageWithCGImage:[(ALAssetsGroup*)[self.assetGroups objectAtIndex:indexPath.row] posterImage]]];
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	ELCAssetTablePicker *picker = [[ELCAssetTablePicker alloc] initWithNibName: nil bundle: nil];
	picker.parent = self;

    picker.assetGroup = [self.assetGroups objectAtIndex:indexPath.row];
    [picker.assetGroup setAssetsFilter:[ALAssetsFilter allPhotos]];
    
	picker.assetPickerFilterDelegate = self.assetPickerFilterDelegate;
	
	[self.navigationController pushViewController:picker animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 57;
}

@end

