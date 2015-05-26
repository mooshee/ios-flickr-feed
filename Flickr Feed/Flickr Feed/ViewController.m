//
//  ViewController.m
//  Flickr Feed
//
//  Created by Daniel Hallman on 3/11/13.
//  Copyright (c) 2013 Daniel Hallman. All rights reserved.
//

#import "ViewController.h"
#import <QuartzCore/QuartzCore.h>

#import "FlickrAPIClient.h"
#import "FlickrItem.h"
#import "UIColor+Flickr.h"
#import "GMGridView.h"
#import "UIImageView+AFNetworking.h"

@interface ViewController () <UIScrollViewDelegate, GMGridViewDataSource, GMGridViewActionDelegate, UISearchBarDelegate>

@property (strong, nonatomic) NSArray *items;
@property (strong, nonatomic) GMGridView *gridView;
@property (strong, nonatomic) UISearchBar *searchBar;
@property (strong, nonatomic) NSCharacterSet *invalidCharacterSet;

@property (assign, nonatomic) BOOL isInFullScreenMode;
@property (strong, nonatomic) UITapGestureRecognizer *fullScreenTapGesture;
@property (assign, nonatomic) UIView *contentView;
@property (assign, nonatomic) CGRect originalContentFrame;
@property (strong, nonatomic) UIActivityIndicatorView *activityView;
@property (strong, nonatomic) UILabel *activityLabel;

@end

@implementation ViewController

const CGFloat kSearchBarHeight = 44.0f;
const NSInteger kImageViewTag = 9314;
const NSInteger kTitleLabelTag = 4313;
const CGFloat kTitleLabelVPadding = 8.0f;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Register our full screen touch handler
    _fullScreenTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapFullScreenCell:)];
    
    NSMutableArray *gestures = [NSMutableArray arrayWithArray:_gridView.gestureRecognizers];
    for (UIView *subview in _gridView.subviews) {
        [gestures addObjectsFromArray:subview.gestureRecognizers];
    }
    
    for (UIGestureRecognizer *gesture in gestures) {
        [gesture requireGestureRecognizerToFail:_fullScreenTapGesture];
    }
    
    // Create grid view
    GMGridView *gridView = [[GMGridView alloc] initWithFrame:self.view.bounds];
    gridView.contentInset = UIEdgeInsetsMake(_searchBar.bounds.size.height, 0.0f, 0.0f, 0.0f);
    gridView.clipsToBounds = YES;
    gridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    gridView.itemSpacing = 4;
    gridView.minEdgeInsets = UIEdgeInsetsMake(kSearchBarHeight + 10.0f, 8.0f, 10.0f, 8.0f);
    gridView.scrollIndicatorInsets = UIEdgeInsetsMake(kSearchBarHeight, 0.0f, 0.0f, 0.0f);
    gridView.delegate = self;
    gridView.dataSource = self;
    gridView.actionDelegate = self;
    [self.view addSubview:gridView];
    _gridView = gridView;
    
    // Invalid characters
    NSMutableCharacterSet *validCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
    [validCharacters addCharactersInString:@","];
    _invalidCharacterSet = [validCharacters invertedSet];
    
    // Create search bar
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f,
                                                                           self.view.bounds.size.width,
                                                                           kSearchBarHeight)];
    searchBar.tintColor = [UIColor flickrBlue];
    searchBar.placeholder = NSLocalizedString(@"Search tags", @"Search Bar placeholder");
    searchBar.delegate = self;
    [_gridView addSubview:searchBar];
    _searchBar = searchBar;
    
    // Create activity view
    _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _activityView.frame = CGRectMake((self.view.bounds.size.width - _activityView.frame.size.width) / 2.0f,
                                     (self.view.bounds.size.height - _activityView.frame.size.height) / 3.0f,
                                     _activityView.frame.size.width,
                                     _activityView.frame.size.height);
    [self.gridView addSubview:_activityView];
    
    _activityLabel = [[UILabel alloc] init];
    _activityLabel.text = NSLocalizedString(@"Loading", @"Loading");
    [_activityLabel sizeToFit];
    _activityLabel.frame = CGRectMake((self.view.bounds.size.width - _activityLabel.frame.size.width) / 2.0f,
                                      CGRectGetMaxY(_activityView.frame) + 5.0f,
                                      _activityLabel.frame.size.width,
                                      _activityLabel.frame.size.height);
    [self.gridView addSubview:_activityLabel];
    
    // Load initial publid feed with no tags
    [self loadPhotosWithTags:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private Methods

- (void)showActivity {
    [_activityView startAnimating];
    _activityView.hidden = NO;
    _activityLabel.hidden = NO;
}

- (void)hideActivity {
    [_activityView stopAnimating];
    _activityView.hidden = YES;
    _activityLabel.hidden = YES;
}

- (void)loadPhotosWithTags:(NSArray *)tags {
    [self showActivity];
    
    _items = nil;
    [_gridView reloadData];
    
    [[FlickrAPIClient sharedClient] publicFeedWithTags:tags completionBlock:^(NSDictionary *response, NSError *error)
     {
         if (error == nil) {			 
             NSMutableArray *mutableItems = [NSMutableArray array];
             for (NSDictionary *itemDict in [response objectForKey:@"items"]) {
                 FlickrItem *item = [[FlickrItem alloc] init];
                 item.title = [itemDict objectForKey:@"title"];
                 NSString *photoURLString = [[itemDict objectForKey:@"media"] objectForKey:@"m"];
                 item.thumbnailURL = [NSURL URLWithString:photoURLString];
                 item.largeURL = [NSURL URLWithString:[photoURLString stringByReplacingOccurrencesOfString:@"_m.jpg" withString:@".jpg"]];
                 item.authorID = [itemDict objectForKey:@"author_id"];
                 item.html = [itemDict objectForKey:@"description"];
				 
				 NSString *author = [itemDict objectForKey:@"author"];
				 item.author = author;
				 
				 // Extract username
				 NSRange usernameRange = [author rangeOfString:@"\\(([^)]+)\\)" options:NSRegularExpressionSearch];
				 if (usernameRange.location != NSNotFound) {
					 // Remove parenthesis
					 usernameRange.location += 1;
					 usernameRange.length -= 2;
					 
					 item.username = [author substringWithRange:usernameRange];
				 }
				 
                 [mutableItems addObject:item];
             }
             
             _items = mutableItems;
            [_gridView reloadData];
         } else {
             [[[UIAlertView alloc] initWithTitle:error.localizedDescription
                                         message:error.localizedFailureReason
                                        delegate:nil
                               cancelButtonTitle:nil
                               otherButtonTitles:nil, nil] show];
         }
         
         [self hideActivity];
     }];
}


- (NSArray *)allGridViewGestures {
    NSMutableArray *gestures = [NSMutableArray arrayWithArray:_gridView.gestureRecognizers];
    for (UIView *subview in _gridView.subviews) {
        [gestures addObjectsFromArray:subview.gestureRecognizers];
    }
    return gestures;
}

- (void)executeSearch {
    [self loadPhotosWithTags:[_searchBar.text componentsSeparatedByString:@","]];
    [_searchBar resignFirstResponder];
}

#pragma mark - UIScrollViewDelegate

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Let the search bar scroll away in one direction
    CGRect rect = _searchBar.frame;
    rect.origin.y = MIN(0, scrollView.contentOffset.y);
    _searchBar.frame = rect;
    
    // Dismiss keyboard on scroll
    [_searchBar resignFirstResponder];
}

