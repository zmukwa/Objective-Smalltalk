//
//  MPWBundleScheme.m
//  MPWTalk
//
//  Created by Marcel Weiher on 5/28/11.
//  Copyright 2012 metaobject ltd. All rights reserved.
//

#import "MPWBundleScheme.h"
#import "MPWStCompiler.h"
#import <MPWFoundation/AccessorMacros.h>
#import "MPWFileBinding.h"

@implementation MPWBundleScheme

objectAccessor( NSBundle, bundle ,setBundle )

+schemeWithBundle:(NSBundle*)aBundle
{
	return [[[self alloc] initWithBundle:aBundle] autorelease];
}

+mainBundleScheme
{
	return [self schemeWithBundle:[NSBundle mainBundle]];
}

+classBundleScheme:(Class)aClass
{
	return [self schemeWithBundle:[NSBundle bundleForClass:aClass]];
}

-initWithBundle:(NSBundle*)aBundle
{
	self=[super init];
	[self setBundle:aBundle];
	return self;
}

-init
{
	return [self initWithBundle:[NSBundle bundleForClass:[self class]]];
}

-bindingForName:aName inContext:aContext
{

    NSString *pathExtension=[aName pathExtension];
    if ( !pathExtension) {
        pathExtension=@"";
    }
	NSString *path = [[self bundle] pathForResource:[aName stringByDeletingPathExtension] ofType:pathExtension];
    if ( !path ) {
        path=[[self bundle] resourcePath];
    }
	//	id binding = [MPWBinding bindingWithValue:[NSString stringWithContentsOfFile:aName]];
	return [super bindingForName:path inContext:aContext];
}



@end

@implementation MPWBundleScheme(testing)


+(void)testGettingASimpleFile
{
	chdir("/");
	IDEXPECT( [[MPWStCompiler evaluate:@"bundle:testfile.txt"] stringValue], @"this is a test file", @"geting testfile.txt");
}


+(void)testGettingRoot
{
	chdir("/");
	IDEXPECT( [[[MPWStCompiler evaluate:@"ref:bundle:/"] url] path], [[MPWStCompiler evaluate:@"scheme:bundle bundle resourcePath."] stringValue], @"root");
}


+testSelectors
{
	return [NSArray arrayWithObjects:
			@"testGettingASimpleFile",
			@"testGettingRoot",
			nil];
}


@end
