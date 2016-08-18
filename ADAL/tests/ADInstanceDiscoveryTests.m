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

#import <XCTest/XCTest.h>
#import "ADErrorCodes.h"
#import "ADLogger.h"
#import "NSString+ADHelperMethods.h"
#import "XCTestCase+TestHelperMethods.h"
#import "ADInstanceDiscovery.h"
#import <libkern/OSAtomic.h>
#import "ADAuthenticationSettings.h"
#import "ADNetworkMock.h"

static NSString* const sAlwaysTrusted = @"https://login.windows.net";

@interface ADInstanceDiscoveryTests : XCTestCase
{
@private
    dispatch_semaphore_t _dsem;
}
@end

#define TEST_SIGNAL dispatch_semaphore_signal(_dsem)
#define TEST_WAIT dispatch_semaphore_wait(_dsem, DISPATCH_TIME_FOREVER)

@implementation ADInstanceDiscoveryTests

- (void)setUp
{
    _dsem = dispatch_semaphore_create(0);
    [super setUp];
    [self adTestBegin:ADAL_LOG_LEVEL_INFO];
}

- (void)tearDown
{
#if !__has_feature(objc_arc)
    dispatch_release(_dsem);
#endif
    _dsem = nil;
    
    [self adTestEnd];
    [super tearDown];
}

- (void)testExtractBaseBadAuthority
{
    [self adSetLogTolerance:ADAL_LOG_LEVEL_ERROR];
    
    ADInstanceDiscovery* discovery = [[ADInstanceDiscovery alloc] init];
    
    NSArray* cases = @[ [NSNull null],
                        // White space string:
                        @"   ",
                        // Invalid URL:
                        @"a sdfasdfasas;djfasd jfaosjd fasj;",
                        // Invalid URL scheme (not using SSL):
                        @"http://login.windows.net",
                        // Path
                        @"././login.windows.net",
                        // Relative URL
                        @"login"];
    
    for (id testCase in cases)
    {
        id testCaseVal = [testCase isKindOfClass:[NSNull class]] ? nil : testCase;
        
        ADAuthenticationError* error = nil;
        NSString* result = [discovery extractHost:testCaseVal
                                    correlationId:nil
                                            error:&error];
        XCTAssertNil(result, @"extractHost: should return nil for \"%@\"", testCaseVal);
        XCTAssertNotNil(error, @"extractHost: did not fill out the error for \"%@\"", testCaseVal);
        XCTAssertEqual(error.domain, ADAuthenticationErrorDomain);
        XCTAssertEqual(error.code, AD_ERROR_DEVELOPER_INVALID_ARGUMENT);
        XCTAssertNil(error.protocolCode);
        XCTAssertTrue([error.errorDetails containsString:@"authority"]);
    }
    
    SAFE_ARC_RELEASE(discovery);
}

- (void)testExtractBaseNormal
{
    ADInstanceDiscovery* discovery = [[ADInstanceDiscovery alloc] init];
    
    NSArray* cases = @[ @"httpS://Login.Windows.Net/MSopentech.onmicrosoft.com/oauth2/authorize",
                        @"httpS://Login.Windows.Net/MSopentech.onmicrosoft.com/oauth2/authorize/",
                        @"httpS://Login.Windows.Net/stuff"];
    
    for (NSString* testCase in cases)
    {
        ADAuthenticationError* error = nil;
        NSString* result = [discovery extractHost:testCase correlationId:nil error:&error];
        XCTAssertNotNil(result);
        XCTAssertNil(error);
        XCTAssertEqualObjects(result, @"https://login.windows.net");
    }
    
    SAFE_ARC_RELEASE(discovery);
}

- (void)testIsAuthorityValidated
{
    ADInstanceDiscovery* discovery = [[ADInstanceDiscovery alloc] init];
    
    [self adSetLogTolerance:ADAL_LOG_LEVEL_ERROR];
    XCTAssertFalse([discovery isAuthorityValidated:nil]);
    XCTAssertFalse([discovery isAuthorityValidated:@"  "]);
    NSString* anotherHost = @"https://somedomain.com";
    XCTAssertFalse([discovery isAuthorityValidated:anotherHost]);
    XCTAssertTrue([discovery isAuthorityValidated:sAlwaysTrusted]);
    
    SAFE_ARC_RELEASE(discovery);
}

- (void)testAddValidAuthority
{
    ADInstanceDiscovery* discovery = [[ADInstanceDiscovery alloc] init];
    
    [self adSetLogTolerance:ADAL_LOG_LEVEL_ERROR];
    XCTAssertFalse([discovery addValidAuthority:nil]);
    XCTAssertFalse([discovery addValidAuthority:@"  "]);
    //Test that re-adding is ok. This can happen in multi-threaded scenarios:
    XCTAssertTrue([discovery addValidAuthority:sAlwaysTrusted]);
    
    NSString* anotherHost = @"https://another.host.com";
    [discovery addValidAuthority:anotherHost];
    XCTAssertTrue([discovery isAuthorityValidated:anotherHost]);
    
    SAFE_ARC_RELEASE(discovery);
}

//Does not call the server, just passes invalid authority
-(void) testValidateAuthorityError
{
    [self adSetLogTolerance:ADAL_LOG_LEVEL_ERROR];
    
    NSArray* cases = @[@"http://invalidscheme.com",
                       @"https://Invalid URL 2305 8 -0238460-820-386"];
    NSUUID* correlationId = [NSUUID UUID];
    
    for (NSString* testCase in cases)
    {
        ADInstanceDiscovery* discovery = [[ADInstanceDiscovery alloc] init];
        [discovery validateAuthority:testCase
                       correlationId:correlationId
                     completionBlock:^(BOOL validated, ADAuthenticationError *error)
         {
             XCTAssertFalse(validated, @"\"%@\" should come back invalid.", testCase);
             XCTAssertNotNil(error);
             
             TEST_SIGNAL;
         }];
        
        TEST_WAIT;
    }
}