#pragma mark - UISearchBarDelegate

- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    // Detect enter/search
    if ([text isEqualToString:@"\n"]) {
        [self executeSearch];
        return YES;
    } else {
        NSString *uncleanText = [searchBar.text stringByReplacingCharactersInRange:range withString:text];
        NSArray *components = [uncleanText componentsSeparatedByCharactersInSet:_invalidCharacterSet];
        searchBar.text = [components componentsJoinedByString:@","];
        return NO;
    }    
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{    
    [self executeSearch];
}

#pragma mark - GMGridViewDataSource

- (NSInteger)numberOfItemsInGMGridView:(GMGridView *)gridView
{
    return [_items count];
}

- (CGSize)GMGridView:(GMGridView *)gridView sizeForItemsInInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    return CGSizeMake(98.0f, 98.0f);
}

- (GMGridViewCell *)GMGridView:(GMGridView *)gridView cellForItemAtIndex:(NSInteger)index
{
    CGSize size = [self GMGridView:gridView sizeForItemsInInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
    
    GMGridViewCell *cell = [gridView dequeueReusableCell];
    
    if (!cell)
    {
        cell = [[GMGridViewCell alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        
        
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        view.autoresizesSubviews = YES;
        view.clipsToBounds = YES;
        view.backgroundColor = [UIColor lightGrayColor];
        view.layer.borderColor = [UIColor lightGrayColor].CGColor;
        view.layer.borderWidth = 1.0f;
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:view.bounds];
        imageView.clipsToBounds = YES;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.backgroundColor = [UIColor lightGrayColor];
        imageView.tag = kImageViewTag;
        [view addSubview:imageView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.7f];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.hidden = YES;
        titleLabel.numberOfLines = 0;
        titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.tag = kTitleLabelTag;
        [view addSubview:titleLabel];
		
        cell.contentView = view;
    }
        
    FlickrItem *item = [_items objectAtIndex:index];
    
    UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:kImageViewTag];
    [imageView setImageWithURL:item.thumbnailURL placeholderImage:nil];
    
    cell.contentView.tag = index;
    return cell;
}

#pragma mark - GMGridViewActionDelegate

- (void)GMGridView:(GMGridView *)gridView didTapOnItemAtIndex:(NSInteger)position {
    if (!_isInFullScreenMode) {
        FlickrItem *item = [_items objectAtIndex:position];
        
        GMGridViewCell *cell = [gridView cellForItemAtIndex:position];
        _contentView = cell.contentView;
        _originalContentFrame = cell.contentView.frame;
        [gridView bringSubviewToFront:cell];

        // Start downloading the larger image ASAP
        UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:kImageViewTag];
        [imageView setImageWithURL:item.largeURL placeholderImage:imageView.image];
        
        // Disable other gestures
        _searchBar.userInteractionEnabled = NO;
        [self.view addGestureRecognizer:_fullScreenTapGesture];
        for (UIGestureRecognizer *gesture in [self allGridViewGestures]) {
            gesture.enabled = NO;
        }
        
        // Calculate final rect
        CGRect fullScreenRect = [self.view convertRect:gridView.frame toView:cell.contentView];
		
        // Position title label
        UILabel *titleLabel = (UILabel *)[_contentView viewWithTag:kTitleLabelTag];
        titleLabel.frame = CGRectMake((fullScreenRect.size.width - titleLabel.frame.size.width) / 2.0f,
                                      fullScreenRect.size.height,
                                      fullScreenRect.size.width, 0.0f);
		
		NSMutableArray *stringComponents = [NSMutableArray new];
		if (item.title.length > 0) [stringComponents addObject:item.title];
		if (item.username.length > 0) [stringComponents addObject:item.username];

		titleLabel.text = [stringComponents componentsJoinedByString:@"\n\nby "];
		
        [titleLabel sizeToFit];
		
        CGRect titleFrame = CGRectMake(0.0f,
                                       fullScreenRect.size.height - titleLabel.frame.size.height - 2*kTitleLabelVPadding,
                                       fullScreenRect.size.width,
                                       titleLabel.frame.size.height + 2*kTitleLabelVPadding);
		
        [UIView animateWithDuration:0.5
                              delay:0
                            options:0
                         animations:^{
                             _contentView.frame = fullScreenRect;
                             _contentView.layer.borderWidth = 0.0f;
                             _contentView.contentMode = UIViewContentModeScaleAspectFit;
                             imageView.backgroundColor = [UIColor blackColor];
                         }
                         completion:^(BOOL finished) {
                             _isInFullScreenMode = YES;
                             titleLabel.frame = titleFrame;
                             titleLabel.hidden = NO;
                         }];
    }
}

