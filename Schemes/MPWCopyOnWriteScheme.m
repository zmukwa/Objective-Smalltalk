//
//  MPWCopyOnWriteScheme.m
//  MPWTalk
//
//  Created by Marcel Weiher on 12/9/11.
//  Copyright (c) 2012 metaobject ltd. All rights reserved.
//

#import "MPWCopyOnWriteScheme.h"
#import <MPWFoundation/MPWFoundation.h>
#import "MPWStCompiler.h"
#import "MPWGenericBinding.h"
#import "MPWTreeNodeScheme.h"

@implementation MPWCopyOnWriteScheme

objectAccessor(MPWScheme, readWrite, setReadWrite)
boolAccessor(cacheReads, setCacheReads)




-initWithBase:(MPWScheme*)newBase cache:(MPWScheme*)newCache
{
    self=[super init];
    [self setSource:newBase];
    [self setReadWrite:newCache];
    return self;

}
     
+cacheWithBase:(MPWScheme*)newBase cache:(MPWScheme*)newCache
{
    MPWCopyOnWriteScheme *newScheme=[[[self alloc] initWithBase:newBase cache:newCache] autorelease];
    [newScheme setCacheReads:YES];
    return newScheme;
}

+cache:cacheScheme
{
    return [self cacheWithBase:nil cache:cacheScheme];
}

+memoryCache
{
    return [self cache:[MPWTreeNodeScheme scheme]];
}


-valueForBinding:aBinding
{
    id result=nil;
    result=[[self readWrite] valueForBinding:aBinding];
//    NSLog(@"COW:  readWrite %@ for %@ returned %@",[self readWrite],[aBinding name],result);
    if ( !result ) {
//        NSLog(@"COW:  source %@ for %@ returned %@",[self source],[aBinding name],result);
        result=[[self source] valueForBinding:aBinding];
        if ( [self cacheReads] ) {
            [(MPWGenericScheme*)[self readWrite] setValue:result forBinding:aBinding];
        }
    }
    return result;
}

-(void)setValue:newValue forBinding:aBinding
{
    [(MPWGenericScheme*)[self readWrite] setValue:newValue forBinding:aBinding];
}

-(BOOL)hasChildren:(MPWGenericBinding*)binding
{
    return [[[self source] bindingForName:[binding name] inContext:nil] hasChildren];
}

-childrenOf:(MPWGenericBinding*)binding
{
    return [[[self source] bindingForName:[binding name] inContext:nil] children];
}


-(void)dealloc
{
    [readWrite release];
    [super dealloc];
}

@end

@implementation MPWCopyOnWriteScheme(testing)

+_testInterpreterWithCOW
{
    MPWStCompiler *interpreter=[[MPWStCompiler new] autorelease];
    [interpreter evaluateScriptString:@" site := MPWTreeNodeScheme scheme."];
    [interpreter evaluateScriptString:@" scheme:cms := site "];
    [interpreter evaluateScriptString:@" cms:/hi := 'hello world' "];
    [interpreter evaluateScriptString:@" scheme:cow := MPWCopyOnWriteScheme scheme."];
    [interpreter evaluateScriptString:@" scheme:cow setSource:site."];
    [interpreter evaluateScriptString:@" writer :=  MPWTreeNodeScheme scheme."];
    [interpreter evaluateScriptString:@" scheme:write :=  writer."];
    [interpreter evaluateScriptString:@" scheme:cow setReadWrite: writer."];
    

    return interpreter;
}


+(void)testReadFromBase
{
    MPWStCompiler *interpreter = [self _testInterpreterWithCOW];
    IDEXPECT([interpreter evaluateScriptString:@" cow:/hi "],@"hello world",@"read of base via cow");
}


+(void)testCopyOverridesBase
{
    MPWStCompiler *interpreter = [self _testInterpreterWithCOW];
    [interpreter evaluateScriptString:@" write:/hi := 'hello bozo' "];
    IDEXPECT([interpreter evaluateScriptString:@" write:/hi "],@"hello bozo",@"read of writer");
    IDEXPECT([interpreter evaluateScriptString:@" cow:/hi "],@"hello bozo",@"read of writer via cow");
}


+(void)testWriteOnCOWDoesntAffectBase
{
    MPWStCompiler *interpreter = [self _testInterpreterWithCOW];
    [interpreter evaluateScriptString:@" cow:/hi := 'hello bozo' "];
    IDEXPECT([interpreter evaluateScriptString:@" cow:/hi "],@"hello bozo",@"read of writer via cow");
    IDEXPECT([interpreter evaluateScriptString:@" write:/hi "],@"hello bozo",@"read of writer via cow");
    IDEXPECT([interpreter evaluateScriptString:@" cms:/hi "],@"hello world",@"read of base");
}

+(void)testCOWWithRelativeScheme
{
    MPWStCompiler *interpreter = [self _testInterpreterWithCOW];
    [interpreter evaluateScriptString:@" scheme:rel := MPWRelScheme alloc initWithBaseScheme: scheme:cms baseURL:'dir'."];
    [interpreter evaluateScriptString:@" cms:/dir/hi := 'Hello Relative World'"];


    IDEXPECT([interpreter evaluateScriptString:@" rel:hi "],@"Hello Relative World",@"read via relative scheme");
    [interpreter evaluateScriptString:@" cms:/writes/baseWrite := 'do not read me'"];
    [interpreter evaluateScriptString:@" scheme:cow setSource: scheme:rel . "];
    IDEXPECT([interpreter evaluateScriptString:@" cow:hi "],@"Hello Relative World",@"read via copy on write via relativexw");
    
    // FIXME: finish
}

+testSelectors
{
    return [NSArray arrayWithObjects:   
            @"testReadFromBase",
            @"testCopyOverridesBase",
            @"testWriteOnCOWDoesntAffectBase",
            @"testCOWWithRelativeScheme",
            nil];
}

@end