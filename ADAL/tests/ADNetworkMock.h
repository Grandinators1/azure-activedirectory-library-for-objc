// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


#import <Foundation/Foundation.h>

@interface ADTestURLResponse : NSObject
{
@public
    NSURL* _requestURL;
    id _requestJSONBody;
    id _requestParamsBody;
    NSDictionary* _requestHeaders;
    NSData* _requestBody;
    NSDictionary* _QPs;
    NSDictionary* _expectedRequestHeaders;
    NSData* _responseData;
    NSURLResponse* _response;
    NSError* _error;
}

+ (ADTestURLResponse*)requestURLString:(NSString*)requestUrlString
                     responseURLString:(NSString*)responseUrlString
                          responseCode:(NSInteger)responseCode
                      httpHeaderFields:(NSDictionary*)headerFields
                      dictionaryAsJSON:(NSDictionary*)data;

+ (ADTestURLResponse*)requestURLString:(NSString*)requestUrlString
                       requestJSONBody:(id)requestJSONBody
                     responseURLString:(NSString*)responseUrlString
                          responseCode:(NSInteger)responseCode
                      httpHeaderFields:(NSDictionary*)headerFields
                      dictionaryAsJSON:(NSDictionary*)data;

+ (ADTestURLResponse*)requestURLString:(NSString*)requestUrlString
                        requestHeaders:(NSDictionary *)requestHeaders
                     requestParamsBody:(id)requestParams
                     responseURLString:(NSString*)responseUrlString
                          responseCode:(NSInteger)responseCode
                      httpHeaderFields:(NSDictionary*)headerFields
                      dictionaryAsJSON:(NSDictionary*)data;

+ (ADTestURLResponse*)request:(NSURL*)request
                     response:(NSURLResponse*)response
                  reponseData:(NSData*)data;

+ (ADTestURLResponse*)request:(NSURL *)request
                      reponse:(NSURLResponse *)response;

+ (ADTestURLResponse*)request:(NSURL *)request
             respondWithError:(NSError*)error;

+ (ADTestURLResponse*)serverNotFoundResponseForURLString:(NSString*)requestURLString;

+ (ADTestURLResponse*)responseValidAuthority:(NSString*)authority;
+ (ADTestURLResponse*)responseInvalidAuthority:(NSString*)authority;

@end

static NSMutableArray* s_responses = nil;

@interface ADNetworkMock : NSObject

+ (ADTestURLResponse*)removeResponseForRequest:(NSURLRequest*)request;

// This adds an expected request, and response to it.
+ (void)addResponse:(ADTestURLResponse*)response;

// If you need to test a series of requests and responses use this API
+ (void)addResponses:(NSArray*)responses;

// Helper methods for common responses
+ (void)addNotFoundResponseForURLString:(NSString*)URLString;
+ (void)addValidAuthorityResponse:(NSString*)authority;
+ (void)addInvalidAuthorityResponse:(NSString*)authority;

+ (BOOL)noResponsesLeft;
+ (void)clearResponses;

@end