#pragma mark - UITapGestureRecognizer

- (void)didTapFullScreenCell:(UITapGestureRecognizer *)tapGesture {
    if (_isInFullScreenMode) {        
        FlickrItem *item = [_items objectAtIndex:_contentView.tag];
        
        // Re-enable other gestures
        _searchBar.userInteractionEnabled = YES;
        [self.view removeGestureRecognizer:_fullScreenTapGesture];
        for (UIGestureRecognizer *gesture in [self allGridViewGestures]) {
            gesture.enabled = YES;
        }
        
        UIImageView *imageView = (UIImageView *)[_contentView viewWithTag:kImageViewTag];
        UILabel *titleLabel = (UILabel *)[_contentView viewWithTag:kTitleLabelTag];
        titleLabel.hidden = YES;

        [UIView animateWithDuration:0.5
                              delay:0
                            options:0
                         animations:^{
                             _contentView.frame = _originalContentFrame;
                             _contentView.layer.borderWidth = 1.0f;
                             _contentView.contentMode = UIViewContentModeScaleAspectFill;
                             imageView.backgroundColor = [UIColor lightGrayColor];
                         }
                         completion:^(BOOL finished) {
                             // Set the imageview back to thumbnail size after the animation completes
                             [imageView setImageWithURL:item.thumbnailURL placeholderImage:imageView.image];
                             _isInFullScreenMode = NO;
                         }];
    }
}

@end
