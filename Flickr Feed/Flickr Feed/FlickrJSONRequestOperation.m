//
//  FlickrJSONRequestOperation.m
//  Flickr Feed
//
//  Created by Daniel Hallman on 3/12/13.
//  Copyright (c) 2013 Daniel Hallman. All rights reserved.
//

#import "FlickrJSONRequestOperation.h"

@interface FlickrJSONRequestOperation ()

@property (readwrite, nonatomic, strong) id responseJSON;
@property (readwrite, nonatomic, strong) NSError *JSONError;
@property (readwrite, nonatomic, strong) NSRecursiveLock *lock;

@end

@implementation FlickrJSONRequestOperation
@synthesize responseJSON = _responseJSON;
@synthesize JSONReadingOptions = _JSONReadingOptions;
@synthesize JSONError = _JSONError;
//@dynamic responseJSON;
//@dynamic JSONError;
@dynamic lock;

+ (NSSet *)acceptableContentTypes;
{
    return [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/plain", @"application/x-javascript", nil];
}

+ (instancetype)JSONRequestOperationWithRequest:(NSURLRequest *)urlRequest
										success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, id JSON))success
										failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON))failure
{
    FlickrJSONRequestOperation *requestOperation = [(FlickrJSONRequestOperation *)[self alloc] initWithRequest:urlRequest];
    [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success(operation.request, operation.response, responseObject);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(operation.request, operation.response, error, [(AFJSONRequestOperation *)operation responseJSON]);
        }
    }];
    
    return requestOperation;
}


- (id)responseJSON {
    [self.lock lock];
    if (!_responseJSON && [self.responseData length] > 0 && [self isFinished] && !self.JSONError) {
        NSError *error = nil;
        
        // Workaround for behavior of Rails to return a single space for `head :ok` (a workaround for a bug in Safari), which is not interpreted as valid input by NSJSONSerialization.
        // See https://github.com/rails/rails/issues/1742
        if ([self.responseData length] == 0 || [self.responseString isEqualToString:@" "]) {
            self.responseJSON = nil;
        } else {
            // Flickr enjoys not following conventions and disregarding specifications
            NSString *string = self.responseString;
            
            // Remove invalid flickr escape sequences
            string = [string stringByReplacingOccurrencesOfString: @"\\'" withString: @"'"];
            
            // Remove the invalid json flickr wrapper
            NSRange range = [string rangeOfString:@"jsonFlickrFeed("
                                          options:0
                                            range:NSMakeRange(0, 15)];
            if (range.location != NSNotFound) {
                // Remove trailing ")" as well
                string = [string substringWithRange:NSMakeRange(range.length, string.length-range.length-1)];
            }
            
            NSData *JSONData = [NSMutableData dataWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
            
            self.responseJSON = [NSJSONSerialization JSONObjectWithData:JSONData
                                                       options:self.JSONReadingOptions
                                                         error:&error];
            
            // Find the culprit characters that Flickr doesn't know how to encode correctly
            if(error) {
                NSString *description = [error.userInfo objectForKey:@"NSDebugDescription"];
                NSRange range = [description rangeOfString:@"character "];
                if (range.location != NSNotFound) {
                    NSInteger index = [[string substringWithRange:NSMakeRange(range.location+range.length, description.length-1)] integerValue];
                    NSLog(@"%@\n surrounding 3 characters: %c%c%c", description, [string characterAtIndex:index-1], [string characterAtIndex:index], [string characterAtIndex:index+1]);
                }
            }
        }
        
        self.JSONError = error;
    }
    [self.lock unlock];
    
    return _responseJSON;
}


@end
