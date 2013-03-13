//
//  FlickrClient.m
//  Flickr Feed
//
//  Created by Daniel Hallman on 3/11/13.
//  Copyright (c) 2013 Daniel Hallman. All rights reserved.
//

#import "FlickrClient.h"
#import "NSString+URLEncoding.h"

NSString * const kFlickrBaseURL = @"http://api.flickr.com/";

@interface FlickrClient() <NSURLConnectionDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, copy) FlickrClientResultsBlock completionBlock;

@end

@implementation FlickrClient

- (void)publicFeedWithTags:(NSArray *)tags completionBlock:(FlickrClientResultsBlock)completionBlock {
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"json", @"format",
                            [tags componentsJoinedByString:@","], @"tags",
                            nil];
    
    
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@services/feeds/photos_public.gne?", kFlickrBaseURL];
    for (NSString *key in params) {
        [urlString appendFormat:@"%@=%@&", key, [[params objectForKey:key] urlEncodingUsingEncoding:NSUTF8StringEncoding]];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    url = [NSURL URLWithString:@"http://api.flickr.com/services/feeds/photos_public.gne?format=json"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"text/plain" forHTTPHeaderField:@"Accept"];
    
    // Cancel previous connection
    if (_connection) {
        [_connection cancel];
        if (_completionBlock) {
            _completionBlock([NSDictionary dictionary], nil);
        }
    }
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    _responseData = [NSMutableData data];
    _completionBlock = [completionBlock copy];
    
    [_connection start];
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (_completionBlock) {
        _completionBlock(nil, error);
    }
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSDictionary *response = nil;
    NSError *error = nil;
    NSString *string = nil;
    
    // Flickr enjoys not following conventions and disregarding specifications
    if (_responseData) {
        string = [[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding];
        
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
        
        _responseData = [NSMutableData dataWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
        
        response = [NSJSONSerialization JSONObjectWithData:_responseData
                                                   options:NSJSONReadingAllowFragments
                                                     error:&error];
        
        // Find the culprit characters that Flickr doesn't know how to encode correctly
        if(error) {
            NSString *description = [error.userInfo objectForKey:@"NSDebugDescription"];
            NSRange range = [description rangeOfString:@"character "];
            if (range.location != NSNotFound) {
                NSInteger index = [[string substringWithRange:NSMakeRange(range.location+range.length, description.length-1)] integerValue];
                NSLog(@"%@\n surrounding 3 characters: %c%c%c", description, [string characterAtIndex:index-1], [string characterAtIndex:index], [string characterAtIndex:index+1]);
            }
        } else {
            
        }
    }
    
    if (_completionBlock) {
        _completionBlock(response, error);
    }
}
@end