- (void)testCanonicalizeAuthority
{
    [self adSetLogTolerance:ADAL_LOG_LEVEL_ERROR];
    //Nil or empty:
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:nil]);
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@""]);
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"    "]);
    
    //Invalid URL
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"&-23425 5345g"]);
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"https:///login.windows.Net/something"], "Bad URL. Three slashes");
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"https:////"]);
    
    //Non-ssl:
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"something"]);
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"http://something"]);
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"http://www.microsoft.com"]);
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"abcde://login.windows.net/common"]);
    
    //Canonicalization to the supported extent:
    NSString* authority = @"    https://www.microsoft.com/something.com/";
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:authority], @"https://www.microsoft.com/something.com");
    
    authority = @"https://www.microsoft.com/something.com";
    //Without the trailing "/":
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:@"https://www.microsoft.com/something.com"], authority);
    //Ending with non-white characters:
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:@"https://www.microsoft.com/something.com   "], authority);
    
    authority = @"https://login.windows.net/msopentechbv.onmicrosoft.com";
    //Test canonicalizing the endpoints:
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:@"https://login.windows.Net/MSOpenTechBV.onmicrosoft.com/OAuth2/Token"], authority);
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:@"https://login.windows.Net/MSOpenTechBV.onmicrosoft.com/OAuth2/Authorize"], authority);
    
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"https://login.windows.Net"], "No tenant");
    XCTAssertNil([ADInstanceDiscovery canonicalizeAuthority:@"https://login.windows.Net/"], "No tenant");
    
    //Trimming beyond the tenant:
    authority = @"https://login.windows.net/something.com";
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:@"https://login.windows.Net/something.com/bar"], authority);
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:@"https://login.windows.Net/something.com"], authority);
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:@"https://login.windows.Net/something.com/"], authority);
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:@"https://login.windows.Net/something.com#bar"], authority);
    authority = @"https://login.windows.net/common";//Use "common" for a change
    ADAssertStringEquals([ADInstanceDiscovery canonicalizeAuthority:@"https://login.windows.net/common?abc=123&vc=3"], authority);
}

// Tests a real authority
- (void)testNormalFlow
{
    ADInstanceDiscovery* discovery = [[ADInstanceDiscovery alloc] init];
    NSUUID* correlationId = [NSUUID UUID];
    
    [ADNetworkMock addResponse:[ADTestURLResponse responseValidAuthority:@"https://login.windows-ppe.net/common"]];
    
    [discovery validateAuthority:@"https://login.windows-ppe.net/common"
                   correlationId:correlationId
                 completionBlock:^(BOOL validated, ADAuthenticationError * error)
    {
        XCTAssertTrue(validated);
        XCTAssertNil(error);
        
        TEST_SIGNAL;
    }];
    
    TEST_WAIT;
    XCTAssertTrue([[discovery validatedAuthorities] containsObject:@"https://login.windows-ppe.net"]);
    SAFE_ARC_RELEASE(discovery);
}

//Ensures that an invalid authority is not approved
- (void)testNonValidatedAuthority
{
    [self adSetLogTolerance:ADAL_LOG_LEVEL_ERROR];
    ADInstanceDiscovery* discovery = [[ADInstanceDiscovery alloc] init];
    NSUUID* correlationId = [NSUUID UUID];
    
    [ADNetworkMock addResponse:[ADTestURLResponse responseInvalidAuthority:@"https://myfakeauthority.microsoft.com/contoso.com"]];
    
    [discovery validateAuthority:@"https://MyFakeAuthority.microsoft.com/contoso.com"
                   correlationId:correlationId
                 completionBlock:^(BOOL validated, ADAuthenticationError * error)
     {
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         XCTAssertEqual(error.code, AD_ERROR_DEVELOPER_AUTHORITY_VALIDATION);
         
         TEST_SIGNAL;
     }];
    
    TEST_WAIT;
}

- (void)testUnreachableServer
{
    [self adSetLogTolerance:ADAL_LOG_LEVEL_ERROR];
    ADInstanceDiscovery* discovery = [[ADInstanceDiscovery alloc] init];
    
    NSURL* requestURL = [NSURL URLWithString:@"https://SomeValidURLButNotExistentInTheNet.com/common/discovery/instance?api-version=1.0&authorization_endpoint=https://login.windows.cn/MSOpenTechBV.onmicrosoft.com/oauth2/authorize&x-client-Ver=" ADAL_VERSION_STRING];
    NSError* responseError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotFindHost userInfo:nil];
    
    [ADNetworkMock addResponse:[ADTestURLResponse request:requestURL
                                               respondWithError:responseError]];
    
    [discovery requestValidationOfAuthority:@"https://login.windows.cn/MSOpenTechBV.onmicrosoft.com"
                                       host:@"https://login.windows.cn"
                           trustedAuthority:@"https://SomeValidURLButNotExistentInTheNet.com"
                              correlationId:[NSUUID UUID]
                            completionBlock:^(BOOL validated, ADAuthenticationError *error)
     {
         XCTAssertFalse(validated);
         XCTAssertNotNil(error);
         
         TEST_SIGNAL;
         
     }];
    
    TEST_WAIT;
    
    SAFE_ARC_RELEASE(discovery);
}

@end
